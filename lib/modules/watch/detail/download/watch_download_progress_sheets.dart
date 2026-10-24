import 'package:flutter/material.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/modules/more/download_queue/moviebox_card_widgets.dart'
    show mbGreen;

// ─────────────────────────────────────────────────────────────────────────────
// Sheets de suivi du téléchargement — extraits de watch_detail_view.dart :
//   • WatchDownloadPreparationSheet : progression de la préparation (file).
//   • WatchAfterDownloadSheet : confirmation une fois la file alimentée.
// ─────────────────────────────────────────────────────────────────────────────

class WatchDownloadPreparationSheet extends StatefulWidget {
  const WatchDownloadPreparationSheet({
    super.key,
    required this.count,
    required this.prepare,
    required this.onDone,
  });

  final int count;
  final Future<void> Function(
    ValueChanged<String> setStatus,
    ValueChanged<double> setProgress,
  ) prepare;
  final VoidCallback onDone;

  @override
  State<WatchDownloadPreparationSheet> createState() =>
      _WatchDownloadPreparationSheetState();
}

class _WatchDownloadPreparationSheetState
    extends State<WatchDownloadPreparationSheet> {
  String _status = 'Collecte des métadonnées…';
  double _progress = 0.08;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      await widget.prepare(
        (status) {
          if (mounted) setState(() => _status = status);
        },
        (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _status = 'Impossible de préparer le téléchargement';
        });
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          Navigator.of(context).pop();
          botToast('Le téléchargement n\'a pas pu être préparé.');
        }
      }
      return;
    }
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).colorScheme.onSurface;
    final muted = text.withValues(alpha: 0.58);
    final accent = Theme.of(context).primaryColor;
    const steps = [
      'Collecte des métadonnées',
      'Détection des sources',
      'Préparation des épisodes',
      'Ajout à la file',
    ];
    final completedSteps = _hasError
        ? 0
        : (_progress * steps.length).floor().clamp(0, steps.length).toInt();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasError
                      ? Icons.error_outline_rounded
                      : Icons.download_for_offline_rounded,
                  color: _hasError ? Colors.redAccent : accent,
                  size: 22,
                ),
                const SizedBox(width: 9),
                Text(
                  'Préparation de ${widget.count} fichier(s)',
                  style: TextStyle(
                    color: text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _hasError ? null : _progress,
                minHeight: 5,
                color: _hasError ? Colors.redAccent : accent,
                backgroundColor: text.withValues(alpha: 0.10),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: TextStyle(
                color: text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < steps.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      index < completedSteps
                          ? Icons.check_circle_rounded
                          : index == completedSteps && !_hasError
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: index < completedSteps
                          ? mbGreen
                          : index == completedSteps && !_hasError
                              ? accent
                              : muted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      steps[index],
                      style: TextStyle(
                        color: index <= completedSteps ? text : muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WatchAfterDownloadSheet extends StatelessWidget {
  const WatchAfterDownloadSheet({
    super.key,
    required this.count,
    required this.onView,
    required this.onWatch,
  });

  final int count;
  final VoidCallback onView;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = scheme.onSurface;
    final muted = text.withValues(alpha: 0.58);
    final faint = text.withValues(alpha: 0.30);
    final accent = Theme.of(context).primaryColor;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download_rounded, color: accent, size: 20),
                const SizedBox(width: 8),
                Text('Téléchargement $count fichier(s)',
                    style: TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: muted, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Regardez pendant le téléchargement, sans données supplémentaires.',
              style: TextStyle(color: muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onView,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: text,
                      side: BorderSide(color: faint),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Voir le téléchargement'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onWatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Regarder maintenant'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
