import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/services/mini_webview_state.dart';

/// Floating tab grouper overlay — shown whenever WebView tabs are minimized.
/// Tap = expand the most recent tab. X = close all.
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
        child: _TabGroupPill(tabs: tabs, ref: ref),
      ),
    );
  }
}

class _TabGroupPill extends StatelessWidget {
  final List<MiniWebViewEntry> tabs;
  final WidgetRef ref;
  const _TabGroupPill({required this.tabs, required this.ref});

  void _expand(BuildContext context) {
    final entry = ref.read(miniWebViewProvider.notifier).pop();
    if (entry != null) {
      context.push('/mangawebview', extra: {
        'url': entry.url,
        'title': entry.title,
        'initialFraction': 0.0,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = tabs.first;
    final extra = tabs.length - 1;
    final label = first.title.isNotEmpty ? first.title : 'Page web';
    final fullLabel =
        extra > 0 ? '$label & $extra autre${extra > 1 ? "s" : ""}' : label;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
      child: GestureDetector(
        onTap: () => _expand(context),
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
              Icon(
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
              // Expand button
              IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 22,
                ),
                onPressed: () => _expand(context),
                tooltip: 'Ouvrir',
              ),
              // Close all button
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
