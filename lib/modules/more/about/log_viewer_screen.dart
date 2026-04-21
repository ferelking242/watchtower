import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';

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
    for (final raw in content.split('\n')) {
      if (raw.isEmpty) continue;
      if (raw.startsWith('══') || raw.startsWith('  WATCHTOWER')) {
        result.add(_LogLine(raw: raw, type: _LineType.session));
      } else if (raw.contains('][ERROR]')) {
        result.add(_LogLine(raw: raw, type: _LineType.error));
      } else if (raw.contains('][WARN ')) {
        result.add(_LogLine(raw: raw, type: _LineType.warning));
      } else if (raw.contains('][DEBUG]')) {
        result.add(_LogLine(raw: raw, type: _LineType.debug));
      } else if (raw.contains('][INFO ')) {
        result.add(_LogLine(raw: raw, type: _LineType.info));
      } else if (raw.startsWith('  ')) {
        result.add(_LogLine(raw: raw, type: _LineType.continuation));
      } else {
        result.add(_LogLine(raw: raw, type: _LineType.info));
      }
    }
    return result;
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_lines);
      } else {
        _filtered = _lines
            .where((l) => l.raw.toLowerCase().contains(q))
            .toList();
      }
    });
    if (_autoScroll) _scrollToBottom();
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
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final outPath = '${downloadsDir.path}/watchtower_logs_$ts.$ext';
      String content = await src.readAsString();
      if (ext == 'md') {
        content = '# Watchtower logs — $ts\n\n```\n$content\n```\n';
      }
      await File(outPath).writeAsString(content);
      botToast('Enregistré dans Download/${outPath.split('/').last}');
    } catch (e) {
      botToast('Erreur: $e');
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
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
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
            ),
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
                            : 'Aucun résultat pour "${_search.text}"',
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.4),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : _LogList(
                  lines: _filtered,
                  scrollController: _scroll,
                  isDark: isDark,
                  searchQuery: _search.text,
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
}

// ─── Log list ──────────────────────────────────────────────────────────────────

class _LogList extends StatelessWidget {
  final List<_LogLine> lines;
  final ScrollController scrollController;
  final bool isDark;
  final String searchQuery;

  const _LogList({
    required this.lines,
    required this.scrollController,
    required this.isDark,
    required this.searchQuery,
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
  const _LogLine({required this.raw, required this.type});
}
