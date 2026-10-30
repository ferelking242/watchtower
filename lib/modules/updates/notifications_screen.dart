import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/models/update.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/extension_catalog_notifications.dart';
import 'package:watchtower/services/fetch_sources_list.dart'
    show
        extensionUpdateLabel,
        extensionUpdateSignature,
        fetchSourcesList,
        hasPendingExtensionUpdate,
        installExtensionUpdate;
import 'package:watchtower/services/layout_registry.dart';

/// In-app notification centre.
///
/// Notifications are grouped messages, not one box per extension: a batch of
/// three extension updates is a single message that expands to its three
/// children, so the page reads as a short list of things that happened rather
/// than a wall of identical cards. Each child is actionable — tapping it opens
/// the extension detail, and the trailing button installs the update in place.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<_NotificationData> _future;
  final Set<int> _installing = {};
  bool _refreshingCatalog = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshCatalog();
    });
  }

  Future<_NotificationData> _load({Object? sourceError}) async {
    List<Source> sources = const [];
    try {
      sources = await isar.sources.buildQuery<Source>().findAll();
      for (final source in sources) {
        source.hydrateExtendedMetadata();
      }
    } catch (error) {
      sourceError = error;
    }
    final savedExtensionUpdates =
        await ExtensionCatalogNotifications.pendingUpdates();
    final savedUpdateKeys = savedExtensionUpdates
        .map((notice) => notice.key)
        .toSet();
    // Updates the user has already acknowledged (dismissed or installed) stay
    // hidden until a *newer* version changes the signature.
    final acknowledged =
        await ExtensionCatalogNotifications.dismissedUpdateSignatures();
    final extensionUpdates =
        sources
            .where(
              (source) =>
                  source.isAdded == true &&
                  source.id != null &&
                  (hasPendingExtensionUpdate(source) ||
                      savedUpdateKeys.contains(
                        '${source.itemType.index}:${source.id}',
                      )) &&
                  !acknowledged.contains(extensionUpdateSignature(source)),
            )
            .toList()
          ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    final newExtensions = await ExtensionCatalogNotifications.pending();
    var libraryUpdates = 0;
    Object? libraryError;
    try {
      libraryUpdates = await isar.updates.count();
    } catch (error) {
      libraryError = error;
    }
    return _NotificationData(
      extensionUpdates: extensionUpdates,
      newExtensions: newExtensions,
      libraryUpdates: libraryUpdates,
      errorMessage: sourceError != null || libraryError != null
          ? 'Certaines notifications sont momentanément indisponibles.'
          : null,
    );
  }

  Future<void> _refreshCatalog() async {
    if (_refreshingCatalog == false && mounted) {
      setState(() => _refreshingCatalog = true);
    }

    Object? sourceError;
    try {
      final sources = await isar.sources.buildQuery<Source>().findAll();
      sourceError = await _refreshInstalledCatalog(sources);
    } catch (error) {
      sourceError = error;
    }

    if (!mounted) return;
    setState(() {
      _refreshingCatalog = false;
      _future = _load(sourceError: sourceError);
    });
  }

  /// Refreshes catalogue metadata only. Notifications must never install an
  /// extension as a side effect of being opened, even when automatic updates
  /// are enabled globally.
  Future<Object?> _refreshInstalledCatalog(List<Source> sources) async {
    final types = sources
        .where(
          (source) =>
              source.isAdded == true &&
              source.isLocal != true &&
              source.sourceCodeLanguage != SourceCodeLanguage.dart,
        )
        .map((source) => source.itemType)
        .toSet();
    if (types.isEmpty) return null;
    Object? firstError;
    await Future.wait(
      types.map((type) async {
        final repos = ref.read(extensionsRepoStateProvider(type));
        for (final repo in repos) {
          try {
            await fetchSourcesList(
              repo: repo,
              refresh: true,
              id: null,
              autoUpdateExtensions: false,
              itemType: type,
            );
          } catch (error) {
            firstError ??= error;
          }
        }
      }),
    );
    return firstError;
  }

  Future<void> _retry() async {
    setState(() {
      _future = _load();
      _refreshingCatalog = true;
    });
    await _refreshCatalog();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications_title),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Broken.arrow_left),
        ),
        actions: [
          IconButton(
            tooltip: l10n.notifications_refresh_tooltip,
            onPressed: _refreshingCatalog ? null : _refreshCatalog,
            icon: _refreshingCatalog
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Broken.refresh_2),
          ),
        ],
      ),
      body: FutureBuilder<_NotificationData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                l10n.notifications_load_error,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            );
          }
          final data = snapshot.data!;
          if (data.isEmpty) {
            if (data.errorMessage != null) {
              return _NotificationError(
                message: data.errorMessage!,
                onRetry: _retry,
              );
            }
            if (_refreshingCatalog) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      l10n.notifications_checking_updates,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              );
            }
            return _EmptyNotifications(color: cs.onSurfaceVariant);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
            children: [
              if (data.errorMessage != null)
                _NotificationWarning(message: data.errorMessage!),
              if (data.extensionUpdates.isNotEmpty) ...[
                _UpdateGroup(
                  sources: data.extensionUpdates,
                  installing: _installing,
                  onInstall: _install,
                  onInstallAll: _installAll,
                  onDismiss: _dismissUpdate,
                  onOpen: _openDetail,
                ),
                const SizedBox(height: 12),
              ],
              if (data.newExtensions.isNotEmpty)
                _PublicationGroup(
                  notices: data.newExtensions,
                  onDismiss: _dismissPublication,
                  onBrowse: () => context.push('/marketplace'),
                ),
              if (data.libraryUpdates > 0) ...[
                const SizedBox(height: 12),
                _MessageCard(
                  icon: Broken.bookmark,
                  color: cs.primary,
                  title: l10n.notifications_library_count(data.libraryUpdates),
                  subtitle: l10n.notifications_library_subtitle,
                  action: TextButton.icon(
                    onPressed: () => context.push('/updates'),
                    icon: const Icon(Broken.arrow_right),
                    label: Text(l10n.notifications_view_updates),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openDetail(Source source) {
    context.push('/extension_detail', extra: source);
  }

  Future<void> _install(Source source) async {
    final id = source.id;
    if (id == null) return;
    setState(() => _installing.add(id));
    try {
      await installExtensionUpdate(source);
      final installed = await isar.sources.get(id);
      if (installed == null) {
        throw StateError(
          'La source installée est introuvable après téléchargement.',
        );
      }
      await LayoutRegistry.instance.load(installed);
      if (installed.uiLayout?.isNotEmpty == true &&
          !LayoutRegistry.instance.has(installed)) {
        throw StateError('Le layout UI n’a pas été installé.');
      }
      // The update is applied: drop it from both ledgers so a later version can
      // be announced again.
      await ExtensionCatalogNotifications.dismissPendingUpdate(
        id: id,
        itemType: installed.itemType,
      );
      await ExtensionCatalogNotifications.clearDismissedUpdates(
        id: id,
        itemType: installed.itemType,
      );
      if (!mounted) return;
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notifications_updated_toast(source.name ?? '')),
        ),
      );
      setState(() => _future = _load());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.notifications_install_failed('$error')),
        ),
      );
    } finally {
      if (mounted) setState(() => _installing.remove(id));
    }
  }

  Future<void> _installAll(List<Source> sources) async {
    for (final source in sources) {
      if (!mounted) return;
      await _install(source);
    }
  }

  /// Hides one update without installing it, until a newer version appears.
  Future<void> _dismissUpdate(Source source) async {
    final id = source.id;
    if (id == null) return;
    await ExtensionCatalogNotifications.dismissPendingUpdate(
      id: id,
      itemType: source.itemType,
      signature: extensionUpdateSignature(source),
    );
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Future<void> _dismissPublication(ExtensionPublicationNotice notice) async {
    await ExtensionCatalogNotifications.dismiss(notice);
    if (!mounted) return;
    setState(() => _future = _load());
  }
}

class _NotificationData {
  final List<Source> extensionUpdates;
  final List<ExtensionPublicationNotice> newExtensions;
  final int libraryUpdates;
  final String? errorMessage;

  const _NotificationData({
    required this.extensionUpdates,
    required this.newExtensions,
    required this.libraryUpdates,
    this.errorMessage,
  });

  bool get isEmpty =>
      extensionUpdates.isEmpty && newExtensions.isEmpty && libraryUpdates == 0;
}

String _publicationTypeLabel(AppLocalizations l10n, ItemType type) =>
    switch (type) {
      ItemType.anime => l10n.catalog_tab_watch,
      ItemType.manga => l10n.catalog_tab_manga,
      ItemType.novel => l10n.catalog_tab_novels,
      ItemType.music => l10n.catalog_tab_music,
      ItemType.game => l10n.catalog_tab_games,
      ItemType.plugin => l10n.browse_plugins,
    };

/// A grouped message: a headline, an optional subtitle, then an expandable list
/// of children. A single child is rendered inline; several are collapsed behind
/// a disclosure row so the page stays short.
class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? child;
  final Widget? action;
  final bool expandable;
  final bool initiallyExpanded;
  final VoidCallback? onToggle;

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.child,
    this.action,
    this.expandable = false,
    this.initiallyExpanded = true,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: expandable ? onToggle : null,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (expandable)
                  Icon(
                    initiallyExpanded ? Broken.arrow_up_1 : Broken.arrow_down_1,
                    size: 19,
                    color: cs.onSurfaceVariant,
                  ),
              ],
            ),
          ),
          if (child != null && (!expandable || initiallyExpanded)) ...[
            const SizedBox(height: 8),
            // The card paints its own background, so ListTiles inside it need a
            // Material ancestor to draw their ink splashes on.
            Material(type: MaterialType.transparency, child: child!),
          ],
          if (action != null)
            Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}

/// The extension-update message: one row per extension, each opening its detail
/// on tap and installing in place.
class _UpdateGroup extends StatefulWidget {
  final List<Source> sources;
  final Set<int> installing;
  final Future<void> Function(Source source) onInstall;
  final Future<void> Function(List<Source> sources) onInstallAll;
  final Future<void> Function(Source source) onDismiss;
  final void Function(Source source) onOpen;

  const _UpdateGroup({
    required this.sources,
    required this.installing,
    required this.onInstall,
    required this.onInstallAll,
    required this.onDismiss,
    required this.onOpen,
  });

  @override
  State<_UpdateGroup> createState() => _UpdateGroupState();
}

class _UpdateGroupState extends State<_UpdateGroup> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // A single update is shown open; a batch starts collapsed so the message
    // reads as one line until the user asks for the children.
    _expanded = widget.sources.length <= 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sources = widget.sources;
    final single = sources.length == 1;
    // A single update is the whole message, so it carries its own actions. A
    // batch keeps a generic headline and reveals one row per extension.
    if (single) {
      final source = sources.first;
      final installing = widget.installing.contains(source.id);
      return _MessageCard(
        icon: Broken.refresh_2,
        color: Colors.orange.shade700,
        title: l10n.notifications_update_single(source.name ?? 'Extension'),
        subtitle: extensionUpdateLabel(source),
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.notifications_dismiss_update,
              onPressed: installing ? null : () => widget.onDismiss(source),
              icon: const Icon(Icons.close_rounded, size: 19),
            ),
            FilledButton(
              onPressed: installing ? null : () => widget.onInstall(source),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: installing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.notifications_install),
            ),
          ],
        ),
      );
    }
    return _MessageCard(
      icon: Broken.refresh_2,
      color: Colors.orange.shade700,
      title: l10n.notifications_updates_count(sources.length),
      subtitle: l10n.notifications_updates_subtitle,
      expandable: true,
      initiallyExpanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      action: TextButton.icon(
        onPressed: () => widget.onInstallAll(sources),
        icon: const Icon(Broken.document_download, size: 18),
        label: Text(l10n.notifications_install_all),
      ),
      child: Column(
        children: [
          for (final source in sources)
            _UpdateTile(
              source: source,
              installing: widget.installing.contains(source.id),
              onInstall: () => widget.onInstall(source),
              onDismiss: () => widget.onDismiss(source),
              onOpen: () => widget.onOpen(source),
            ),
        ],
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  final Source source;
  final bool installing;
  final VoidCallback onInstall;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;

  const _UpdateTile({
    required this.source,
    required this.installing,
    required this.onInstall,
    required this.onDismiss,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _SourceIcon(source: source),
      title: Text(
        l10n.notifications_update_message(source.name ?? 'Extension'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(extensionUpdateLabel(source)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.notifications_dismiss_update,
            onPressed: installing ? null : onDismiss,
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
          FilledButton(
            onPressed: installing ? null : onInstall,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: installing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.notifications_install),
          ),
        ],
      ),
      onTap: onOpen,
    );
  }
}

/// The "new extensions published" message.
class _PublicationGroup extends StatelessWidget {
  final List<ExtensionPublicationNotice> notices;
  final Future<void> Function(ExtensionPublicationNotice notice) onDismiss;
  final VoidCallback onBrowse;

  const _PublicationGroup({
    required this.notices,
    required this.onDismiss,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return _MessageCard(
      icon: Icons.new_releases_rounded,
      color: cs.tertiary,
      title: l10n.notifications_new_count(notices.length),
      subtitle: l10n.notifications_new_subtitle,
      action: TextButton.icon(
        onPressed: onBrowse,
        icon: const Icon(Broken.arrow_right),
        label: Text(l10n.notifications_browse_marketplace),
      ),
      child: Column(
        children: [
          for (final notice in notices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _PublicationIcon(notice: notice),
              title: Text(
                notice.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  _publicationTypeLabel(l10n, notice.itemType),
                  if (notice.lang.isNotEmpty) notice.lang.toUpperCase(),
                  if (notice.version.isNotEmpty) 'v${notice.version}',
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: l10n.notifications_hide,
                onPressed: () => onDismiss(notice),
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
              onTap: onBrowse,
            ),
        ],
      ),
    );
  }
}

class _NotificationWarning extends StatelessWidget {
  final String message;
  const _NotificationWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _NotificationError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Broken.notification, color: color, size: 46),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: color),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Broken.refresh_2),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  final Color color;
  const _EmptyNotifications({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Broken.notification,
            size: 46,
            color: color.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 12),
          Text(context.l10n.notifications_none, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _SourceIcon extends StatelessWidget {
  final Source source;
  const _SourceIcon({required this.source});

  @override
  Widget build(BuildContext context) {
    final url = source.iconUrl;
    if (url == null || url.isEmpty) {
      return const CircleAvatar(child: Icon(Broken.box));
    }
    return CircleAvatar(backgroundImage: NetworkImage(url));
  }
}

class _PublicationIcon extends StatelessWidget {
  final ExtensionPublicationNotice notice;

  const _PublicationIcon({required this.notice});

  @override
  Widget build(BuildContext context) {
    final url = notice.iconUrl;
    if (url == null || url.isEmpty) {
      return const CircleAvatar(child: Icon(Broken.box));
    }
    return CircleAvatar(backgroundImage: NetworkImage(url));
  }
}
