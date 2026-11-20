import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/local_indexer/metadata/local_media_metadata.dart';
import 'package:watchtower/local_indexer/metadata/local_metadata_resolver.dart';
import 'package:watchtower/local_indexer/metadata/local_override_service.dart';
import 'package:watchtower/local_indexer/models/local_indexed_item.dart';
import 'package:watchtower/local_indexer/models/local_work.dart';
import 'package:watchtower/local_indexer/providers/local_indexer_provider.dart';
import 'package:watchtower/local_indexer/rename/local_rename_service.dart';
import 'package:watchtower/main.dart' show isar;
import 'package:watchtower/providers/l10n_providers.dart';

/// Bottom sheet opened from a Smart Library card.
///
/// Shows the files behind a work and lets the user fix what the automatic
/// classification could not place: edit the title/type/tags by hand, search
/// the catalogue again, or rename the file to the canonical name its metadata
/// implies.
class LocalWorkDetailSheet extends ConsumerStatefulWidget {
  final LocalWork work;

  const LocalWorkDetailSheet({required this.work, super.key});

  static Future<void> show(BuildContext context, LocalWork work) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LocalWorkDetailSheet(work: work),
    );
  }

  @override
  ConsumerState<LocalWorkDetailSheet> createState() =>
      _LocalWorkDetailSheetState();
}

class _LocalWorkDetailSheetState extends ConsumerState<LocalWorkDetailSheet> {
  bool _busy = false;

  LocalWork get _work => widget.work;

  void _refresh() {
    ref.invalidate(localWorksProvider);
    ref.invalidate(recentlyIndexedProvider);
    ref.invalidate(localIndexedCountProvider);
  }

  Future<void> _requery(LocalIndexedItem item) async {
    setState(() => _busy = true);
    final l10n = context.l10n;
    try {
      final metadata = await LocalMetadataResolver.instance.resolveOne(item);
      if (!mounted) return;
      final message = metadata == null
          ? l10n.smart_requery_none
          : l10n.smart_requery_found(metadata.title);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.smart_requery_failed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(LocalIndexedItem item) async {
    final l10n = context.l10n;
    final metadata = await LocalMediaMetadataStore.instance.get(item);
    final plan = LocalRenameService.instance.plan(item, metadata: metadata);
    if (!mounted) return;

    if (!plan.isRenameable) {
      final reason = plan.blockedReason;
      final message = reason == null
          ? l10n.smart_rename_not_needed
          : l10n.smart_rename_failed(reason);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.smart_rename),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.smart_rename_preview),
            const SizedBox(height: 6),
            Text(
              plan.targetName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.smart_edit_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.smart_rename_apply),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final applied = await LocalRenameService.instance.apply(
        plan,
        isar: isar,
        searchEngine: ref.read(localSearchEngineProvider),
      );
      if (!mounted) return;
      final ok = applied.blockedReason == null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? l10n.smart_rename_done
                : l10n.smart_rename_failed(applied.blockedReason!),
          ),
        ),
      );
      _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Renames every file of the work in one pass.
  ///
  /// Correcting a twelve-episode season one file at a time is unusable, and
  /// after a manual fix the user expects the whole folder to follow the name
  /// they just gave it.
  Future<void> _renameAll() async {
    final l10n = context.l10n;
    final plans = <LocalRenamePlan>[];
    for (final item in _work.files) {
      final metadata = await LocalMediaMetadataStore.instance.get(item);
      final plan = LocalRenameService.instance.plan(item, metadata: metadata);
      if (plan.isRenameable) plans.add(plan);
    }
    if (!mounted) return;

    if (plans.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.smart_rename_not_needed)));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.smart_rename_all),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.smart_rename_preview),
              const SizedBox(height: 6),
              for (final plan in plans.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    plan.targetName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              if (plans.length > 20)
                Text('+${plans.length - 20}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.smart_edit_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.smart_rename_apply),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    var renamed = 0;
    var blocked = 0;
    try {
      final engine = ref.read(localSearchEngineProvider);
      for (final plan in plans) {
        final applied = await LocalRenameService.instance.apply(
          plan,
          isar: isar,
          searchEngine: engine,
        );
        if (applied.blockedReason == null) {
          renamed++;
        } else {
          blocked++;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.smart_rename_all_done(renamed, blocked))),
      );
      _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(LocalIndexedItem item) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditEntrySheet(item: item),
    );
    if (updated == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _work.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.smart_track_count(_work.fileCount),
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (_work.files.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _renameAll,
                  icon: const Icon(Broken.edit_2, size: 16),
                  label: Text(l10n.smart_rename_all),
                ),
              ),
            if (_work.kind == LocalMediaKind.unknown)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.smart_unknown_help,
                  style: TextStyle(fontSize: 12, color: cs.error),
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _work.files.length,
                itemBuilder: (context, i) {
                  final item = _work.files[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      p.basename(item.filePath),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.smart_requery,
                          onPressed: _busy ? null : () => _requery(item),
                          icon: const Icon(Broken.search_zoom_in, size: 20),
                        ),
                        IconButton(
                          tooltip: l10n.smart_rename,
                          onPressed: _busy ? null : () => _rename(item),
                          icon: const Icon(Broken.edit_2, size: 20),
                        ),
                        IconButton(
                          tooltip: l10n.smart_edit_entry,
                          onPressed: _busy ? null : () => _edit(item),
                          icon: const Icon(Broken.edit, size: 20),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Form that lets the user correct one indexed entry by hand.
class _EditEntrySheet extends ConsumerStatefulWidget {
  final LocalIndexedItem item;

  const _EditEntrySheet({required this.item});

  @override
  ConsumerState<_EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends ConsumerState<_EditEntrySheet> {
  late final TextEditingController _title;
  late final TextEditingController _season;
  late final TextEditingController _episode;
  late final TextEditingController _artist;
  late final TextEditingController _album;
  late LocalMediaKind _kind;
  bool _saving = false;
  bool _searching = false;
  LocalMediaMetadata? _match;

  static const _kinds = [
    LocalMediaKind.movie,
    LocalMediaKind.series,
    LocalMediaKind.anime,
    LocalMediaKind.music,
    LocalMediaKind.manga,
    LocalMediaKind.unknown,
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item.title);
    _season = TextEditingController(text: item.season?.toString() ?? '');
    _episode = TextEditingController(text: item.episode?.toString() ?? '');
    _artist = TextEditingController(text: item.artist ?? '');
    _album = TextEditingController(text: item.album ?? '');
    _kind = item.kind;
  }

  @override
  void dispose() {
    _title.dispose();
    _season.dispose();
    _episode.dispose();
    _artist.dispose();
    _album.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final l10n = context.l10n;
    try {
      await LocalOverrideService.instance.edit(
        widget.item,
        isar: isar,
        searchEngine: ref.read(localSearchEngineProvider),
        title: _title.text,
        kind: _kind,
        season: int.tryParse(_season.text.trim()),
        episode: int.tryParse(_episode.text.trim()),
        clearSeason: _season.text.trim().isEmpty,
        clearEpisode: _episode.text.trim().isEmpty,
        artist: _artist.text,
        album: _album.text,
        clearArtist: _artist.text.trim().isEmpty,
        clearAlbum: _album.text.trim().isEmpty,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.smart_edit_saved)));
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Looks the typed name up on the catalogue the current [kind] maps to, so
  /// the user can rescue an entry whose filename never matched anything.
  Future<void> _search() async {
    final l10n = context.l10n;
    setState(() => _searching = true);
    try {
      final found = await LocalMetadataResolver.instance.searchByTitle(
        _title.text,
        kind: _kind,
        artist: _artist.text.trim().isEmpty ? null : _artist.text,
      );
      if (!mounted) return;
      setState(() => _match = found);
      if (found == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.smart_search_none)));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.smart_search_failed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Accepts the catalogue match: its title becomes the entry title, and for
  /// music the resolved artist/album are filled in.
  Future<void> _applyMatch() async {
    final match = _match;
    if (match == null) return;
    setState(() {
      _title.text = match.title;
      if (match.artist != null) _artist.text = match.artist!;
      if (match.album != null) _album.text = match.album!;
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isMusic = _kind == LocalMediaKind.music;
    final isSeries =
        _kind == LocalMediaKind.series || _kind == LocalMediaKind.anime;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.smart_edit_entry,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: l10n.smart_edit_title,
                  helperText: l10n.smart_edit_title_hint,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _saving || _searching ? null : _search,
                  icon: _searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Broken.search_zoom_in, size: 18),
                  label: Text(
                    _searching
                        ? l10n.smart_search_running
                        : l10n.smart_search_catalogue,
                  ),
                ),
              ),
              if (_match != null) ...[
                const SizedBox(height: 8),
                _MatchCard(
                  match: _match!,
                  onApply: _saving ? null : _applyMatch,
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<LocalMediaKind>(
                initialValue: _kind,
                decoration: InputDecoration(labelText: l10n.smart_edit_kind),
                items: [
                  for (final kind in _kinds)
                    DropdownMenuItem(value: kind, child: Text(kind.name)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _kind = value);
                },
              ),
              if (isSeries) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _season,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.smart_edit_season,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _episode,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.smart_edit_episode,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (isMusic) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _artist,
                  decoration: InputDecoration(
                    labelText: l10n.smart_edit_artist,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _album,
                  decoration: InputDecoration(labelText: l10n.smart_edit_album),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(l10n.smart_edit_cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(l10n.smart_edit_save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview of one catalogue hit, with the button that accepts it.
class _MatchCard extends StatelessWidget {
  final LocalMediaMetadata match;
  final VoidCallback? onApply;

  const _MatchCard({required this.match, required this.onApply});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final subtitle = [
      if (match.year != null) '${match.year}',
      if (match.artist != null && match.artist!.isNotEmpty) match.artist!,
      if (match.album != null && match.album!.isNotEmpty) match.album!,
      if (match.genres.isNotEmpty) match.genres.take(2).join(', '),
    ].join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (match.posterUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  match.posterUrl!,
                  width: 48,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 48, height: 72),
                ),
              ),
            if (match.posterUrl != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    match.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  if (match.overview != null && match.overview!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        match.overview!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: onApply,
                      child: Text(l10n.smart_search_apply),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
