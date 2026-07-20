import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/source_preference.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/changed.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:watchtower/services/fetch_item_sources.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/services/fetch_sources_list.dart';
import 'package:watchtower/services/icon_cache_service.dart';
import 'package:watchtower/services/layout_downloader.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/language.dart';
import 'package:watchtower/utils/log/logger.dart';

final extensionListTileWidget = Provider.family<Widget, Source>((ref, source) {
  return ExtensionListTileWidget(source: source);
});

class ExtensionListTileWidget extends ConsumerStatefulWidget {
  final Source source;
  const ExtensionListTileWidget({super.key, required this.source});

  @override
  ConsumerState<ExtensionListTileWidget> createState() =>
      _ExtensionListTileWidgetState();
}

class _ExtensionListTileWidgetState
    extends ConsumerState<ExtensionListTileWidget> {
  bool _isLoading = false;
  String? _lastError;

  // Computed from the current widget.source so they stay accurate when the
  // parent rebuilds with a refreshed Source (e.g. after an install/update).
  // Using `late final` here was a bug: initState only runs once, so after
  // an update the stale value was shown until the widget was disposed.
  bool get _updateAvailable {
    final v = widget.source.version;
    final vl = widget.source.versionLast;
    if (v == null || vl == null) return false;
    return compareVersions(v, vl) < 0;
  }

  bool get _sourceNotEmpty =>
      widget.source.sourceCode != null &&
      widget.source.sourceCode!.isNotEmpty;

  Future<void> _handleSourceFetch() async {
    setState(() { _isLoading = true; _lastError = null; });
    AppLogger.log(
      '${_updateAvailable ? "Update" : "Install"} requested: "${widget.source.name}" v${widget.source.version}',
      tag: LogTag.extension_,
    );
    try {
      final provider = fetchItemSourcesListProvider(
        id: widget.source.id,
        reFresh: true,
        itemType: widget.source.itemType,
      );
      if (!(widget.source.isAdded ?? false)) ref.invalidate(provider);
      await ref.read(provider.future);
      AppLogger.log(
        '${_updateAvailable ? "Update" : "Install"} completed: "${widget.source.name}"',
        tag: LogTag.extension_,
      );
    } catch (e, st) {
      AppLogger.log(
        '${_updateAvailable ? "Update" : "Install"} FAILED: "${widget.source.name}"',
        logLevel: LogLevel.error,
        tag: LogTag.extension_,
        error: e,
        stackTrace: st,
      );
      if (mounted) setState(() => _lastError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePin() {
    isar.writeTxnSync(() {
      isar.sources.putSync(
        widget.source
          ..isPinned = !(widget.source.isPinned ?? false)
          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  void _showActionSheet(BuildContext ctx) {
    final isPinned = widget.source.isPinned ?? false;
    final cs = Theme.of(ctx).colorScheme;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          margin: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            12 + MediaQuery.of(sheetCtx).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.07),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Extension name header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: (widget.source.iconUrl?.isEmpty ?? true)
                          ? const Icon(Icons.extension_rounded, size: 18)
                            : ExtensionIconWidget(
                                sourceId: widget.source.id,
                                iconUrl: widget.source.iconUrl,
                                size: 36,
                              )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.source.name!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            widget.source.version ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: cs.outline.withValues(alpha: 0.12),
              ),

              // ── Actions ───────────────────────────────────────────────
              if (_sourceNotEmpty)
                _SheetAction(
                  icon: Icons.settings_outlined,
                  label: 'Ouvrir les paramètres',
                  cs: cs,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    ctx.push('/extension_detail', extra: widget.source);
                  },
                ),
              if (_sourceNotEmpty)
                _SheetAction(
                  icon: _updateAvailable
                      ? Icons.system_update_alt_outlined
                      : Icons.refresh_rounded,
                  label: _updateAvailable
                      ? 'Mettre à jour'
                      : 'Vérifier la mise à jour',
                  accent: _updateAvailable ? Colors.orange.shade400 : null,
                  cs: cs,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _handleSourceFetch();
                  },
                ),
              _SheetAction(
                icon: isPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                label: isPinned ? 'Désépingler' : 'Épingler',
                cs: cs,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _togglePin();
                },
              ),
              if (_sourceNotEmpty)
                _SheetAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Désinstaller',
                  accent: cs.error,
                  cs: cs,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _uninstall(ctx);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _uninstall(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(widget.source.name!),
        content: Text(
          dialogCtx.l10n.uninstall_extension(widget.source.name!),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(dialogCtx.l10n.cancel),
              ),
              const SizedBox(width: 15),
              TextButton(
                onPressed: () {
                  final sourcePrefsIds = isar
                      .sourcePreferences
                      .filter()
                      .sourceIdEqualTo(widget.source.id!)
                      .findAllSync()
                      .map((e) => e.id!)
                      .toList();
                  final sourcePrefsStringIds = isar
                      .sourcePreferenceStringValues
                      .filter()
                      .sourceIdEqualTo(widget.source.id!)
                      .findAllSync()
                      .map((e) => e.id)
                      .toList();
                  isar.writeTxnSync(() {
                    if (widget.source.isObsolete ?? false) {
                      isar.sources.deleteSync(widget.source.id!);
                      ref
                          .read(synchingProvider(syncId: 1).notifier)
                          .addChangedPart(
                            ActionType.removeExtension,
                            widget.source.id,
                            "{}",
                            false,
                          );
                    } else {
                      isar.sources.putSync(
                        widget.source
                          ..sourceCode = ""
                          ..isAdded = false
                          ..isPinned = false
                          ..updatedAt = DateTime.now().millisecondsSinceEpoch,
                      );
                    }
                    unawaited(LayoutDownloader.instance.remove(widget.source));
                    isar.sourcePreferences.deleteAllSync(sourcePrefsIds);
                    isar.sourcePreferenceStringValues
                        .deleteAllSync(sourcePrefsStringIds);
                  });
                  Navigator.pop(dialogCtx);
                },
                child: Text(dialogCtx.l10n.ok),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrailingButton(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 40,
        width: 36,
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.0),
          ),
        ),
      );
    }
    if (!_sourceNotEmpty) {
      return IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: _handleSourceFetch,
        icon: const Icon(Icons.download_outlined, size: 20),
      );
    }
    // Installed — encircled more_vert → directly to extension settings
    return GestureDetector(
      onTap: () => context.push('/extension_detail', extra: widget.source),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
            ),
            child: Icon(
              Icons.more_vert,
              size: 18,
              color: _updateAvailable
                  ? Colors.orange.shade400
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          if (_updateAvailable)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.shade400,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.source.sourceCodeLanguage;
    final isJs = lang == SourceCodeLanguage.javascript;
    final isDart = lang == SourceCodeLanguage.dart;
    final isMihon = lang == SourceCodeLanguage.mihon;
    final isAniyomi = isMihon && widget.source.itemType == ItemType.anime;

    final tile = ListTile(
      onTap: _isLoading
          ? null
          : () {
              if (_sourceNotEmpty) {
                AppLogger.log(
                  'Open extension detail: "${widget.source.name}" '
                  '[${widget.source.lang}] v${widget.source.version} '
                  '· id=${widget.source.id} · type=${widget.source.itemType.name}',
                  tag: LogTag.extension_,
                );
                context.push('/extension_detail', extra: widget.source);
              } else {
                _handleSourceFetch();
              }
            },
      onLongPress: _isLoading ? null : () => _showActionSheet(context),
      leading: Container(
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: (widget.source.iconUrl?.isEmpty ?? true)
            ? const Icon(Icons.extension_rounded, size: 18)
              : ExtensionIconWidget(
                  sourceId: widget.source.id,
                  iconUrl: widget.source.iconUrl,
                  size: 30,
                )
      ),
      title: Text(widget.source.name!),
      subtitle: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            completeLanguageName(widget.source.lang!.toLowerCase()),
            style: const TextStyle(fontWeight: FontWeight.w300, fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            _updateAvailable
                ? '${widget.source.version ?? ''} → ${widget.source.versionLast ?? ''}'
                : widget.source.version ?? '',
            style: TextStyle(
              fontWeight: FontWeight.w300,
              fontSize: 12,
              color: _updateAvailable ? Colors.orange.shade400 : null,
            ),
          ),
          if (widget.source.isNsfw ?? false)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "NSFW",
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          if (isDart)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "DART",
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          if (isJs)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.shade800.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "JS",
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          if (isMihon)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isAniyomi
                      ? const Color(0xFF7B2FBE).withValues(alpha: 0.9)
                      : Colors.indigo.shade600.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isAniyomi ? 'ANIYOMI' : 'MIHON',
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          if (widget.source.repo?.name != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "- ${widget.source.repo!.name!}",
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (widget.source.isObsolete ?? false)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "OBSOLETE",
                style: TextStyle(
                  color: context.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      trailing: _buildTrailingButton(context),
    );

    final errorBar = _lastError == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 13, color: Colors.red),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _lastError!,
                      style: const TextStyle(fontSize: 10, color: Colors.red),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => Clipboard.setData(ClipboardData(text: _lastError!)),
                    child: const Icon(Icons.copy_rounded, size: 13, color: Colors.red),
                  ),
                ],
              ),
            );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwipeTile(
            sourceNotEmpty: _sourceNotEmpty,
            isPinned: widget.source.isPinned ?? false,
            onUninstall: _sourceNotEmpty ? () => _uninstall(context) : null,
            onPin: _togglePin,
            onSettings: _sourceNotEmpty
                ? () => context.push('/extension_detail', extra: widget.source)
                : null,
            child: tile,
          ),
          if (errorBar != null) errorBar,
        ],
      );
  }
}

// ── Swipe tile ────────────────────────────────────────────────────────────────

class _SwipeTile extends StatefulWidget {
  final Widget child;
  final bool sourceNotEmpty;
  final bool isPinned;
  final VoidCallback? onUninstall;
  final VoidCallback? onPin;
  final VoidCallback? onSettings;

  const _SwipeTile({
    required this.child,
    this.sourceNotEmpty = false,
    this.isPinned = false,
    this.onUninstall,
    this.onPin,
    this.onSettings,
  });

  @override
  State<_SwipeTile> createState() => _SwipeTileState();
}

class _SwipeTileState extends State<_SwipeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _snapCtrl;
  late Animation<double> _snapAnim;
  double _dx = 0;
  bool _dragging = false;

  static const double _revealW = 110.0;
  static const double _deleteTh = 80.0;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _snapAnim = const AlwaysStoppedAnimation(0);
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  void _snapTo(double target) {
    final start = _dx;
    _snapAnim = Tween<double>(begin: start, end: target)
        .animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOut));
    _snapCtrl.forward(from: 0);
    setState(() { _dx = target; _dragging = false; });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _snapCtrl.stop();
    final next = (_dx + d.delta.dx).clamp(-_revealW, _deleteTh);
    if (!mounted) return;
    setState(() { _dx = next; _dragging = true; });
  }

  void _onDragEnd(DragEndDetails _) {
    if (_dx >= _deleteTh * 0.78 && widget.onUninstall != null) {
      _snapTo(0);
      Future.microtask(() => widget.onUninstall?.call());
    } else if (_dx <= -_revealW * 0.45 && widget.sourceNotEmpty) {
      _snapTo(-_revealW);
    } else {
      _snapTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _snapAnim,
      builder: (ctx, _) {
        final offset = _dragging ? _dx : _snapAnim.value;
        final showDel = offset > 4;
        final showOpt = offset < -4 && widget.sourceNotEmpty;
        final delOp = (offset / _deleteTh).clamp(0.0, 1.0);
        final optOp = (-offset / _revealW).clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onTap: (!_dragging && offset != 0)
              ? () => _snapTo(0)
              : null,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Delete background (right swipe)
              if (showDel)
                Positioned.fill(
                  child: Container(
                    color: cs.error.withValues(alpha: delOp * 0.9),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: Opacity(
                      opacity: delOp,
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              // Options background (left swipe)
              if (showOpt)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: _revealW,
                  child: Opacity(
                    opacity: optOp,
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _snapTo(0);
                              widget.onPin?.call();
                            },
                            child: Container(
                              color: Colors.indigo.shade600,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    widget.isPinned
                                        ? Icons.push_pin_rounded
                                        : Icons.push_pin_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Épingler',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _snapTo(0);
                              widget.onSettings?.call();
                            },
                            child: Container(
                              color: Colors.blueGrey.shade600,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.settings_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Réglages',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // The tile itself
              Transform.translate(
                offset: Offset(offset, 0),
                child: Material(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  child: widget.child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Bottom-sheet action row ───────────────────────────────────────────────────

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.cs,
    required this.isDark,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final fg = accent ?? (isDark ? Colors.white : Colors.black87);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
