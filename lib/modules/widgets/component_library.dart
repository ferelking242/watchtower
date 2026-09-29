import 'package:flutter/material.dart';

import 'package:watchtower/modules/media/app_ui_components.dart';

/// Generic 3-column swipeable section used when a page needs to show content
/// in column-major groups of three rows.
///
/// The section deliberately accepts a widget builder instead of a media model.
/// Callers pass the real card used by their page, so the gallery and production
/// screens can render the same widget without a second card implementation.
class ThreeColumnSwipeSection<T> extends StatelessWidget {
  const ThreeColumnSwipeSection({
    required this.title,
    required this.items,
    required this.itemBuilder,
    this.subtitle,
    this.onSeeAll,
    this.rows = 3,
    this.columns = 3,
    this.itemHeight = 86,
    this.itemSpacing = 10,
    this.columnSpacing = 12,
    this.state = ComponentSectionState.result,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback? onSeeAll;
  final int rows;
  final int columns;
  final double itemHeight;
  final double itemSpacing;
  final double columnSpacing;
  final ComponentSectionState state;

  @override
  Widget build(BuildContext context) {
    final safeRows = rows.clamp(1, 8).toInt();
    final safeColumns = columns.clamp(1, 6).toInt();
    final pageSize = safeRows * safeColumns;
    final pageCount = items.isEmpty ? 0 : (items.length / pageSize).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: title,
          actionLabel: onSeeAll == null ? null : 'All >',
          onAction: onSeeAll,
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: Text(
              subtitle!,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        switch (state) {
          ComponentSectionState.loading => const SizedBox(
            height: 280,
            child: AppMediaRowShimmer(),
          ),
          ComponentSectionState.empty => const _SectionMessage(
            icon: Icons.inbox_outlined,
            message: 'Aucun contenu',
          ),
          ComponentSectionState.error => const _SectionMessage(
            icon: Icons.error_outline_rounded,
            message: 'Impossible de charger cette section',
          ),
          ComponentSectionState.result when items.isEmpty => const _SectionMessage(
            icon: Icons.inbox_outlined,
            message: 'Aucun contenu',
          ),
          ComponentSectionState.result => SizedBox(
            height: safeRows * itemHeight + (safeRows - 1) * itemSpacing,
            child: PageView.builder(
              itemCount: pageCount,
              controller: PageController(viewportFraction: .94),
              itemBuilder: (context, page) {
                final start = page * pageSize;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var column = 0; column < safeColumns; column++) ...[
                      Expanded(
                        child: Column(
                          children: [
                            for (var row = 0; row < safeRows; row++)
                              if (start + column * safeRows + row < items.length)
                                ...[
                                  SizedBox(
                                    height: itemHeight,
                                    child: itemBuilder(
                                      context,
                                      items[start + column * safeRows + row],
                                    ),
                                  ),
                                  if (row < safeRows - 1)
                                    SizedBox(height: itemSpacing),
                                ],
                          ],
                        ),
                      ),
                      if (column < safeColumns - 1)
                        SizedBox(width: columnSpacing),
                    ],
                  ],
                );
              },
            ),
          ),
        },
      ],
    );
  }
}

enum ComponentSectionState { result, loading, empty, error }

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF171C23),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white54, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}