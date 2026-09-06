import 'package:flutter/material.dart';
import 'package:watchtower/models/source.dart';

// ─── Shared enums ────────────────────────────────────────────────────────────

/// Global status of one extension for the current run.
enum ExtStatus { idle, running, done, failed, skipped }

/// Export formats available after a completed run.
enum ReportFormat { markdown, json, text, csv }

// ─── Source row (compact list item) ─────────────────────────────────────────

class SourceRow extends StatelessWidget {
  final Source source;
  final ExtStatus status;
  final bool selected;
  final bool dimmed;
  final String? subtitle;
  final ColorScheme cs;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback? onOpenDetail;

  const SourceRow({
    required this.source,
    required this.status,
    required this.selected,
    required this.dimmed,
    required this.subtitle,
    required this.trailing,
    required this.cs,
    required this.onTap,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final s = source;
    final radius = BorderRadius.circular(11);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          decoration: BoxDecoration(
            color: selected
                ? cs.primaryContainer.withValues(alpha: 0.28)
                : cs.surfaceContainerLow
                    .withValues(alpha: dimmed ? 0.45 : 1),
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.45)
                  : cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(children: [
            if ((s.iconUrl ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.network(
                  s.iconUrl!,
                  width: 26,
                  height: 26,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackIcon(cs),
                ),
              )
            else
              _fallbackIcon(cs),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        s.name ?? '?',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: cs.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if ((s.lang ?? '').isNotEmpty) ...[const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s.lang!.toUpperCase(),
                            style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurfaceVariant,
                                letterSpacing: 0.4)),
                      ),
                    ],
                  ]),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(subtitle!,
                          style: TextStyle(
                              fontSize: 10.5, color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (trailing != null) trailing!,
          ]),
        ),
      ),
    );
  }

  Widget _fallbackIcon(ColorScheme cs) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(5),
        ),
        child:
            Icon(Icons.extension_rounded, size: 15, color: cs.onSurfaceVariant),
      );
}

// ─── Status dot ──────────────────────────────────────────────────────────────

class StatusDot extends StatefulWidget {
  final ExtStatus status;
  final ColorScheme cs;
  final double size;

  const StatusDot({
    required this.status,
    required this.cs,
    this.size = 8,
  });

  @override
  State<StatusDot> createState() => StatusDotState();
}

class StatusDotState extends State<StatusDot> with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.status == ExtStatus.running) _startPulse();
  }

  @override
  void didUpdateWidget(StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.status == ExtStatus.running && _pulse == null) {
      _startPulse();
    } else if (widget.status != ExtStatus.running && _pulse != null) {
      _pulse?.dispose();
      _pulse = null;
    }
  }

  void _startPulse() {
    _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
        lowerBound: 0.35)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.status) {
      ExtStatus.done => Colors.green.shade500,
      ExtStatus.failed => widget.cs.error,
      ExtStatus.running => Colors.amber.shade600,
      ExtStatus.skipped => widget.cs.outline,
      ExtStatus.idle => widget.cs.outlineVariant,
    };

    Widget dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (_pulse != null) {
      dot = FadeTransition(opacity: _pulse!, child: dot);
    }
    return SizedBox(
        width: widget.size + 8,
        height: widget.size + 8,
        child: Center(child: dot));
  }
}

class MiniCheck extends StatelessWidget {
  final bool checked;
  final ColorScheme cs;

  const MiniCheck({required this.checked, required this.cs});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked ? cs.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? cs.primary : cs.outlineVariant,
          width: 1.4,
        ),
      ),
      child: checked
          ? Icon(Icons.check_rounded, size: 14, color: cs.onPrimary)
          : null,
    );
  }
}

// ─── Mini chip ───────────────────────────────────────────────────────────────

class MiniChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;
  final bool danger;

  const MiniChip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (danger ? cs.errorContainer : cs.primaryContainer)
        : cs.surfaceContainerHigh;
    final fg = selected
        ? (danger ? cs.onErrorContainer : cs.onPrimaryContainer)
        : cs.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected
                  ? (danger ? cs.error : cs.primary)
                  : cs.outlineVariant.withValues(alpha: 0.6),
              width: selected ? 1 : 0.6,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: fg)),
        ),
      ),
    );
  }
}

// ─── Detail back bar (narrow) ────────────────────────────────────────────────

class DetailBar extends StatelessWidget {
  final Source source;
  final ColorScheme cs;
  final VoidCallback onBack;

  const DetailBar({
    required this.source,
    required this.cs,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 12, 2),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
            bottom:
                BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
          onPressed: onBack,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        ),
        Flexible(
          child: Text(source.name ?? 'Extension',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              overflow: TextOverflow.ellipsis),
        ),
        const Spacer(),
        Text('Détail',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

// ─── Premium empty state ─────────────────────────────────────────────────────

class EmptyHero extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ColorScheme cs;

  const EmptyHero({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: cs.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: cs.onSurface)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant,
                    height: 1.4)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(actionLabel!),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── Export bar ──────────────────────────────────────────────────────────────

class ExportBar extends StatelessWidget {
  final List<ReportFormat> formats;
  final ReportFormat active;
  final bool rawReport;
  final bool canCopy;
  final int savedCount;
  final ColorScheme cs;
  final ValueChanged<ReportFormat> onFormat;
  final VoidCallback onToggleRaw;
  final VoidCallback onCopy;

  const ExportBar({
    required this.formats,
    required this.active,
    required this.rawReport,
    required this.canCopy,
    required this.savedCount,
    required this.cs,
    required this.onFormat,
    required this.onToggleRaw,
    required this.onCopy,
  });

  static String formatLabel(ReportFormat f) => switch (f) {
        ReportFormat.markdown => 'Markdown (.md)',
        ReportFormat.json => 'JSON (.json)',
        ReportFormat.text => 'Texte (.txt)',
        ReportFormat.csv => 'CSV (.csv)',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
            bottom:
                BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Exporter le rapport',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface)),
          if (savedCount > 0) ...[
            const SizedBox(width: 8),
            Icon(Icons.folder_rounded, size: 13, color: cs.onSurfaceVariant),
            Text('$savedCount fichiers',
                style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
          ],
          const Spacer(),
          IconButton(
            icon: Icon(
                rawReport ? Icons.list_alt_rounded : Icons.code_rounded,
                size: 17,
                color: cs.onSurfaceVariant),
            onPressed: canCopy ? onToggleRaw : null,
            tooltip: rawReport ? 'Vue synthèse' : 'Voir le rapport brut',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 2),
          TextButton.icon(
            onPressed: canCopy ? onCopy : null,
            icon: const Icon(Icons.copy_rounded, size: 14),
            label: const Text('Copier', style: TextStyle(fontSize: 11.5)),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ]),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in formats) ...[
              ChoiceChip(
                label: Text(
                  formatLabel(f),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          f == active ? FontWeight.w700 : FontWeight.w500),
                ),
                selected: f == active,
                onSelected: (_) => onFormat(f),
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                showCheckmark: false,
              ),
              const SizedBox(width: 6),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ─── Raw report view ─────────────────────────────────────────────────────────

class RawReportView extends StatelessWidget {
  final String content;
  final String format;
  final ColorScheme cs;

  const RawReportView({
    required this.content,
    required this.format,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerLowest,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            Text('Rapport brut — $format',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant)),
            const Spacer(),
            Text('${content.length} caractères',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 8),
          SelectableText(
            content,
            style: TextStyle(
                fontSize: 10.5,
                fontFamily: 'monospace',
                height: 1.45,
                color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}
