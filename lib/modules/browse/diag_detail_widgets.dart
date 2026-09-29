import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_bypass_panel.dart';
import 'package:watchtower/modules/anti_bot/cloudflare_error_widget.dart'
    show isCloudflareError;
import 'package:watchtower/modules/browse/diag_ui_widgets.dart' show ExtStatus;
import 'package:watchtower/modules/browse/diag_video_preview.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/services/extension_diagnostics.dart';

String _fmtMs(int ms) {
  if (ms <= 0) return '—';
  if (ms < 1000) return '${ms}ms';
  final s = ms ~/ 1000;
  if (s < 60) return '${s}.${((ms % 1000) ~/ 100)}s';
  return '${s ~/ 60}m${(s % 60).toString().padLeft(2, "0")}s';
}

// ─── Extension detail ────────────────────────────────────────────────────────

class ExtensionDetail extends StatelessWidget {
  final Source source;
  final ExtDiagResult? result;
  final ExtStatus status;
  final bool running;
  final ItemType itemType;
  final ColorScheme cs;
  final VoidCallback? onRetry;
  final VoidCallback? onResolveCloudflare;

  const ExtensionDetail({
    super.key,
    required this.source,
    required this.result,
    required this.status,
    required this.running,
    required this.itemType,
    required this.cs,
    required this.onRetry,
    required this.onResolveCloudflare,
  });

  bool get _hasCloudflareError {
    final r = result;
    if (r == null) return false;
    return r.failedWithReason.any((e) => isCloudflareError(e.value.error));
  }

  @override
  Widget build(BuildContext context) {
    final src = source;
    final r = result;

    if (r == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerRow(context),
          const SizedBox(height: 18),
          if (status == ExtStatus.running || running)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(children: [
                  SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: cs.primary)),
                  const SizedBox(height: 10),
                  Text('Diagnostic en cours…',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ]),
              ),
            )
          else
            Column(children: [
              Icon(Icons.schedule_rounded, size: 42, color: cs.outlineVariant),
              const SizedBox(height: 10),
              Text('En attente du diagnostic',
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              if (onRetry != null) ...[const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Tester cette extension'),
                ),
              ],
            ]),
        ],
      );
    }

    final allOk = r.allOk;
    final cancelled = r.cancelled;
    final stepLabel = diagStepLabel;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _headerRow(context),
        if (cancelled) ...[
          const SizedBox(height: 10),
          _noticeRow(
            icon: Icons.stop_circle_outlined,
            text: 'Diagnostic interrompu — certaines étapes n’ont pas pu être exécutées.',
          ),
        ] else if (!allOk) ...[const SizedBox(height: 10), _errorSummary(context)],
        // Inline Cloudflare resolution — rendered here, no separate webview.
        if (_hasCloudflareError && !running && (src.baseUrl ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          CloudflareBypassPanel(
            url: src.baseUrl!,
            compact: true,
            onResolved: onResolveCloudflare,
            onRetry: onRetry,
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'Étapes — Popular · Latest · Détail · ${itemType == ItemType.anime ? "Vidéos" : "Pages"}',
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final step in DiagStep.values)
          if (r.steps.containsKey(step))
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: StepTile(
                step: step,
                stepResult: r.steps[step]!,
                label: stepLabel(step, itemType),
                cs: cs,
              ),
            ),
        if (r.steps[DiagStep.media]?.ok == true && r.previewUrls.isNotEmpty) ...[
          const SizedBox(height: 6),
          MediaPreviewSection(
            previewUrls: r.previewUrls,
            mediaCount: r.steps[DiagStep.media]?.count ?? 0,
            itemType: itemType,
            cs: cs,
          ),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: running || onRetry == null ? null : onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retester cette extension',
                  style: TextStyle(fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _noticeRow({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
        ),
      ]),
    );
  }

  Widget _errorSummary(BuildContext context) {
    final r = result!;
    final first = r.failedWithReason.isEmpty
        ? null
        : r.failedWithReason.first;
    final reason = first != null && first.value.error != null
        ? '${diagStepLabel(first.key, itemType)} — ${first.value.error}'
        : '${r.failCount} étape(s) en échec — ouvrez chaque étape pour les logs.';
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: cs.error.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, size: 16, color: cs.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(reason,
              style: TextStyle(fontSize: 11.5, color: cs.onSurface),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 6),
        Text('${r.failCount} ✗',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: cs.error)),
      ]),
    );
  }

  Widget _headerRow(BuildContext context) {
    final src = source;
    final r = result;
    final allOk = r?.allOk == true;
    final cancelled = r?.cancelled == true;
    final totalMs = r?.totalMs ?? 0;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if ((src.iconUrl ?? '').isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.network(
            src.iconUrl!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.extension_rounded, size: 40, color: cs.onSurfaceVariant),
          ),
        )
      else
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.extension_rounded,
              size: 22, color: cs.onSurfaceVariant),
        ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(src.name ?? 'Inconnue',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Wrap(spacing: 4, runSpacing: 4, children: [
            _TagChip(label: (src.lang ?? '?').toUpperCase(), cs: cs),
            if (src.sourceCodeLanguage != null)
              _TagChip(
                  label: src.sourceCodeLanguage!.name,
                  cs: cs,
                  bg: cs.secondaryContainer,
                  fg: cs.onSecondaryContainer),
            if (src.isNsfw == true)
              _TagChip(
                  label: 'NSFW',
                  cs: cs,
                  bg: cs.errorContainer.withValues(alpha: 0.5),
                  fg: cs.onErrorContainer),
            if (src.hasCloudflare == true)
              _TagChip(
                  label: 'Cloudflare', cs: cs, icon: Icons.shield_outlined),
          ]),
        ]),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cancelled
                ? cs.surfaceContainerHighest
                : allOk
                    ? Colors.green.withValues(alpha: 0.12)
                    : cs.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            cancelled
                ? 'Interrompu'
                : allOk
                    ? '✓ OK'
                    : '✗ ${r!.failCount}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: cancelled
                    ? cs.onSurfaceVariant
                    : allOk
                        ? Colors.green.shade700
                        : cs.error),
          ),
        ),
        if (totalMs > 0) ...[
          const SizedBox(height: 4),
          Text(_fmtMs(totalMs),
              style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
        ],
      ]),
    ]);
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final Color? bg;
  final Color? fg;
  final IconData? icon;

  const _TagChip({required this.label, required this.cs, this.bg, this.fg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 10, color: fg ?? cs.onSurfaceVariant),
          const SizedBox(width: 3),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: fg ?? cs.onSurfaceVariant,
                letterSpacing: 0.3)),
      ]),
    );
  }
}

// ─── Step tile (status + error + expandable logs) ────────────────────────────

class StepTile extends StatefulWidget {
  final DiagStep step;
  final DiagStepResult stepResult;
  final String label;
  final ColorScheme cs;

  const StepTile({
    required this.step,
    required this.stepResult,
    required this.label,
    required this.cs,
  });

  @override
  State<StepTile> createState() => StepTileState();
}

class StepTileState extends State<StepTile> {
  bool _open = false;

  IconData get _icon => switch (widget.step) {
        DiagStep.popular => Icons.local_fire_department_outlined,
        DiagStep.latest => Icons.update_rounded,
        DiagStep.detail => Icons.info_outline_rounded,
        DiagStep.media => Icons.play_circle_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final r = widget.stepResult;
    final cs = widget.cs;
    final ok = r.ok;
    final color = ok ? Colors.green.shade600 : cs.error;
    final hasError = !ok && r.error != null;
    final hasLogs = r.hasLogs;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok
              ? cs.outlineVariant.withValues(alpha: 0.7)
              : cs.error.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: hasLogs ? () => setState(() => _open = !_open) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(widget.label,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: cs.onSurface)),
                      const SizedBox(width: 6),
                      Text(r.count != null ? '${r.count} résultats' : '…',
                          style: TextStyle(
                              fontSize: 10, color: cs.onSurfaceVariant)),
                    ]),
                    if (hasError)
                      Text(
                        r.error!,
                        style: TextStyle(
                            fontSize: 10.5,
                            color: cs.error,
                            fontFamily: 'monospace',
                            height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(_fmtMs(r.ms),
                  style: TextStyle(
                      fontSize: 10.5,
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: 8),
              ok
                  ? Icon(Icons.check_circle_rounded,
                      size: 16, color: Colors.green.shade500)
                  : Icon(Icons.cancel_rounded, size: 16, color: cs.error),
              if (hasLogs) ...[
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.expand_more_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                ),
              ],
            ]),
          ),
        ),
        if (_open && hasLogs)
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LOGS — ${widget.label.toUpperCase()}',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 5),
                for (final l in r.logs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: SelectableText(l,
                        style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: cs.onSurface,
                            height: 1.35)),
                  ),
                if (r.logs.isEmpty)
                  Text('Aucune trace pour cette étape.',
                      style:
                          TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
      ]),
    );
  }
}

// ─── Media preview section ───────────────────────────────────────────────────

class MediaPreviewSection extends StatefulWidget {
  final List<DiagMediaUrl> previewUrls;
  final int mediaCount;
  final ItemType itemType;
  final ColorScheme cs;

  const MediaPreviewSection({
    required this.previewUrls,
    required this.mediaCount,
    required this.itemType,
    required this.cs,
  });

  @override
  State<MediaPreviewSection> createState() => MediaPreviewSectionState();
}

class MediaPreviewSectionState extends State<MediaPreviewSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isAnime = widget.itemType == ItemType.anime;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
            child: Row(children: [
              Icon(
                  isAnime
                      ? Icons.play_circle_outline_rounded
                      : Icons.auto_stories_outlined,
                  size: 17,
                  color: cs.primary),
              const SizedBox(width: 8),
              Text(
                  isAnime ? 'Prévisualisation vidéo' : 'Prévisualisation pages',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${widget.mediaCount} sources',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer)),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(Icons.expand_more_rounded,
                    size: 18, color: cs.onSurfaceVariant),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: isAnime
                ? DiagVideoPreview(urls: widget.previewUrls, cs: cs)
                : _PagePreview(urls: widget.previewUrls, cs: cs),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }
}

// ─── Manga page preview ──────────────────────────────────────────────────────

class _PagePreview extends StatefulWidget {
  final List<DiagMediaUrl> urls;
  final ColorScheme cs;

  const _PagePreview({required this.urls, required this.cs});

  @override
  State<_PagePreview> createState() => _PagePreviewState();
}

class _PagePreviewState extends State<_PagePreview> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final urls = widget.urls;

    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _currentPage > 0
                ? () {
                    _pageCtrl.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut);
                  }
                : null,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Text('Page ${_currentPage + 1} / ${urls.length}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _currentPage < urls.length - 1
                ? () {
                    _pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut);
                  }
                : null,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 260,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) {
              final url = urls[i];
              return Image.network(
                url.url,
                headers: url.headers,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Center(
                      child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: cs.primary,
                          strokeWidth: 2));
                },
                errorBuilder: (_, __, ___) => Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.broken_image_rounded,
                      size: 36, color: cs.outlineVariant),
                  const SizedBox(height: 6),
                  Text('Image inaccessible',
                      style:
                          TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                ])),
              );
            },
          ),
        ),
      ),
    ]);
  }
}

// ─── Result card (results page) ──────────────────────────────────────────────

class ResultCard extends StatefulWidget {
  final ExtDiagResult result;
  final ItemType itemType;
  final ColorScheme cs;
  final VoidCallback onOpen;

  const ResultCard({
    required this.result,
    required this.itemType,
    required this.cs,
    required this.onOpen,
  });

  @override
  State<ResultCard> createState() => ResultCardState();
}

class ResultCardState extends State<ResultCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final cs = widget.cs;
    final allOk = r.allOk;
    final cancelled = r.cancelled;
    final accent = cancelled
        ? cs.onSurfaceVariant
        : allOk
            ? Colors.green.shade600
            : cs.error;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: allOk
              ? cs.outlineVariant.withValues(alpha: 0.6)
              : accent.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 8, 6, 8),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 9),
              if ((r.source.iconUrl ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.network(r.source.iconUrl!,
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.extension_rounded,
                          size: 24,
                          color: cs.onSurfaceVariant)),
                )
              else
                Icon(Icons.extension_rounded, size: 24, color: cs.onSurfaceVariant),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.source.name ?? '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis),
                    Row(children: [
                      for (final e in r.steps.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            e.value.ok
                                ? Icons.check_circle_rounded
                                : e.value.error == null
                                    ? Icons.remove_circle_outline_rounded
                                    : Icons.cancel_rounded,
                            size: 12,
                            color: e.value.ok
                                ? Colors.green.shade400
                                : cs.error,
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
              Text(
                r.okCount == r.steps.length && r.steps.isNotEmpty
                    ? 'Tout OK'
                    : '${r.okCount}/${r.steps.length}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accent),
              ),
              const SizedBox(width: 10),
              Text(_fmtMs(r.totalMs),
                  style: TextStyle(
                      fontSize: 10.5,
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded,
                    size: 18, color: cs.primary),
                onPressed: widget.onOpen,
                tooltip: 'Ouvrir le détail',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 11, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in r.failedWithReason)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: cs.error.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${diagStepLabel(e.key, widget.itemType)} — '
                            '${e.value.ms > 0 ? _fmtMs(e.value.ms) : "non testé"}',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: cs.error)),
                        const SizedBox(height: 3),
                        SelectableText(e.value.error ?? '',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                color: cs.onSurface)),
                        if (e.value.hasLogs) ...[
                          const SizedBox(height: 4),
                          Text(
                              '${e.value.logs.length} lignes de log — ouvrez le détail pour les consulter',
                              style: TextStyle(
                                  fontSize: 9.5, color: cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                ),
              if (r.failedWithReason.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: Colors.green.shade500),
                    const SizedBox(width: 6),
                    Text('Aucune erreur détectée sur les étapes.',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ]),
                ),
            ]),
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ]),
    );
  }
}
