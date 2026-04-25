import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watchtower/router/router.dart' show navigatorKey;
import 'package:watchtower/utils/log/logger.dart';

/// Floating, draggable overlay that streams [AppLogger]'s formatted log
/// entries on top of every screen. It is intentionally lightweight (no
/// Riverpod, no GoRouter) so it can be shown / hidden from any context —
/// including before the widget tree is fully ready.
///
/// Usage: `LogOverlayController.instance.toggle()`.
///
/// The overlay survives navigation because it is inserted into the root
/// [Overlay] held by the global [navigatorKey]. It does NOT block touches:
/// only the small panel itself captures gestures (for drag + buttons).
class LogOverlayController {
  LogOverlayController._();
  static final LogOverlayController instance = LogOverlayController._();

  OverlayEntry? _entry;
  final ValueNotifier<bool> _visible = ValueNotifier<bool>(false);

  /// Reactive visibility flag — wire a switch to it in your settings.
  ValueListenable<bool> get visibleListenable => _visible;
  bool get isVisible => _visible.value;

  void toggle() => isVisible ? hide() : show();

  void show() {
    if (_entry != null) return;
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) {
      // Try again on the next frame — useful when called very early.
      WidgetsBinding.instance.addPostFrameCallback((_) => show());
      return;
    }
    _entry = OverlayEntry(builder: (_) => const _LogOverlayPanel());
    overlay.insert(_entry!);
    _visible.value = true;
  }

  void hide() {
    _entry?.remove();
    _entry = null;
    _visible.value = false;
  }
}

class _LogOverlayPanel extends StatefulWidget {
  const _LogOverlayPanel();

  @override
  State<_LogOverlayPanel> createState() => _LogOverlayPanelState();
}

class _LogOverlayPanelState extends State<_LogOverlayPanel> {
  // Position is stored in absolute screen coordinates (top-left of the box).
  Offset _pos = const Offset(8, 80);
  Size _size = const Size(340, 240);
  bool _collapsed = false;
  bool _autoScroll = true;
  bool _onlyErrors = false;
  String _filter = '';

  static const int _maxRows = 250;
  final Queue<String> _rows = ListQueue<String>();
  late final StreamSubscription<String> _sub;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _filterCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Seed with whatever is already in the ring buffer so the user sees
    // recent context immediately when they open the overlay.
    for (final entry in AppLogger.recentEntries()) {
      _push(entry, scroll: false);
    }
    _sub = AppLogger.liveStream.listen(_push);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _sub.cancel();
    _scroll.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  void _push(String entry, {bool scroll = true}) {
    if (!mounted) {
      _rows.add(entry);
      if (_rows.length > _maxRows) _rows.removeFirst();
      return;
    }
    setState(() {
      _rows.add(entry);
      if (_rows.length > _maxRows) _rows.removeFirst();
    });
    if (scroll && _autoScroll) _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Iterable<String> get _filtered {
    if (!_onlyErrors && _filter.isEmpty) return _rows;
    final q = _filter.toLowerCase();
    return _rows.where((r) {
      if (_onlyErrors && !r.contains('][ERROR]') && !r.contains('][WARN ')) {
        return false;
      }
      if (q.isNotEmpty && !r.toLowerCase().contains(q)) return false;
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Keep the panel on-screen even after rotation / resize.
    final maxLeft = (mq.size.width - 80).clamp(0.0, mq.size.width);
    final maxTop = (mq.size.height - 80).clamp(0.0, mq.size.height);
    final left = _pos.dx.clamp(0.0, maxLeft);
    final top = _pos.dy.clamp(0.0, maxTop);

    return Positioned(
      left: left,
      top: top,
      child: _collapsed ? _buildHandle() : _buildPanel(),
    );
  }

  Widget _buildHandle() {
    return GestureDetector(
      onPanUpdate: (d) => setState(() => _pos += d.delta),
      onTap: () => setState(() => _collapsed = false),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.terminal_rounded,
                  size: 14, color: Colors.greenAccent),
              SizedBox(width: 6),
              Text('LOGS',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    final rows = _filtered.toList();
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: _size.width,
        height: _size.height,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117).withOpacity(0.92),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.35)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(blurRadius: 10, color: Colors.black54),
            ],
          ),
          child: Column(
            children: [
              _buildTitleBar(rows.length),
              _buildToolbar(),
              const Divider(height: 1, thickness: 1, color: Color(0xFF222C36)),
              Expanded(child: _buildList(rows)),
              _buildResizeHandle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(int visibleCount) {
    return GestureDetector(
      onPanUpdate: (d) => setState(() => _pos += d.delta),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: const Color(0xFF161B22),
        child: Row(
          children: [
            const Icon(Icons.terminal_rounded,
                size: 14, color: Colors.greenAccent),
            const SizedBox(width: 6),
            Text(
              'Live logs · $visibleCount',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.greenAccent,
              ),
            ),
            const Spacer(),
            _IconBtn(
              icon: _autoScroll
                  ? Icons.vertical_align_bottom_rounded
                  : Icons.vertical_align_center_rounded,
              tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
              active: _autoScroll,
              onTap: () => setState(() => _autoScroll = !_autoScroll),
            ),
            _IconBtn(
              icon: Icons.minimize_rounded,
              tooltip: 'Réduire',
              onTap: () => setState(() => _collapsed = true),
            ),
            _IconBtn(
              icon: Icons.close_rounded,
              tooltip: 'Fermer',
              onTap: () => LogOverlayController.instance.hide(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFF0D1117),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _filterCtrl,
              onChanged: (v) => setState(() => _filter = v),
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, color: Colors.white),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                hintText: 'filtrer…',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search,
                    size: 14, color: Colors.white38),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 20, minHeight: 20),
              ),
            ),
          ),
          _IconBtn(
            icon: Icons.error_outline_rounded,
            tooltip: 'Erreurs / warnings uniquement',
            active: _onlyErrors,
            onTap: () => setState(() => _onlyErrors = !_onlyErrors),
          ),
          _IconBtn(
            icon: Icons.copy_rounded,
            tooltip: 'Copier',
            onTap: () async {
              final text = _filtered.join('\n');
              await Clipboard.setData(ClipboardData(text: text));
            },
          ),
          _IconBtn(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Vider',
            onTap: () {
              AppLogger.clearRing();
              setState(_rows.clear);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<String> rows) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'Aucun log pour l\'instant.\nLance une lecture ou un téléchargement.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }
    return Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final raw = rows[i];
          final color = _colorFor(raw);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: SelectableText(
              raw,
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: color),
              maxLines: 6,
            ),
          );
        },
      ),
    );
  }

  Color _colorFor(String raw) {
    if (raw.contains('][ERROR]')) return Colors.redAccent;
    if (raw.contains('][WARN ')) return Colors.orangeAccent;
    if (raw.contains('][DEBUG]')) return Colors.white54;
    if (raw.startsWith('══') || raw.startsWith('  WATCHTOWER')) {
      return Colors.cyanAccent;
    }
    return Colors.greenAccent.shade100;
  }

  Widget _buildResizeHandle() {
    return GestureDetector(
      onPanUpdate: (d) => setState(() {
        final w = (_size.width + d.delta.dx).clamp(220.0, 720.0);
        final h = (_size.height + d.delta.dy).clamp(140.0, 720.0);
        _size = Size(w, h);
      }),
      child: Container(
        height: 12,
        color: const Color(0xFF161B22),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 4),
        child: const Icon(Icons.drag_handle_rounded,
            size: 12, color: Colors.white38),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(
            icon,
            size: 14,
            color: active ? Colors.greenAccent : Colors.white70,
          ),
        ),
      ),
    );
  }
}
