import 'package:flutter/material.dart';

import 'package:watchtower/modules/media/widgets/bulk_enqueue_controller.dart';
import 'package:watchtower/modules/more/download_queue/moviebox_card_widgets.dart';

/// Box shown while the selected videos are pushed to the download queue.
///
/// It has a real header (title + counters), an animated list of the items being
/// processed, a pause/resume button and a "mettre en arrière-plan" button that
/// hands the run over to a notification carrying pause/resume/cancel actions.
class BulkEnqueueDialog extends StatefulWidget {
  const BulkEnqueueDialog({
    required this.controller,
    required this.titles,
    required this.onBackground,
    super.key,
  });

  final BulkEnqueueController controller;
  final List<String> titles;
  final VoidCallback onBackground;

  @override
  State<BulkEnqueueDialog> createState() => _BulkEnqueueDialogState();
}

class _BulkEnqueueDialogState extends State<BulkEnqueueDialog> {
  bool _dismissScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_dismissWhenFinished);
    if (widget.controller.finished) _scheduleDismiss();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_dismissWhenFinished);
    super.dispose();
  }

  void _dismissWhenFinished() {
    if (widget.controller.finished) _scheduleDismiss();
  }

  void _scheduleDismiss() {
    if (_dismissScheduled) return;
    _dismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surfaceContainerHigh,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(cs, c),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: c.cancelled ? null : c.progress,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.titles.length,
                    itemBuilder: (context, i) => _itemCard(cs, c, i),
                  ),
                ),
                const SizedBox(height: 10),
                _actions(cs, c),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(ColorScheme cs, BulkEnqueueController c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.cancelled
                    ? 'Annulation…'
                    : c.paused
                    ? 'Mise en file en pause'
                    : 'Mise en file d’attente',
                style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '${c.done}/${c.total} éléments'
                '${c.queued > 0 ? ' · ${c.queued} vidéo(s)' : ''}'
                '${c.failed > 0 ? ' · ${c.failed} échec(s)' : ''}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(Icons.download_rounded, color: cs.primary, size: 22),
      ],
    );
  }

  /// One animated row per catalogue entry, revealing as the run advances.
  Widget _itemCard(ColorScheme cs, BulkEnqueueController c, int index) {
    final isProcessing = index == c.done;
    final isDone = index < c.done;
    final title = index < widget.titles.length ? widget.titles[index] : 'Élément ${index + 1}';
    return AnimatedOpacity(
      opacity: index <= c.done ? 1 : 0.45,
      duration: const Duration(milliseconds: 220),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: isProcessing ? Border.all(color: cs.primary.withValues(alpha: 0.6)) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: isDone
                  ? const Icon(Icons.check_circle_rounded, size: 16, color: mbGreen)
                  : isProcessing
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Icon(Icons.schedule_rounded, size: 16, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurface, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(ColorScheme cs, BulkEnqueueController c) {
    final isPaused = c.paused;
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            onPressed: c.cancelled || c.finished ? null : c.togglePause,
            icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
            label: Text(isPaused ? 'Reprendre' : 'Pause'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextButton.icon(
            onPressed: c.cancelled || c.finished ? null : widget.onBackground,
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Arrière-plan', overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: c.cancelled ? null : c.cancel,
          child: Text('Annuler', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }
}
