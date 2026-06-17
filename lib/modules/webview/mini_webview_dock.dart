import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/services/mini_webview_state.dart';

/// Floating pill that groups minimised WebView tabs.
/// 1 tab  → tap opens directly.
/// 2+ tabs → tap opens the tab-manager sheet.
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
          // Sit above the floating navigation dock (64 px pill + 14 px pad)
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

  void _openAt(BuildContext context, int index) {
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

  void _openFirst(BuildContext context) => _openAt(context, 0);

  void _showTabManager(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _TabManagerSheet(
        onOpenTab: (index) {
          Navigator.pop(ctx);
          _openAt(context, index);
        },
        onCloseAll: () {
          Navigator.pop(ctx);
          ref.read(miniWebViewProvider.notifier).clear();
        },
        onCloseTab: (index) =>
            ref.read(miniWebViewProvider.notifier).removeAt(index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = tabs.length;
    final title = tabs.first.title.isNotEmpty ? tabs.first.title : 'Page web';
    final label = count > 1 ? '$count onglets' : title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () =>
            count >= 2 ? _showTabManager(context) : _openFirst(context),
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
              count >= 2
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
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
                  : Icon(Icons.language_rounded,
                      color: Colors.white.withValues(alpha: 0.85), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                    : _openFirst(context),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.55), size: 20),
                onPressed: () =>
                    ref.read(miniWebViewProvider.notifier).clear(),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab manager sheet ─────────────────────────────────────────────────────────
// Pure ConsumerWidget — no WidgetRef constructor param needed.

class _TabManagerSheet extends ConsumerWidget {
  final void Function(int) onOpenTab;
  final void Function(int) onCloseTab;
  final VoidCallback onCloseAll;

  const _TabManagerSheet({
    required this.onOpenTab,
    required this.onCloseTab,
    required this.onCloseAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(miniWebViewProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    if (tabs.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
              child: Row(
                children: [
                  Text(
                    '${tabs.length} onglet${tabs.length > 1 ? 's' : ''}'
                    ' ouvert${tabs.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onCloseAll,
                    icon: Icon(Icons.close_rounded,
                        size: 15, color: cs.error),
                    label: Text(
                      'Fermer tous',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.error,
                        fontWeight: FontWeight.w600,
                      ),
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
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: tabs.length,
                itemBuilder: (context, index) {
                  final tab = tabs[index];
                  return ListTile(
                    onTap: () => onOpenTab(index),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.language_rounded,
                          size: 18, color: cs.primary),
                    ),
                    title: Text(
                      tab.title.isNotEmpty ? tab.title : 'Page web',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w500),
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
                      icon: Icon(Icons.close_rounded,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.40)),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onCloseTab(index);
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
    );
  }
}
