import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/services/anti_bot/bypass_webview_sheet.dart';
import 'package:watchtower/services/anti_bot/remote_bypass_service.dart';
import 'package:watchtower/models/settings.dart';

bool isCloudflareError(String? error) {
    if (error == null) return false;
    final l = error.toLowerCase();
    return l.contains('cloudflare') ||
        l.contains('cf_clearance') ||
        l.contains('challenge') ||
        l.contains('failed to bypass') ||
        l.contains('just a moment') ||
        l.contains('attention required') ||
        l.contains('cf-ray') ||
        (l.contains('503') && l.contains('server')) ||
        (l.contains('403') && l.contains('cloud')) ||
        (l.contains('timeout') && l.contains('connection'));
  }

class CloudflareErrorWidget extends StatefulWidget {
  final String? errorText;
  final String? url;
  final VoidCallback? onRetry;

  const CloudflareErrorWidget({
    super.key,
    this.errorText,
    this.url,
    this.onRetry,
  });

  @override
  State<CloudflareErrorWidget> createState() => _CloudflareErrorWidgetState();
}

class _CloudflareErrorWidgetState extends State<CloudflareErrorWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  bool _remoteConfigured = false;
  bool _remoteLoading = false;
  String? _remoteError;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
    _checkRemote();
  }

  Future<void> _checkRemote() async {
    final settings = await RemoteBypassService.instance.loadSettings();
    if (mounted) {
      setState(() => _remoteConfigured = settings.isConfigured);
    }
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _beatChallenge() async {
      if (widget.url == null) return;
      final resolved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.92,
            child: BypassWebViewSheet(url: widget.url!),
          ),
        ),
      );
      if (resolved == true && mounted) {
          // Grace period so cf_clearance cookie propagates to extension HTTP client
          await Future.delayed(const Duration(milliseconds: 1200));
          if (mounted) widget.onRetry?.call();
        }
    }

  Future<void> _useRemote() async {
    if (widget.url == null) return;
    setState(() {
      _remoteLoading = true;
      _remoteError = null;
    });
    final result = await RemoteBypassService.instance.solve(widget.url!);
    if (!mounted) return;
    setState(() => _remoteLoading = false);
    if (result.success) {
      widget.onRetry?.call();
    } else {
      setState(() => _remoteError = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _floatAnim,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _floatAnim.value),
                  child: const _GuardBot3D(),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Source bloquée',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Cette source est protégée par un système anti-bot (Cloudflare). '
                'Vous devez résoudre le challenge pour y accéder.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (_remoteError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _remoteError!,
                    style: TextStyle(fontSize: 11.5, color: cs.onErrorContainer),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              // ── Beat challenge button ────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: _GlowButton(
                  label: 'Affronter le challenge',
                  icon: Icons.shield_rounded,
                  color: cs.primary,
                  onTap: widget.url != null ? _beatChallenge : null,
                ),
              ),
              const SizedBox(height: 12),
              // ── Remote bypass button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: _remoteConfigured
                    ? _GlowButton(
                        label: _remoteLoading
                            ? 'Contournement en cours…'
                            : 'Contourner via serveur distant',
                        icon: Icons.cloud_sync_rounded,
                        color: cs.secondary,
                        loading: _remoteLoading,
                        onTap: (!_remoteLoading && widget.url != null)
                            ? _useRemote
                            : null,
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: cs.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        onPressed: () => context.push('/advanced'),
                        icon: const Icon(Icons.settings_ethernet_rounded,
                            size: 18),
                        label: const Text(
                          'Configurer un serveur distant',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
              ),
              if (widget.errorText != null) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _showDetails(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        'Voir les détails',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.4,
        builder: (ctx, ctrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            controller: ctrl,
            child: SelectableText(
              widget.errorText ?? '',
              style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated 3D Guard Bot Character ─────────────────────────────────────────

class _GuardBot3D extends StatelessWidget {
  const _GuardBot3D();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(
        painter: _GuardBotPainter(
          primary: cs.primary,
          secondary: cs.secondary,
          surface: cs.surfaceContainerHighest,
          onSurface: cs.onSurface,
          error: cs.error,
        ),
      ),
    );
  }
}

class _GuardBotPainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color onSurface;
  final Color error;

  _GuardBotPainter({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.onSurface,
    required this.error,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final paint = Paint()..isAntiAlias = true;

    // ── Shadow ────────────────────────────────────────────────────────────
    paint
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.9),
        width: 90,
        height: 18,
      ),
      paint,
    );
    paint.maskFilter = null;

    // ── Body (torso) ───────────────────────────────────────────────────────
    final bodyGrad = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 0.9,
      colors: [
        primary.withValues(alpha: 0.9),
        primary.withValues(alpha: 0.4),
        secondary.withValues(alpha: 0.6),
      ],
    );
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, size.height * 0.64),
      width: 64,
      height: 72,
    );
    paint.shader = bodyGrad.createShader(bodyRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(16)),
      paint,
    );
    paint.shader = null;

    // ── Body highlight ─────────────────────────────────────────────────────
    paint
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        bodyRect.deflate(2),
        const Radius.circular(15),
      ),
      paint,
    );
    paint.style = PaintingStyle.fill;

    // ── Shield (center of body) ────────────────────────────────────────────
    final shieldPath = Path();
    final sc = Offset(cx, size.height * 0.65);
    shieldPath.moveTo(sc.dx, sc.dy - 16);
    shieldPath.lineTo(sc.dx + 12, sc.dy - 8);
    shieldPath.lineTo(sc.dx + 12, sc.dy + 4);
    shieldPath.cubicTo(
      sc.dx + 12, sc.dy + 14,
      sc.dx, sc.dy + 20,
      sc.dx, sc.dy + 20,
    );
    shieldPath.cubicTo(
      sc.dx, sc.dy + 20,
      sc.dx - 12, sc.dy + 14,
      sc.dx - 12, sc.dy + 4,
    );
    shieldPath.lineTo(sc.dx - 12, sc.dy - 8);
    shieldPath.close();

    final shieldGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white.withValues(alpha: 0.9), secondary.withValues(alpha: 0.7)],
    );
    final shieldBounds = Rect.fromCenter(center: sc, width: 30, height: 40);
    paint
      ..shader = shieldGrad.createShader(shieldBounds)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shieldPath, paint);
    paint.shader = null;

    // Orange lock icon inside shield
    paint.color = error.withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(sc.dx, sc.dy + 4), width: 8, height: 6),
        const Radius.circular(2),
      ),
      paint,
    );
    paint
      ..color = error.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(sc.dx, sc.dy + 1), width: 7, height: 7),
      math.pi,
      math.pi,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;

    // ── Head ──────────────────────────────────────────────────────────────
    final headGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        surface.withValues(alpha: 1.0),
        primary.withValues(alpha: 0.3),
      ],
    );
    final headRect = Rect.fromCenter(
      center: Offset(cx, size.height * 0.28),
      width: 54,
      height: 50,
    );
    paint.shader = headGrad.createShader(headRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, const Radius.circular(14)),
      paint,
    );
    paint.shader = null;

    // Head outline
    paint
      ..color = primary.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect, const Radius.circular(14)),
      paint,
    );
    paint.style = PaintingStyle.fill;

    // ── Visor (eyes) ──────────────────────────────────────────────────────
    final visorGrad = LinearGradient(
      colors: [
        primary.withValues(alpha: 0.95),
        secondary.withValues(alpha: 0.8),
      ],
    );
    final visorRect = Rect.fromCenter(
      center: Offset(cx, size.height * 0.27),
      width: 38,
      height: 14,
    );
    paint.shader = visorGrad.createShader(visorRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(visorRect, const Radius.circular(7)),
      paint,
    );
    paint.shader = null;

    // Eye glow
    paint.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(cx - 8, size.height * 0.27), 3, paint);
    canvas.drawCircle(Offset(cx + 8, size.height * 0.27), 3, paint);

    // ── Antenna ───────────────────────────────────────────────────────────
    paint
      ..color = primary.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, size.height * 0.03),
      Offset(cx, size.height * 0.12),
      paint,
    );
    paint
      ..style = PaintingStyle.fill
      ..color = secondary;
    canvas.drawCircle(Offset(cx, size.height * 0.03), 5, paint);
    paint
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(cx, size.height * 0.03), 2.5, paint);

    // ── Neck ──────────────────────────────────────────────────────────────
    paint.color = primary.withValues(alpha: 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, size.height * 0.435),
          width: 18,
          height: 10,
        ),
        const Radius.circular(4),
      ),
      paint,
    );

    // ── Arms ──────────────────────────────────────────────────────────────
    final armPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final leftArmGrad = LinearGradient(
      colors: [primary.withValues(alpha: 0.7), secondary.withValues(alpha: 0.5)],
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    );
    final leftArmRect = Rect.fromCenter(
      center: Offset(cx - 42, size.height * 0.60),
      width: 14,
      height: 52,
    );
    armPaint.shader = leftArmGrad.createShader(leftArmRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftArmRect, const Radius.circular(7)),
      armPaint,
    );

    final rightArmGrad = LinearGradient(
      colors: [primary.withValues(alpha: 0.7), secondary.withValues(alpha: 0.5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final rightArmRect = Rect.fromCenter(
      center: Offset(cx + 42, size.height * 0.60),
      width: 14,
      height: 52,
    );
    armPaint.shader = rightArmGrad.createShader(rightArmRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightArmRect, const Radius.circular(7)),
      armPaint,
    );

    // ── Legs ──────────────────────────────────────────────────────────────
    paint.color = primary.withValues(alpha: 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - 14, size.height * 0.84),
          width: 16,
          height: 26,
        ),
        const Radius.circular(6),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + 14, size.height * 0.84),
          width: 16,
          height: 26,
        ),
        const Radius.circular(6),
      ),
      paint,
    );

    // Feet
    paint.color = secondary.withValues(alpha: 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - 15, size.height * 0.935),
          width: 20,
          height: 9,
        ),
        const Radius.circular(4),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + 15, size.height * 0.935),
          width: 20,
          height: 9,
        ),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GuardBotPainter old) =>
      old.primary != primary || old.secondary != secondary;
}

// ─── Glow action button ───────────────────────────────────────────────────────

class _GlowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  const _GlowButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: onTap != null
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
