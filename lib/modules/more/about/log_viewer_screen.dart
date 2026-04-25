import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/utils/log/log_overlay.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  String _rawContent = '';
  List<_LogLine> _lines = [];
  List<_LogLine> _filtered = [];
  bool _loading = true;
  bool _autoScroll = true;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  // Active filter sets — empty set means "all levels / all tags".
  final Set<_LineType> _levelFilter = {};
  final Set<String> _tagFilter = {};
  bool _filterBarOpen = true;
  // Collapsed session header indexes (use original line index)
  final Set<int> _collapsedSessions = {};

  static final _tagRegex = RegExp(r'\]\[[^\]]+\] \[([A-Z_]+)\]');

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    _loadLogs();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final storage = StorageProvider();
      final dir = await storage.getDefaultDirectory();
      final file = File(path.join(dir!.path, 'logs.txt'));
      if (await file.exists()) {
        final content = await file.readAsString();
        _rawContent = content;
        _lines = _parse(content);
        _applyFilter();
      } else {
        _lines = [];
        _filtered = [];
      }
    } catch (e) {
      _lines = [];
      _filtered = [];
    }
    setState(() => _loading = false);
    if (_autoScroll) _scrollToBottom();
  }

  List<_LogLine> _parse(String content) {
    final result = <_LogLine>[];
    int sessionId = -1;
    for (final raw in content.split('\n')) {
      if (raw.isEmpty) continue;
      _LineType type;
      if (raw.startsWith('══') || raw.startsWith('  WATCHTOWER')) {
        type = _LineType.session;
        if (raw.startsWith('══')) sessionId = result.length;
      } else if (raw.contains('][ERROR]')) {
        type = _LineType.error;
      } else if (raw.contains('][WARN ')) {
        type = _LineType.warning;
      } else if (raw.contains('][DEBUG]')) {
        type = _LineType.debug;
      } else if (raw.contains('][INFO ')) {
        type = _LineType.info;
      } else if (raw.startsWith('  ')) {
        type = _LineType.continuation;
      } else {
        type = _LineType.info;
      }
      String? tag;
      final m = _tagRegex.firstMatch(raw);
      if (m != null) tag = m.group(1);
      result.add(_LogLine(
        raw: raw,
        type: type,
        tag: tag,
        sessionId: sessionId,
      ));
    }
    return result;
  }

  Set<String> get _availableTags {
    final tags = <String>{};
    for (final l in _lines) {
      if (l.tag != null) tags.add(l.tag!);
    }
    return tags;
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _lines.where((l) {
        if (_collapsedSessions.isNotEmpty &&
            l.type != _LineType.session &&
            _collapsedSessions.contains(l.sessionId)) {
          return false;
        }
        if (_levelFilter.isNotEmpty &&
            l.type != _LineType.session &&
            l.type != _LineType.continuation &&
            !_levelFilter.contains(l.type)) {
          return false;
        }
        if (_tagFilter.isNotEmpty &&
            l.type != _LineType.session &&
            l.type != _LineType.continuation) {
          if (l.tag == null || !_tagFilter.contains(l.tag)) return false;
        }
        if (q.isNotEmpty && !l.raw.toLowerCase().contains(q)) return false;
        return true;
      }).toList();
    });
    if (_autoScroll) _scrollToBottom();
  }

  void _toggleLevel(_LineType t) {
    setState(() {
      if (_levelFilter.contains(t)) {
        _levelFilter.remove(t);
      } else {
        _levelFilter.add(t);
      }
    });
    _applyFilter();
  }

  void _toggleTag(String t) {
    setState(() {
      if (_tagFilter.contains(t)) {
        _tagFilter.remove(t);
      } else {
        _tagFilter.add(t);
      }
    });
    _applyFilter();
  }

  void _toggleSessionCollapse(int sessionId) {
    setState(() {
      if (_collapsedSessions.contains(sessionId)) {
        _collapsedSessions.remove(sessionId);
      } else {
        _collapsedSessions.add(sessionId);
      }
    });
    _applyFilter();
  }

  void _clearFilters() {
    setState(() {
      _levelFilter.clear();
      _tagFilter.clear();
      _collapsedSessions.clear();
      _search.clear();
    });
    _applyFilter();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _downloadAs(String ext) async {
    try {
      final storage = StorageProvider();
      final dir = await storage.getDefaultDirectory();
      final src = File(path.join(dir!.path, 'logs.txt'));
      if (!await src.exists()) {
        botToast('Aucun fichier log trouvé');
        return;
      }
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'watchtower_logs_$ts.$ext';
      String content = await src.readAsString();
      if (ext == 'md') {
        content = '# Watchtower logs — $ts\n\n```\n$content\n```\n';
      }

      Directory? target;
      if (Platform.isAndroid) {
        final candidate = Directory('/storage/emulated/0/Download');
        try {
          if (!await candidate.exists()) {
            await candidate.create(recursive: true);
          }
          final probe = File('${candidate.path}/.wt_probe');
          await probe.writeAsString('ok');
          await probe.delete();
          target = candidate;
        } catch (_) {
          target = await getExternalStorageDirectory();
        }
      } else {
        target = await getApplicationDocumentsDirectory();
      }
      target ??= await getApplicationDocumentsDirectory();

      final outFile = File(path.join(target.path, fileName));
      await outFile.writeAsString(content);

      botToast('Enregistré : ${outFile.path}');

      if (!Platform.isAndroid ||
          !outFile.path.startsWith('/storage/emulated/0/Download')) {
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(outFile.path)],
            text: fileName,
            sharePositionOrigin:
                box != null ? box.localToGlobal(Offset.zero) & box.size : null,
          ),
        );
      }
    } catch (e) {
      botToast('Erreur téléchargement : $e');
    }
  }

  Future<void> _share() async {
    final storage = StorageProvider();
    final dir = await storage.getDefaultDirectory();
    final file = File(path.join(dir!.path, 'logs.txt'));
    if (await file.exists() && context.mounted) {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'logs.txt',
          sharePositionOrigin:
              box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        ),
      );
    } else {
      botToast('Aucun fichier log trouvé');
    }
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _rawContent));
    botToast('Logs copiés dans le presse-papiers');
  }

  int get _errorCount => _lines.where((l) => l.type == _LineType.error).length;
  int get _warnCount => _lines.where((l) => l.type == _LineType.warning).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA);
    final surfaceColor =
        isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.terminal_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Logs',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            if (_errorCount > 0)
              _Badge(label: '${_errorCount}E', color: Colors.red),
            if (_warnCount > 0) ...[
              const SizedBox(width: 4),
              _Badge(label: '${_warnCount}W', color: Colors.orange),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copier tout',
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: _loading ? null : _copyAll,
          ),
          ArrowPopupMenuButton<String>(
            tooltip: 'Télécharger / Partager',
            icon: const Icon(Icons.download_rounded, size: 20),
            onSelected: (v) {
              switch (v) {
                case 'txt':
                  _downloadAs('txt');
                  break;
                case 'md':
                  _downloadAs('md');
                  break;
                case 'share':
                  _share();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'txt',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.text_snippet_outlined, size: 18),
                  title: Text('Télécharger .txt'),
                ),
              ),
              PopupMenuItem(
                value: 'md',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.description_outlined, size: 18),
                  title: Text('Télécharger .md'),
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.share_outlined, size: 18),
                  title: Text('Partager'),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadLogs,
          ),
          // ── Floating live-log overlay toggle ───────────────────────────────
          // Shows a draggable, always-on-top panel that streams every log line
          // in real time on top of any screen — useful for diagnosing UI bugs
          // without leaving the screen where the bug occurs.
          ValueListenableBuilder<bool>(
            valueListenable:
                LogOverlayController.instance.visibleListenable,
            builder: (_, visible, __) => IconButton(
              tooltip: visible
                  ? 'Cacher l\'overlay temps réel'
                  : 'Afficher l\'overlay temps réel',
              icon: Icon(
                visible
                    ? Icons.picture_in_picture_alt_rounded
                    : Icons.picture_in_picture_outlined,
                size: 20,
                color: visible ? Colors.greenAccent : null,
              ),
              onPressed: () => LogOverlayController.instance.toggle(),
            ),
          ),
          IconButton(
            tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
            icon: Icon(
              _autoScroll
                  ? Icons.vertical_align_bottom_rounded
                  : Icons.vertical_align_center_rounded,
              size: 20,
              color: _autoScroll ? cs.primary : null,
            ),
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize:
              Size.fromHeight(_filterBarOpen ? 132.0 : 56.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_filterBarOpen) _buildFilterBar(cs, bgColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: _filterBarOpen
                          ? 'Cacher filtres'
                          : 'Afficher filtres',
                      icon: Icon(
                        _filterBarOpen
                            ? Icons.filter_alt_rounded
                            : Icons.filter_alt_outlined,
                        size: 20,
                        color: (_levelFilter.isNotEmpty ||
                                _tagFilter.isNotEmpty)
                            ? cs.primary
                            : null,
                      ),
                      onPressed: () => setState(
                          () => _filterBarOpen = !_filterBarOpen),
                    ),
                    Expanded(child: _buildSearchField(cs, bgColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: cs.onSurface.withOpacity(0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _lines.isEmpty
                            ? 'Aucun log enregistré'
                            : 'Aucun résultat',
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.4),
                          fontSize: 14,
                        ),
                      ),
                      if (_levelFilter.isNotEmpty ||
                          _tagFilter.isNotEmpty ||
                          _search.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear_all_rounded, size: 16),
                          label: const Text('Effacer les filtres'),
                        ),
                      ],
                    ],
                  ),
                )
              : _LogList(
                  lines: _filtered,
                  scrollController: _scroll,
                  isDark: isDark,
                  searchQuery: _search.text,
                  collapsedSessions: _collapsedSessions,
                  onToggleSession: _toggleSessionCollapse,
                ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.small(
              tooltip: 'Aller en bas',
              onPressed: _scrollToBottom,
              child: const Icon(Icons.keyboard_double_arrow_down_rounded),
            ),
      bottomNavigationBar: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Text(
              '${_filtered.length} ligne${_filtered.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withOpacity(0.5),
                fontFamily: 'monospace',
              ),
            ),
            if (_search.text.isNotEmpty) ...[
              Text(
                ' · filtre: "${_search.text}"',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.primary.withOpacity(0.7),
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const Spacer(),
            if (_errorCount > 0)
              Text(
                '$_errorCount erreur${_errorCount != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                  fontFamily: 'monospace',
                ),
              ),
            if (_errorCount > 0 && _warnCount > 0)
              const Text(
                ' · ',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            if (_warnCount > 0)
              Text(
                '$_warnCount warning${_warnCount != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontFamily: 'monospace',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme cs, Color bgColor) {
    final tags = _availableTags.toList()..sort();
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                _LevelChip(
                    type: _LineType.error,
                    label: 'Errors',
                    color: Colors.red,
                    selected: _levelFilter.contains(_LineType.error),
                    onTap: () => _toggleLevel(_LineType.error)),
                _LevelChip(
                    type: _LineType.warning,
                    label: 'Warn',
                    color: Colors.orange,
                    selected: _levelFilter.contains(_LineType.warning),
                    onTap: () => _toggleLevel(_LineType.warning)),
                _LevelChip(
                    type: _LineType.info,
                    label: 'Info',
                    color: Colors.green,
                    selected: _levelFilter.contains(_LineType.info),
                    onTap: () => _toggleLevel(_LineType.info)),
                _LevelChip(
                    type: _LineType.debug,
                    label: 'Debug',
                    color: Colors.grey,
                    selected: _levelFilter.contains(_LineType.debug),
                    onTap: () => _toggleLevel(_LineType.debug)),
                if (_levelFilter.isNotEmpty ||
                    _tagFilter.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      labelPadding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      label: const Text('Reset',
                          style: TextStyle(fontSize: 10)),
                      avatar: const Icon(Icons.clear_rounded, size: 12),
                      onPressed: _clearFilters,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: tags.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'Aucun tag détecté dans les logs',
                      style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurface.withOpacity(0.4)),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: tags.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (_, i) {
                      final t = tags[i];
                      final selected = _tagFilter.contains(t);
                      return FilterChip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4),
                        label: Text(t,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace')),
                        selected: selected,
                        onSelected: (_) => _toggleTag(t),
                        selectedColor: cs.primary.withValues(alpha: 0.25),
                        showCheckmark: false,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ColorScheme cs, Color bgColor) {
    return TextField(
              controller: _search,
              style: GoogleFonts.jetBrainsMono(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Filtrer les logs…',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.4),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () {
                          _search.clear();
                          _applyFilter();
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: cs.outline.withOpacity(0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: cs.outline.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            );
  }

}

// ─── Log list ──────────────────────────────────────────────────────────────────

class _LogList extends StatelessWidget {
  final List<_LogLine> lines;
  final ScrollController scrollController;
  final bool isDark;
  final String searchQuery;
  final Set<int> collapsedSessions;
  final void Function(int sessionId) onToggleSession;

  const _LogList({
    required this.lines,
    required this.scrollController,
    required this.isDark,
    required this.searchQuery,
    required this.collapsedSessions,
    required this.onToggleSession,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: lines.length,
        itemBuilder: (context, i) {
          final line = lines[i];
          if (line.type == _LineType.session && line.raw.startsWith('══')) {
            final collapsed = collapsedSessions.contains(line.sessionId);
            return InkWell(
              onTap: () => onToggleSession(line.sessionId),
              child: Row(
                children: [
                  Icon(
                    collapsed
                        ? Icons.chevron_right_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: Colors.blue.shade400,
                  ),
                  Expanded(
                    child: _LogLineWidget(
                      line: line,
                      isDark: isDark,
                      searchQuery: searchQuery,
                    ),
                  ),
                ],
              ),
            );
          }
          return _LogLineWidget(
            line: line,
            isDark: isDark,
            searchQuery: searchQuery,
          );
        },
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final _LineType type;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _LevelChip({
    required this.type,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        avatar: Icon(
          type == _LineType.error
              ? Icons.error_outline_rounded
              : type == _LineType.warning
                  ? Icons.warning_amber_rounded
                  : type == _LineType.info
                      ? Icons.info_outline_rounded
                      : Icons.bug_report_outlined,
          size: 13,
          color: color,
        ),
        label: Text(label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: selected ? color : null,
            )),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color.withValues(alpha: 0.18),
        side: BorderSide(
          color: selected
              ? color.withValues(alpha: 0.7)
              : Colors.transparent,
        ),
        showCheckmark: false,
      ),
    );
  }
}

class _LogLineWidget extends StatelessWidget {
  final _LogLine line;
  final bool isDark;
  final String searchQuery;

  const _LogLineWidget({
    required this.line,
    required this.isDark,
    required this.searchQuery,
  });

  Color _bgColor() {
    switch (line.type) {
      case _LineType.session:
        return isDark
            ? Colors.blue.withOpacity(0.12)
            : Colors.blue.withOpacity(0.06);
      case _LineType.error:
        return isDark
            ? Colors.red.withOpacity(0.1)
            : Colors.red.withOpacity(0.04);
      case _LineType.warning:
        return isDark
            ? Colors.orange.withOpacity(0.08)
            : Colors.orange.withOpacity(0.04);
      default:
        return Colors.transparent;
    }
  }

  Color _textColor() {
    switch (line.type) {
      case _LineType.session:
        return isDark ? Colors.blue.shade300 : Colors.blue.shade700;
      case _LineType.error:
        return isDark ? Colors.red.shade300 : Colors.red.shade700;
      case _LineType.warning:
        return isDark ? Colors.orange.shade300 : Colors.orange.shade700;
      case _LineType.debug:
        return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
      case _LineType.continuation:
        return isDark
            ? Colors.white.withOpacity(0.5)
            : Colors.black.withOpacity(0.45);
      default:
        return isDark ? Colors.green.shade300 : Colors.green.shade800;
    }
  }

  static final _urlRegex = RegExp(
    r'(https?:\/\/[^\s<>"\)\]]+)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final text = line.raw;
    final color = _textColor();

    Widget child;
    if (searchQuery.isNotEmpty) {
      child = _HighlightedText(
        text: text,
        query: searchQuery,
        baseColor: color,
      );
    } else if (_urlRegex.hasMatch(text)) {
      final spans = <InlineSpan>[];
      int last = 0;
      for (final m in _urlRegex.allMatches(text)) {
        if (m.start > last) {
          spans.add(TextSpan(text: text.substring(last, m.start)));
        }
        final url = text.substring(m.start, m.end);
        spans.add(TextSpan(
          text: url,
          style: TextStyle(
            color: Colors.blue.shade400,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openUrl(context, url),
        ));
        last = m.end;
      }
      if (last < text.length) {
        spans.add(TextSpan(text: text.substring(last)));
      }
      child = Text.rich(
        TextSpan(children: spans),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          color: color,
          height: 1.5,
        ),
      );
    } else {
      child = Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          color: color,
          height: 1.5,
        ),
      );
    }

    return Container(
      color: _bgColor(),
      margin: line.type == _LineType.session
          ? const EdgeInsets.symmetric(vertical: 2)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: child,
    );
  }

  void _openUrl(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _LogUrlWebView(url: url)),
    );
  }
}

class _LogUrlWebView extends StatelessWidget {
  final String url;
  const _LogUrlWebView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          IconButton(
            tooltip: 'Ouvrir dans le navigateur',
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            onPressed: () => launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final Color baseColor;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    int idx;
    while ((idx = lower.indexOf(lowerQ, start)) != -1) {
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: const TextStyle(
          backgroundColor: Colors.yellow,
          color: Colors.black,
        ),
      ));
      start = idx + query.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        color: baseColor,
        height: 1.5,
      ),
    );
  }
}

// ─── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Models ────────────────────────────────────────────────────────────────────

enum _LineType { session, error, warning, info, debug, continuation }

class _LogLine {
  final String raw;
  final _LineType type;
  final String? tag;
  final int sessionId;
  const _LogLine({
    required this.raw,
    required this.type,
    this.tag,
    this.sessionId = -1,
  });
}
