import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchtower/modules/home/widgets/home_header.dart'
    show showAccountSheet;
import 'package:watchtower/modules/more/about/providers/check_for_update.dart';
import 'package:watchtower/modules/more/providers/downloaded_only_state_provider.dart';
import 'package:watchtower/modules/main_view/main_screen.dart'
    show menuOpenProvider;

const _kOrderPrefKey = 'menu_items_order';

class _SpeedItem {
  final String id;
  final String label;
  final IconData icon;
  final void Function(BuildContext context, WidgetRef ref) action;

  const _SpeedItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.action,
  });
}

final _kDefaultItems = <_SpeedItem>[
  _SpeedItem(
    id: 'search',
    label: 'Search',
    icon: Icons.search_rounded,
    action: (ctx, ref) => ctx.go('/globalSearch'),
  ),
  _SpeedItem(
    id: 'signin',
    label: 'Sign in',
    icon: Icons.login_rounded,
    action: (ctx, ref) => showAccountSheet(ctx),
  ),
  _SpeedItem(
    id: 'update',
    label: 'Update available',
    icon: Icons.system_update_alt_rounded,
    action: (ctx, ref) => ref.read(checkForUpdateProvider(context: ctx)),
  ),
  _SpeedItem(
    id: 'anilist',
    label: 'Refresh AniList',
    icon: Icons.sync_rounded,
    action: (ctx, ref) => ctx.go('/trackerLibrary'),
  ),
  _SpeedItem(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    action: (ctx, ref) => ctx.go('/settings'),
  ),
  _SpeedItem(
    id: 'offline',
    label: 'Offline',
    icon: Icons.cloud_off_rounded,
    action: (ctx, ref) {
      final current = ref.read(downloadedOnlyStateProvider);
      ref
          .read(downloadedOnlyStateProvider.notifier)
          .setDownloadedOnly(!current);
    },
  ),
  _SpeedItem(
    id: 'extensions',
    label: 'Extensions',
    icon: Icons.extension_rounded,
    action: (ctx, ref) => ctx.go('/browse'),
  ),
  _SpeedItem(
    id: 'torrent',
    label: 'Torrent list',
    icon: Icons.cloud_download_outlined,
    action: (ctx, ref) => ctx.go('/settings'),
  ),
  _SpeedItem(
    id: 'manga',
    label: 'Manga',
    icon: Icons.auto_stories,
    action: (ctx, ref) => ctx.go('/MangaLibrary'),
  ),
  _SpeedItem(
    id: 'schedule',
    label: 'Schedule',
    icon: Icons.calendar_month_rounded,
    action: (ctx, ref) => ctx.go('/schedule'),
  ),
];

class WatchtowerSpeedDial extends ConsumerStatefulWidget {
  const WatchtowerSpeedDial({super.key});

  @override
  ConsumerState<WatchtowerSpeedDial> createState() =>
      _WatchtowerSpeedDialState();
}

class _WatchtowerSpeedDialState extends ConsumerState<WatchtowerSpeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _labelCtrl;
  List<_SpeedItem> _orderedItems = List.from(_kDefaultItems);

  @override
  void initState() {
    super.initState();
    _labelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadOrder();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  void _onOpen() {
    HapticFeedback.mediumImpact();
    if (mounted) ref.read(menuOpenProvider.notifier).state = true;
    // Labels appear 150ms after icons start rising
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _labelCtrl.forward(from: 0);
    });
  }

  void _onClose() {
    HapticFeedback.lightImpact();
    if (mounted) {
      ref.read(menuOpenProvider.notifier).state = false;
      _labelCtrl.reverse();
    }
  }

  Future<void> _loadOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kOrderPrefKey);
      if (json != null) {
        final ids = List<String>.from(jsonDecode(json) as List);
        final itemMap = {for (final it in _kDefaultItems) it.id: it};
        final ordered = <_SpeedItem>[];
        for (final id in ids) {
          if (itemMap.containsKey(id)) ordered.add(itemMap[id]!);
        }
        // Append any new items not yet in saved order
        for (final it in _kDefaultItems) {
          if (!ids.contains(it.id)) ordered.add(it);
        }
        if (mounted) setState(() => _orderedItems = ordered);
      }
    } catch (_) {}
  }

  Future<void> _saveOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kOrderPrefKey,
        jsonEncode(_orderedItems.map((e) => e.id).toList()),
      );
    } catch (_) {}
  }

  Future<void> _showReorderSheet() async {
    if (!mounted) return;
    final newOrder = await showModalBottomSheet<List<_SpeedItem>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ReorderSheet(items: List.from(_orderedItems)),
    );
    if (newOrder != null && mounted) {
      setState(() => _orderedItems = newOrder);
      _saveOrder();
    }
  }

  SpeedDialChild _buildChild(
    _SpeedItem item,
    int dialIndex,
    bool isDark,
    ColorScheme cs,
  ) {
    // dialIndex 0 = bottom (first to appear, closest to FAB)
    // Stagger: 50ms per item → 50/600 ≈ 0.083 of controller span
    final t = dialIndex * 0.083;
    final anim = CurvedAnimation(
      parent: _labelCtrl,
      curve: Interval(
        min(0.9, t),
        min(1.0, t + 0.33),
        curve: Curves.easeOut,
      ),
    );

    return SpeedDialChild(
      child: Icon(item.icon, size: 22),
      backgroundColor: isDark
          ? const Color(0xFF0F0F14)
          : const Color(0xFFE4E4E8),
      foregroundColor: isDark ? Colors.white.withValues(alpha: 0.88) : Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelWidget: _AnimatedLabel(
        label: item.label,
        isDark: isDark,
        animation: anim,
        onLongPress: _showReorderSheet,
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        Future.delayed(
          const Duration(milliseconds: 120),
          () {
            if (mounted) item.action(context, ref);
          },
        );
      },
      onLongPress: _showReorderSheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // SpeedDial shows children[0] closest to FAB (bottom).
    // User default order: Search=top, Schedule=bottom → pass reversed.
    final dialItems = _orderedItems.reversed.toList();

    return SpeedDial(
      onOpen: _onOpen,
      onClose: _onClose,
      direction: SpeedDialDirection.up,
      animationDuration: const Duration(milliseconds: 250),
      animationCurve: Curves.easeOutBack,
      overlayColor: Colors.black,
      overlayOpacity: 0.6,
      icon: Icons.menu_rounded,
      activeIcon: Icons.close_rounded,
      useRotationAnimation: true,
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      shape: const CircleBorder(),
      spacing: 12,
      spaceBetweenChildren: 8,
      buttonSize: const Size(56, 56),
      childrenButtonSize: const Size(52, 52),
      children: [
        for (int i = 0; i < dialItems.length; i++)
          _buildChild(dialItems[i], i, isDark, cs),
      ],
    );
  }
}

class _AnimatedLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  final Animation<double> animation;
  final VoidCallback onLongPress;

  const _AnimatedLabel({
    required this.label,
    required this.isDark,
    required this.animation,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(-10.0 * (1.0 - animation.value), 0),
          child: child,
        ),
      ),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F0F14)
                : const Color(0xFFF0F0F4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.drag_handle_rounded,
                size: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.40)
                    : Colors.black.withValues(alpha: 0.30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReorderSheet extends StatefulWidget {
  final List<_SpeedItem> items;

  const _ReorderSheet({required this.items});

  @override
  State<_ReorderSheet> createState() => _ReorderSheetState();
}

class _ReorderSheetState extends State<_ReorderSheet> {
  late List<_SpeedItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, mq.padding.bottom + 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.70),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
            child: Row(
              children: [
                Icon(Icons.drag_handle_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Réorganiser le menu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _items),
                  child: Text(
                    'Valider',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.onSurface.withValues(alpha: 0.10),
          ),
          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              proxyDecorator: (child, index, animation) =>
                  Material(color: Colors.transparent, child: child),
              onReorder: (oldIndex, newIndex) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
              },
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  key: ValueKey(item.id),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, size: 18, color: cs.onSurface),
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  trailing: Icon(
                    Icons.drag_handle_rounded,
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.35),
                  ),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
