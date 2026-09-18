import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/download.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/more/download_queue/moviebox_card_widgets.dart';

/// The page opened by the Downloads item in the dock menu.
///
/// This used to be deleted while the router still referenced
/// `DownloadQueueScreen`, leaving the route without a valid page. Keep the
/// queue page small and independent from the settings pages so an empty queue
/// still renders a useful screen.
class DownloadQueueScreen extends ConsumerWidget {
  const DownloadQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Téléchargements'),
      ),
      body: StreamBuilder<List<Download>>(
        stream: isar.downloads.where().watch(fireImmediately: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _QueueMessage(
              icon: Icons.error_outline_rounded,
              title: 'Impossible de charger les téléchargements',
              detail: '${snapshot.error}',
              color: scheme.error,
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final downloads = snapshot.data!;
          if (downloads.isEmpty) {
            return const _QueueMessage(
              icon: Icons.download_done_rounded,
              title: 'Aucun téléchargement',
              detail: 'Les téléchargements en cours apparaîtront ici.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: downloads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _DownloadTile(download: downloads[index]),
          );
        },
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.download});

  final Download download;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _progress;
    final failed = download.failed == 1 || download.status == 'failed';
    final completed = download.isDownload == true || download.status == 'done';
    final title = (download.title ?? '').trim();
    final subtitle = (download.quality ?? download.status ?? '').trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 68,
              child: MbThumb(
                imageUrl: download.posterUrl,
                customBytes: null,
                itemType: ItemType.anime,
                badge: completed ? 'TERMINÉ' : 'DOWNLOAD',
                isVideo: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Téléchargement' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.62),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  MbGradientProgressBar(
                    value: progress,
                    paused: download.isStartDownload == false,
                    failed: failed,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              failed
                  ? Icons.error_outline_rounded
                  : completed
                      ? Icons.check_circle_rounded
                      : Icons.downloading_rounded,
              color: failed
                  ? scheme.error
                  : completed
                      ? mbGreen
                      : scheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  double get _progress {
    final exactTotal = download.totalBytes;
    final exactDone = download.downloadedBytes;
    if (exactTotal != null && exactTotal > 0 && exactDone != null) {
      return (exactDone / exactTotal).clamp(0.0, 1.0).toDouble();
    }

    final total = download.total ?? 0;
    final done = download.succeeded ?? 0;
    if (total <= 0) return download.isDownload == true ? 1 : 0;
    return (done / total).clamp(0.0, 1.0).toDouble();
  }
}

class _QueueMessage extends StatelessWidget {
  const _QueueMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: color ?? scheme.primary.withValues(alpha: 0.82),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.64),
              ),
            ),
          ],
        ),
      ),
    );
  }
}