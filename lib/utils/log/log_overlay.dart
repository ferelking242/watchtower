import 'dart:async';
import 'dart:collection';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _showDate = true;
  // When collapsed, dock the small handle on the right edge by default —
  // the user explicitly asked for it ("collé à droite quand replié").
  bool _dockedRight = true;
  String _filter = '';
  // Folded log groups — when a tag has been seen consecutively N times in a
  // row we collapse them into a single foldable header (`+N` siblings).
  final Set<int> _expandedGroups = <int>{};

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

  /// Strip the `[YYYY-MM-DD HH:MM:SS.mmm]` timestamp prefix when the user
  /// has the date toggle off (keeps the display compact on a phone screen).
  String _displayLine(String raw) {
    if (_showDate) return raw;
    // Timestamps look like `[2026-04-21 13:42:43.142][INFO ] ...`
    final m = RegExp(r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\]')
        .firstMatch(raw);
    if (m == null) return raw;
    return raw.substring(m.end);
  }

  /// Extract a stable group key for "tree folding" — uses the `[TAG]` token
  /// when present so consecutive entries from the same subsystem (EXT,
  /// HLS, DL, …) collapse into a single foldable parent.
  String _groupKey(String raw) {
    // Skip the timestamp + level prefix to find the optional `[TAG]` token.
    // Format: `[TS][LEVEL] [TAG] message…` — the first two `[..]` brackets
    // are TS and LEVEL, the optional 3rd one is the tag.
    final tag = RegExp(r'^\[[^\]]+\]\[[^\]]+\]\s+\[([A-Z_]+)\]')
        .firstMatch(raw);
    if (tag != null) return tag.group(1)!;
    // Fall back to the level so at least ERROR vs INFO groups separately.
    final lvl = RegExp(r'^\[[^\]]+\]\[([A-Z ]+)\]').firstMatch(raw);
    return lvl?.group(1)?.trim() ?? '_';
  }

  /// Build "tree-folded" rows: consecutive entries sharing the same group
  /// key are collapsed into one foldable parent showing the first line
  /// plus a `+N` badge (the user can tap to expand the group).
  List<_LogRow> _buildTree(List<String> rows) {
    final out = <_LogRow>[];
    int i = 0;
    int groupId = 0;
    while (i < rows.length) {
      final key = _groupKey(rows[i]);
      int j = i + 1;
      while (j < rows.length && _groupKey(rows[j]) == key) {
        j++;
      }
      final children = j - i - 1;
      // Single line → not foldable, render as a leaf.
      if (children == 0) {
        out.add(_LogRow(text: rows[i], depth: 0, isParent: false, groupId: -1));
      } else {
        final id = groupId++;
        final expanded = _expandedGroups.contains(id);
        out.add(_LogRow(
          text: rows[i],
          depth: 0,
          isParent: true,
          siblings: children,
          groupId: id,
          expanded: expanded,
          tag: key,
        ));
        if (expanded) {
          for (var k = i + 1; k < j; k++) {
            out.add(_LogRow(
              text: rows[k],
              depth: 1,
              isParent: false,
              groupId: id,
            ));
          }
        }
      }
      i = j;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (_collapsed) {
      // Docked handle: pinned to the right edge by default; user can drag
      // it elsewhere and it sticks.
      final handleSize = const Size(64, 28);
      double left;
      double top = _pos.dy.clamp(0.0, (mq.size.height - handleSize.height));
      if (_dockedRight) {
        left = mq.size.width - handleSize.width - 6;
      } else {
        left = _pos.dx.clamp(0.0, (mq.size.width - handleSize.width));
      }
      return Positioned(
        left: left,
        top: top,
        child: _buildHandle(),
      );
    }
    final maxLeft = (mq.size.width - 80).clamp(0.0, mq.size.width);
    final maxTop = (mq.size.height - 80).clamp(0.0, mq.size.height);
    final left = _pos.dx.clamp(0.0, maxLeft);
    final top = _pos.dy.clamp(0.0, maxTop);
    return Positioned(
      left: left,
      top: top,
      child: _buildPanel(),
    );
  }

  Widget _buildHandle() {
    return GestureDetector(
      onPanUpdate: (d) => setState(() {
        // As soon as the user drags the handle horizontally past a small
        // threshold, undock it from the right edge so it follows the finger.
        if (_dockedRight && d.delta.dx.abs() > 1) {
          final mq = MediaQuery.of(context);
          _pos = Offset(mq.size.width - 70, _pos.dy);
          _dockedRight = false;
        }
        _pos += d.delta;
      }),
      onPanEnd: (_) {
        // Snap back to the right edge if released near it.
        final mq = MediaQuery.of(context);
        if (_pos.dx > mq.size.width - 90) {
          setState(() => _dockedRight = true);
        }
      },
      onTap: () => setState(() => _collapsed = false),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.78),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
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
    final flat = _filtered.toList();
    final tree = _buildTree(flat);
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: _size.width,
        height: _size.height,
        child: Stack(
          children: [
            Container(
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
                  _buildTitleBar(flat.length),
                  _buildToolbar(),
                  const Divider(
                      height: 1, thickness: 1, color: Color(0xFF222C36)),
                  Expanded(child: _buildList(tree)),
                  _buildBottomBar(),
                ],
              ),
            ),
            // Bottom-right corner resize grip — pulls in BOTH dimensions so
            // the user can shape the panel however they want.
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => setState(() {
                  final w = (_size.width + d.delta.dx).clamp(220.0, 720.0);
                  final h = (_size.height + d.delta.dy).clamp(140.0, 720.0);
                  _size = Size(w, h);
                }),
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.only(right: 2, bottom: 2),
                  child: const Icon(
                    Icons.south_east_rounded,
                    size: 14,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
            // Right-edge resize grip — width only.
            Positioned(
              right: 0,
              top: 30,
              bottom: 18,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => setState(() {
                  final w = (_size.width + d.delta.dx).clamp(220.0, 720.0);
                  _size = Size(w, _size.height);
                }),
                child: const SizedBox(width: 6),
              ),
            ),
          ],
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
              icon: _showDate
                  ? Icons.calendar_month_rounded
                  : Icons.calendar_today_outlined,
              tooltip: _showDate ? 'Date · ON' : 'Date · OFF',
              active: _showDate,
              onTap: () => setState(() => _showDate = !_showDate),
            ),
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
              final text = _filtered.map(_displayLine).join('\n');
              await Clipboard.setData(ClipboardData(text: text));
            },
          ),
          // Download / share the current session's log file. Falls back to
          // sharing the in-memory buffer as a temp file when the on-disk
          // session log isn't available (logs disabled in settings, or the
          // logger never finished init()).
          _IconBtn(
            icon: Icons.download_rounded,
            tooltip: 'Télécharger / Partager',
            onTap: _downloadLog,
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

  Future<void> _downloadLog() async {
    try {
      final sessionPath = AppLogger.currentSessionPath;
      File toShare;
      if (sessionPath != null && await File(sessionPath).exists()) {
        toShare = File(sessionPath);
      } else {
        // Build a temp file from whatever is currently in the overlay so
        // the user always gets *something* downloadable.
        final tmpDir = Directory.systemTemp;
        final stamp = DateTime.now().millisecondsSinceEpoch;
        toShare = File(
            '${tmpDir.path}${Platform.pathSeparator}watchtower_logs_$stamp.log');
        await toShare.writeAsString(_filtered.join('\n'));
      }
      await Share.shareXFiles(
        [XFile(toShare.path)],
        subject: 'Watchtower logs',
        text: 'Logs Watchtower',
      );
    } catch (_) {
      // Last-ditch fallback: copy to clipboard so the user still has
      // something to paste into a bug report.
      try {
        await Clipboard.setData(
          ClipboardData(text: _filtered.map(_displayLine).join('\n')),
        );
      } catch (_) {}
    }
  }

  Widget _buildList(List<_LogRow> rows) {
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
        padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final row = rows[i];
          final color = _colorFor(row.text);
          final display = _displayLine(row.text);

          if (row.isParent) {
            return InkWell(
              onTap: () {
                setState(() {
                  if (row.expanded) {
                    _expandedGroups.remove(row.groupId);
                  } else {
                    _expandedGroups.add(row.groupId);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 2),
                      child: Icon(
                        row.expanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.chevron_right_rounded,
                        size: 14,
                        color: Colors.cyanAccent,
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        display,
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 10, color: color),
                        maxLines: 6,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.cyanAccent.withOpacity(0.4),
                            width: 0.5),
                      ),
                      child: Text(
                        '+${row.siblings}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                4 + (row.depth * 16.0), 1, 4, 1),
            child: SelectableText(
              display,
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

  Widget _buildBottomBar() {
    return Container(
      height: 14,
      color: const Color(0xFF161B22),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        AppLogger.currentSessionPath != null
            ? 'session active'
            : 'tampon mémoire',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 8,
          color: Colors.white30,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// One displayable row in the (optionally folded) log tree.
class _LogRow {
  final String text;
  final int depth;
  final bool isParent;
  final int siblings;
  final int groupId;
  final bool expanded;
  final String tag;
  const _LogRow({
    required this.text,
    required this.depth,
    required this.isParent,
    required this.groupId,
    this.siblings = 0,
    this.expanded = false,
    this.tag = '',
  });
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
