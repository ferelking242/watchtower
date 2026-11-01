import 'package:flutter/material.dart';

import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_manga.dart';
import 'package:watchtower/modules/media/content_cards.dart';

/// Generic suggestion panel for extensions that opt into search previews.
class ExtensionSearchPreview extends StatelessWidget {
  const ExtensionSearchPreview({
    required this.enabled,
    required this.query,
    required this.loading,
    required this.items,
    required this.onOpen,
    super.key,
  });

  final bool enabled;
  final String query;
  final bool loading;
  final List<MManga> items;
  final ValueChanged<MManga> onOpen;

  String _groupFor(MManga item) {
    final path = Uri.tryParse(item.link ?? '')?.path.toLowerCase() ?? '';
    if (path.contains('/channels/')) return 'CHAÎNES';
    if (path.contains('/pornstars/') || path.contains('/actresses/'))
      return 'ACTRICES';
    return 'VIDÉOS';
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        enabled && query.trim().length >= 2 && (loading || items.isNotEmpty);
    final groups = <String, List<MManga>>{
      'CHAÎNES': [],
      'ACTRICES': [],
      'VIDÉOS': [],
    };
    for (final item in items) {
      groups[_groupFor(item)]!.add(item);
    }
    final colors = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: visible
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Material(
                color: colors.surfaceContainerLow,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: loading && items.isEmpty
                      ? const SizedBox(
                          height: 66,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          children: [
                            for (final entry in groups.entries)
                              if (entry.value.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    8,
                                    14,
                                    5,
                                  ),
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                for (final item in entry.value)
                                  _ExtensionSearchPreviewRow(
                                    item: item,
                                    group: entry.key,
                                    onTap: () => onOpen(item),
                                  ),
                              ],
                          ],
                        ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _ExtensionSearchPreviewRow extends StatelessWidget {
  const _ExtensionSearchPreviewRow({
    required this.item,
    required this.group,
    required this.onTap,
  });

  final MManga item;
  final String group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isVideo = group == 'VIDÉOS';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: ContentImage(url: item.imageUrl, radius: 12),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name?.trim().isNotEmpty == true
                        ? item.name!.trim()
                        : 'Sans titre',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isVideo ? Broken.play : Broken.arrow_right_3,
              size: 17,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
