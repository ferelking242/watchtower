import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/services/mini_webview_state.dart';

/// Floating tab grouper overlay — shown whenever WebView tabs are minimized.
/// 1 tab  → tap/expand opens it directly.
/// 2+ tabs → tap/grid icon opens the tab manager sheet.
class MiniWebViewTabGrouper extends ConsumerWidget {
  const MiniWebViewTabGrouper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(miniWebViewProvider);
    if (tabs.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          // Clear the floating navigation dock (64px pill + 14px bottom pad)
          padding: const EdgeInsets.only(bottom: 78.0),
          child: _TabGroupPill(tabs: tabs, ref: ref),
        ),
      ),
    );
  }
}

class _TabGroupPill extends StatelessWidget {
  final List<MiniWebViewEntry> tabs;
  final WidgetRef ref;
  const _TabGroupPill({required this.tabs, required this.ref});

  void _openTab(BuildContext context, int index) {
    final list = ref.read(miniWebViewProvider);
    if (index < 0 || index >= list.length) return;
    final entry = list[index];
    ref.read(miniWebViewProvider.notifier).removeAt(index);
    context.push('/mangawebview', extra: {
      'url': entry.url,
      'title': entry.title,
      'initialFraction': 0.0,
    });
  }

  void _openSingle(BuildContext context) {
    final entry = ref.read(miniWebViewProvider.notifier).pop();
    if (entry != null) {
      context.push('/mangawebview', extra: {
        'url': entry.url,
        'title': entry.title,
        'initialFraction': 0.0,
      });
    }
  }

  void _showTabManager(BuildContext context) {
    HapticFeedback.mediumImpact();
    final currentTabs = List<MiniWebViewEntry>.from(
      ref.read(miniWebViewProvider),
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => ProviderScope(
        parent: ProviderScope.containerOf(ctx),
        child: _TabManagerSheet(
          initialTabs: currentTabs,
          ref: ref,
          onOpenTab: (index) {
            Navigator.pop(ctx);
            _openTab(context, index);
          },
          onCloseAll: () {
            Navigator.pop(ctx);
            ref.read(miniWebViewProvider.notifier).clear();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = tabs.length;
    final first = tabs.first;
    final label = first.title.isNotEmpty ? first.title : 'Page web';
    final fullLabel = count > 1 ? '$count onglets ouverts' : label;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
      child: GestureDetector(
        onTap: () => count >= 2
            ? _showTabManager(context)
            : _openSingle(context),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              // Count badge (2+ tabs) or globe icon (1 tab)
              count >= 2
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.language_rounded,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 20,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fullLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Grid/expand button
              IconButton(
                icon: Icon(
                  count >= 2
                      ? Icons.grid_view_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 22,
                ),
                onPressed: () => count >= 2
                    ? _showTabManager(context)
                    : _openSingle(context),
                tooltip: count >= 2 ? 'Gérer les onglets' : 'Ouvrir',
              ),
              // Close all
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 20,
                ),
                onPressed: () =>
                    ref.read(miniWebViewProvider.notifier).clear(),
                tooltip: 'Fermer tout',
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab manager bottom sheet ──────────────────────────────────────────────────

class _TabManagerSheet extends ConsumerStatefulWidget {
  final List<MiniWebViewEntry> initialTabs;
  final WidgetRef ref;
  final void Function(int) onOpenTab;
  final VoidCallback onCloseAll;

  const _TabManagerSheet({
    required this.initialTabs,
    required this.ref,
    required this.onOpenTab,
    required this.onCloseAll,
  });

  @override
  ConsumerState<_TabManagerSheet> createState() => _TabManagerSheetState();
}

class _TabManagerSheetState extends ConsumerState<_TabManagerSheet> {
  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(miniWebViewProvider);
    if (tabs.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.90),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
                child: Row(
                  children: [
                    Text(
                      '${tabs.length} onglet${tabs.length > 1 ? 's' : ''} ouvert${tabs.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: widget.onCloseAll,
                      icon: Icon(Icons.close_rounded, size: 15, color: cs.error),
                      label: Text(
                        'Fermer tous',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : Colors.black.withValues(alpha: 0.08),
              ),
              // Tab list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: tabs.length,
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    final title =
                        tab.title.isNotEmpty ? tab.title : 'Page web';
                    return ListTile(
                      onTap: () => widget.onOpenTab(index),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.language_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                      ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        tab.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.42),
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.40),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.ref
                              .read(miniWebViewProvider.notifier)
                              .removeAt(index);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                      contentPadding:
                          const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }
}
