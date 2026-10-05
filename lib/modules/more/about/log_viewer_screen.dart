import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart' show isar;
import 'package:watchtower/models/source.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/utils/adaptive_overlay_menu.dart';
import 'package:watchtower/utils/arrow_popup_menu.dart';
import 'package:watchtower/utils/log/log_overlay.dart';
import 'package:watchtower/utils/log/logger.dart';

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
  int _logMode = LogMode.normal.index;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  // Active filter sets — empty set means "all levels / all tags".
  final Set<_LineType> _levelFilter = {};
  final Set<String> _tagFilter = {};
  final Set<_LogCategory> _categoryFilter = {};
  // Collapsed session header indexes (use original line index)
  final Set<int> _collapsedSessions = {};
  final List<Source> _extensionSources = [];

  static final _tagRegex = RegExp(r'\]\[[^\]]+\] \[([A-Z_]+)\]');

  @override
  void initState() {
    super.initState();
    _search.addListener(_applyFilter);
    _loadLogMode();
    _loadExtensionSources();
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

      // 1. Prefer per-session files written by AppLogger (logs_sessions/).
      if (dir != null) {
        final sessionsDir =
            Directory(path.join(dir.path, 'log'));
        if (await sessionsDir.exists()) {
          final files = await sessionsDir
              .list()
              .where((e) => e is File && e.path.endsWith('.log'))
              .cast<File>()
              .toList();
          if (files.isNotEmpty) {
            files.sort((a, b) => b.path.compareTo(a.path));
            final content = await files.first.readAsString();
            _rawContent = content;
            _parseAndCollapseSessions(content);
            _applyFilter();
            setState(() => _loading = false);
            if (_autoScroll) _scrollToBottom();
            return;
          }
        }

        // 2. Legacy fallback: old flat logs.txt file.
        final legacy = File(path.join(dir.path, 'logs.txt'));
        if (await legacy.exists()) {
          final content = await legacy.readAsString();
          _rawContent = content;
          _parseAndCollapseSessions(content);
          _applyFilter();
          setState(() => _loading = false);
          if (_autoScroll) _scrollToBottom();
          return;
        }
      }

      // 3. No file at all — use the in-memory ring buffer (works even when
      //    file logging is disabled; always populated by AppLogger.log()).
      final recent = AppLogger.recentEntries();
      if (recent.isNotEmpty) {
        final content = recent.join('\n');
        _rawContent = content;
        _parseAndCollapseSessions(content);
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
      } else if (_failureRegex.hasMatch(raw)) {
        type = _LineType.error;
      } else if (raw.contains('][INFO ')) {
        type = _isSuccessMessage(raw) ? _LineType.success : _LineType.info;
      } else if (raw.startsWith('  ')) {
        type = _LineType.continuation;
      } else if (_isSuccessMessage(raw)) {
        type = _LineType.success;
      } else {
        type = _LineType.info;
      }
      String? tag;
      final m = _tagRegex.firstMatch(raw);
      if (m != null) tag = m.group(1);
      final source = tag == 'EXT' ? _sourceForLogLine(raw) : null;
      result.add(_LogLine(
        raw: raw,
        type: type,
        tag: tag,
        sessionId: sessionId,
        extensionName: source?.name,
        extensionIconUrl: source?.iconUrl,
        extensionSourceId: source?.id,
      ));
    }
    return result;
  }

  static final _successRegex = RegExp(
    r'\b(success(?:ful(?:ly)?)?|succeeded|complete(?:d)?|finished|installed|connected|loaded|saved|ready)\b',
    caseSensitive: false,
  );
  static final _failureRegex = RegExp(
    r'\b(error|exception|failed|failure|unable to)\b',
    caseSensitive: false,
  );

  bool _isSuccessMessage(String raw) => _successRegex.hasMatch(raw);

  void _parseAndCollapseSessions(String content) {
    _lines = _parse(content);
    _collapsedSessions
      ..clear()
      ..addAll(
        _lines
            .where(
              (line) =>
                  line.type == _LineType.session && line.raw.startsWith('══'),
            )
            .map((line) => line.sessionId),
      );
  }

  void _loadExtensionSources() {
    try {
      _extensionSources
        ..clear()
        ..addAll(
          isar.sources
              .where()
              .findAllSync()
              .where((source) => (source.name ?? '').trim().isNotEmpty)
              .toList()
            ..sort(
              (a, b) => (b.name ?? '').length.compareTo((a.name ?? '').length),
            ),
        );
    } catch (_) {
      // The in-memory log viewer can still be opened before the database loads.
    }
  }

  Source? _sourceForLogLine(String raw) {
    final normalized = raw.toLowerCase();
    for (final source in _extensionSources) {
      final name = source.name?.trim();
      if (name != null && name.isNotEmpty && normalized.contains(name.toLowerCase())) {
        return source;
      }
    }
    return null;
  }

  Future<void> _loadLogMode() async {
    try {
      final box = await Hive.openBox('advanced_settings');
      final value = box.get(kLogMode, defaultValue: LogMode.normal.index);
      final modeIndex = value is int ? value : LogMode.normal.index;
      if (mounted) {
        setState(
          () => _logMode =
              modeIndex.clamp(0, LogMode.values.length - 1).toInt(),
        );
      }
    } catch (_) {}
  }

  Future<void> _setLogMode(LogMode mode) async {
    final box = await Hive.openBox('advanced_settings');
    await box.put(kLogMode, mode.index);
    await box.put(kLogMinLevel, mode.minLevel);
    for (final entry in mode.defaultTags.entries) {
      await box.put(entry.key, entry.value);
    }
    await AppLogger.reloadSettings();
    if (!mounted) return;
    setState(() => _logMode = mode.index);
    if (mode.isHeavy) {
      botToast(
        mode == LogMode.extreme
            ? '⚡ Extreme – tout est logué. RAM +++. À utiliser avec précaution.'
            : '⚠ Mode Debug actif – consommation RAM élevée',
        second: 5,
      );
    }
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
        if (_categoryFilter.isNotEmpty &&
            l.type != _LineType.session &&
            l.type != _LineType.continuation &&
            !_categoryFilter.any((category) => category.matches(l))) {
          return false;
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

  void _toggleCategory(_LogCategory category) {
    setState(() {
      if (!_categoryFilter.add(category)) _categoryFilter.remove(category);
    });
    _applyFilter();
  }

  void _clearCategoryFilters() {
    setState(_categoryFilter.clear);
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
      _categoryFilter.clear();
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
      if (!kIsWeb && Platform.isAndroid) {
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

      if (kIsWeb || !Platform.isAndroid ||
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
  int get _successCount => _lines.where((l) => l.type == _LineType.success).length;

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
            Icon(Broken.code_1, size: 18, color: cs.primary),
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
            if (_successCount > 0) ...[
              const SizedBox(width: 4),
              _Badge(label: '${_successCount}✓', color: Colors.green),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Copier tout',
            icon: const Icon(Broken.copy, size: 20),
            onPressed: _loading ? null : _copyAll,
          ),
          ArrowPopupMenuButton<String>(
            tooltip: 'Télécharger / Partager',
            icon: const Icon(Broken.document_download, size: 20),
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
                  leading: Icon(Broken.document_text, size: 18),
                  title: Text('Télécharger .txt'),
                ),
              ),
              PopupMenuItem(
                value: 'md',
                child: ListTile(
                  dense: true,
                  leading: Icon(Broken.document_1, size: 18),
                  title: Text('Télécharger .md'),
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  dense: true,
                  leading: Icon(Broken.share, size: 18),
                  title: Text('Partager'),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Broken.refresh, size: 20),
            onPressed: _loadLogs,
          ),
          PopupMenuButton<String>(
            tooltip: 'Options',
            icon: const Icon(Broken.more_2, size: 20),
            onSelected: (v) {
              if (v == 'refresh') _loadLogs();
              if (v == 'overlay') LogOverlayController.instance.toggle();
              if (v == 'scroll') setState(() => _autoScroll = !_autoScroll);
              if (v == 'clear') setState(() {
                AppLogger.clearRing();
                _rawContent = '';
                _lines = [];
                _filtered = [];
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'refresh', child: ListTile(dense: true, leading: Icon(Broken.refresh, size: 18), title: Text('Rafraîchir'))),
              PopupMenuItem(
                value: 'overlay',
                child: ValueListenableBuilder<bool>(
                  valueListenable: LogOverlayController.instance.visibleListenable,
                  builder: (_, v, __) => ListTile(dense: true, leading: Icon(v ? Broken.monitor : Broken.video_slash, size: 18, color: v ? Colors.greenAccent : null), title: Text(v ? 'Cacher overlay' : 'Overlay live')),
                ),
              ),
              PopupMenuItem(
                value: 'scroll',
                child: ListTile(dense: true, leading: Icon(_autoScroll ? Broken.arrow_down : Broken.arrow_up, size: 18, color: _autoScroll ? cs.primary : null), title: Text(_autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF')),
              ),
              const PopupMenuItem(value: 'clear', child: ListTile(dense: true, leading: Icon(Broken.trash, size: 18, color: Colors.red), title: Text('Vider les logs'))),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Column(
              children: [
                _buildModeSelector(cs),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AdaptiveOverlayMenuButton(
                      menuWidth: (MediaQuery.sizeOf(context).width - 20)
                          .clamp(160.0, 290.0)
                          .toDouble(),
                      trigger: Tooltip(
                        message: 'Filtres',
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            _levelFilter.isNotEmpty ||
                                    _tagFilter.isNotEmpty ||
                                    _categoryFilter.isNotEmpty
                                ? Broken.filter_tick
                                : Broken.filter,
                            size: 20,
                            color: _levelFilter.isNotEmpty ||
                                    _tagFilter.isNotEmpty ||
                                    _categoryFilter.isNotEmpty
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                      contentBuilder: (_) => _LogFiltersMenu(
                        levels: _levelFilter,
                        categories: _categoryFilter,
                        tags: _tagFilter,
                        availableTags: _availableTags.toList()..sort(),
                        onToggleLevel: _toggleLevel,
                        onToggleCategory: _toggleCategory,
                        onToggleTag: _toggleTag,
                        onClearCategories: _clearCategoryFilters,
                        onClear: _clearFilters,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: _buildSearchField(cs, bgColor)),
                  ],
                ),
              ],
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
                        Broken.document_1,
                        size: 48,
                        color: cs.onSurface.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _lines.isEmpty
                            ? 'Aucun log enregistré'
                            : 'Aucun résultat',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                      ),
                      if (_levelFilter.isNotEmpty ||
                          _tagFilter.isNotEmpty ||
                          _categoryFilter.isNotEmpty ||
                          _search.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Broken.refresh_left_square, size: 16),
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
              child: const Icon(Broken.arrow_down),
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
                color: cs.onSurface.withValues(alpha: 0.5),
                fontFamily: 'monospace',
              ),
            ),
            if (_search.text.isNotEmpty) ...[
              Text(
                ' · filtre: "${_search.text}"',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.primary.withValues(alpha: 0.7),
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

  Widget _buildModeSelector(ColorScheme cs) {
    const colors = {
      LogMode.normal: Colors.green,
      LogMode.verbose: Colors.blue,
      LogMode.debug: Colors.orange,
      LogMode.extreme: Colors.red,
    };
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 0, 10, 0),
            child: Center(
              child: Icon(Broken.setting_2, size: 16),
            ),
          ),
          for (final mode in LogMode.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(mode.displayName),
                selected: _logMode == mode.index,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selectedColor: colors[mode]!,
                backgroundColor: colors[mode]!.withValues(alpha: 0.1),
                side: BorderSide(
                  color: _logMode == mode.index
                      ? colors[mode]!
                      : colors[mode]!.withValues(alpha: 0.4),
                ),
                labelStyle: TextStyle(
                  color: _logMode == mode.index
                      ? Colors.white
                      : cs.onSurface.withValues(alpha: 0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (selected) {
                  if (selected) _setLogMode(mode);
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
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
                prefixIcon: const Icon(Broken.search_normal, size: 18),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Broken.close_circle, size: 16),
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
                    color: cs.outline.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: cs.outline.withValues(alpha: 0.2),
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

class _LogFiltersMenu extends StatefulWidget {
  final Set<_LineType> levels;
  final Set<_LogCategory> categories;
  final Set<String> tags;
  final List<String> availableTags;
  final ValueChanged<_LineType> onToggleLevel;
  final ValueChanged<_LogCategory> onToggleCategory;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onClearCategories;
  final VoidCallback onClear;

  const _LogFiltersMenu({
    required this.levels,
    required this.categories,
    required this.tags,
    required this.availableTags,
    required this.onToggleLevel,
    required this.onToggleCategory,
    required this.onToggleTag,
    required this.onClearCategories,
    required this.onClear,
  });

  @override
  State<_LogFiltersMenu> createState() => _LogFiltersMenuState();
}

class _LogFiltersMenuState extends State<_LogFiltersMenu> {
  void _toggleLevel(_LineType type) {
    widget.onToggleLevel(type);
    setState(() {});
  }

  void _toggleCategory(_LogCategory category) {
    widget.onToggleCategory(category);
    setState(() {});
  }

  void _toggleTag(String tag) {
    widget.onToggleTag(tag);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdaptiveOverlaySection(title: 'Type de contenu'),
        AdaptiveOverlayItem(
          icon: Broken.global,
          label: 'Tout afficher',
          selected: widget.categories.isEmpty,
          onTap: () {
            widget.onClearCategories();
            setState(() {});
          },
        ),
        for (final category in _LogCategory.values)
          AdaptiveOverlayItem(
            icon: category.icon,
            label: category.label,
            selected: widget.categories.contains(category),
            onTap: () => _toggleCategory(category),
          ),
        const AdaptiveOverlayDivider(),
        const AdaptiveOverlaySection(title: 'Niveau'),
        for (final entry in const [
          (_LineType.error, 'Erreur', Broken.close_circle),
          (_LineType.warning, 'Avertissement', Broken.warning_2),
          (_LineType.success, 'Réussite', Broken.tick_circle),
          (_LineType.info, 'Info', Broken.info_circle),
          (_LineType.debug, 'Debug', Broken.code_1),
        ])
          AdaptiveOverlayItem(
            icon: entry.$3,
            label: entry.$2,
            selected: widget.levels.contains(entry.$1),
            onTap: () => _toggleLevel(entry.$1),
          ),
        if (widget.availableTags.isNotEmpty) ...[
          const AdaptiveOverlayDivider(),
          const AdaptiveOverlaySection(title: 'Tags'),
          for (final tag in widget.availableTags)
            AdaptiveOverlayItem(
              icon: Broken.tag,
              label: tag,
              selected: widget.tags.contains(tag),
              onTap: () => _toggleTag(tag),
            ),
        ],
        if (widget.levels.isNotEmpty ||
            widget.categories.isNotEmpty ||
            widget.tags.isNotEmpty) ...[
          const AdaptiveOverlayDivider(),
          AdaptiveOverlayItem(
            icon: Broken.refresh_left_square,
            label: 'Réinitialiser tous les filtres',
            onTap: () {
              widget.onClear();
              setState(() {});
            },
          ),
        ],
      ],
    );
  }
}

class _ExtensionLogo extends StatelessWidget {
  final String? iconUrl;
  final int? sourceId;

  const _ExtensionLogo({required this.iconUrl, required this.sourceId});

  @override
  Widget build(BuildContext context) {
    final url = iconUrl?.trim() ?? '';
    if (url.isEmpty) {
      return const Icon(Broken.global, size: 10, color: Color(0xFF6366F1));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Image.network(
        url,
        key: ValueKey('extension-logo-${sourceId ?? 0}-$url'),
        width: 12,
        height: 12,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Broken.global,
          size: 10,
          color: Color(0xFF6366F1),
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
                        ? Broken.arrow_right_3
                        : Broken.arrow_down,
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
            ? Colors.indigo.withValues(alpha: 0.13)
            : Colors.indigo.withValues(alpha: 0.07);
      case _LineType.error:
        return isDark
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.04);
      case _LineType.warning:
        return isDark
            ? Colors.orange.withValues(alpha: 0.08)
            : Colors.orange.withValues(alpha: 0.04);
      case _LineType.success:
        return isDark
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.green.withValues(alpha: 0.035);
      default:
        return Colors.transparent;
    }
  }

  Color _textColor() {
    switch (line.type) {
      case _LineType.session:
        return isDark ? Colors.indigo.shade200 : Colors.indigo.shade800;
      case _LineType.error:
        return isDark ? Colors.red.shade300 : Colors.red.shade700;
      case _LineType.warning:
        return isDark ? Colors.orange.shade300 : Colors.orange.shade700;
      case _LineType.success:
        return isDark ? Colors.green.shade300 : Colors.green.shade800;
      case _LineType.debug:
        return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
      case _LineType.continuation:
        return isDark
            ? Colors.white.withValues(alpha: 0.5)
            : Colors.black.withValues(alpha: 0.45);
      case _LineType.info:
        return isDark ? Colors.cyan.shade200 : Colors.cyan.shade900;
    }
  }

  static final _urlRegex = RegExp(
    r'(https?:\/\/[^\s<>"\)\],;]+)',
    caseSensitive: false,
  );

  static String _prettyUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    final path = uri.path == '/' ? '' : uri.path;
    final label = '${uri.host}$path';
    return label.length > 44 ? '${label.substring(0, 41)}…' : label;
  }

  // ── Tag → colour mapping ──────────────────────────────────────────────────
    static const Map<String, Color> _tagColors = {
      'EXT':     Color(0xFF6366F1),
      'NET':     Color(0xFF06B6D4),
      'WATCH':   Color(0xFF10B981),
      'DL':      Color(0xFFF59E0B),
      'MANGA':   Color(0xFFEC4899),
      'HLS':     Color(0xFF8B5CF6),
      'INSTALL': Color(0xFF14B8A6),
      'READER':  Color(0xFFF97316),
      'UI':      Color(0xFF64748B),
      'MAINT':   Color(0xFF94A3B8),
      'SRCH':    Color(0xFF22D3EE),
      'PAGE':    Color(0xFF78716C),
      'REPO':    Color(0xFF6366F1),
    };

    // Matches "ExtName[lang]" from _extLog output: "… ExtName[fr] · …"
    static final _extNameRx = RegExp(r'\b([A-Za-z0-9_\-]+\[[a-z?]+\])\b');

    @override
    Widget build(BuildContext context) {
      final text = line.raw;
      final color = _textColor();
      final tagColor = line.tag != null ? (_tagColors[line.tag!] ?? Colors.blueGrey) : null;
      final extMatch = (line.tag == 'EXT') ? _extNameRx.firstMatch(text) : null;
      final extName = line.extensionName ?? extMatch?.group(1);

      Widget textChild;
      if (searchQuery.isNotEmpty) {
        textChild = _HighlightedText(text: text, query: searchQuery, baseColor: color);
      } else if (_urlRegex.hasMatch(text)) {
        final spans = <InlineSpan>[];
        int last = 0;
        for (final m in _urlRegex.allMatches(text)) {
          if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
          final url = text.substring(m.start, m.end);
          spans.add(TextSpan(
            text: _prettyUrl(url),
            style: TextStyle(
              color: Colors.lightBlue.shade400,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _openUrl(context, url),
          ));
          last = m.end;
        }
        if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
        textChild = Text.rich(
          TextSpan(children: spans),
          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: color, height: 1.5),
        );
      } else {
        textChild = Text(
          text,
          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: color, height: 1.5),
        );
      }

      return Container(
        color: _bgColor(),
        margin: line.type == _LineType.session ? const EdgeInsets.symmetric(vertical: 2) : null,
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tagColor != null && line.tag != null) ...[
              // Tag pill (EXT / NET / WATCH …)
              Container(
                margin: const EdgeInsets.only(top: 2, right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: tagColor.withValues(alpha: 0.55), width: 0.7),
                ),
                child: Text(
                  line.tag!,
                  style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w800,
                    color: tagColor, letterSpacing: 0.5, fontFamily: 'monospace',
                  ),
                ),
              ),
              // Extension name pill — only for EXT tag lines that carry a name
              if (extName != null)
                Container(
                  margin: const EdgeInsets.only(top: 2, right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35), width: 0.7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ExtensionLogo(
                        iconUrl: line.extensionIconUrl,
                        sourceId: line.extensionSourceId,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        extName,
                        style: const TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1), letterSpacing: 0.3, fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            Expanded(child: textChild),
          ],
        ),
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
            icon: const Icon(Broken.global, size: 20),
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
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

enum _LogCategory { extensions, watch, manga, images }

final _imageCategoryRegex = RegExp(
  r'\b(images?|img|thumbnails?|covers?|posters?|avatars?|banners?)\b|\.(jpe?g|png|webp|gif|bmp)\b',
  caseSensitive: false,
);

extension on _LogCategory {
  String get label => switch (this) {
        _LogCategory.extensions => 'Extensions',
        _LogCategory.watch => 'Watch',
        _LogCategory.manga => 'Manga',
        _LogCategory.images => 'Images',
      };

  IconData get icon => switch (this) {
        _LogCategory.extensions => Broken.global,
        _LogCategory.watch => Broken.video,
        _LogCategory.manga => Broken.book_1,
        _LogCategory.images => Broken.image,
      };

  bool matches(_LogLine line) {
    final tag = line.tag;
    switch (this) {
      case _LogCategory.extensions:
        return tag == 'EXT' || tag == 'REPO';
      case _LogCategory.watch:
        return tag == 'WATCH' || tag == 'HLS' || tag == 'PLAYER';
      case _LogCategory.manga:
        return tag == 'MANGA' || tag == 'READER' || tag == 'PAGE';
      case _LogCategory.images:
        return _imageCategoryRegex.hasMatch(line.raw);
    }
  }
}

enum _LineType {
  session,
  error,
  warning,
  success,
  info,
  debug,
  continuation,
}

class _LogLine {
  final String raw;
  final _LineType type;
  final String? tag;
  final int sessionId;
  final String? extensionName;
  final String? extensionIconUrl;
  final int? extensionSourceId;

  const _LogLine({
    required this.raw,
    required this.type,
    this.tag,
    this.sessionId = -1,
    this.extensionName,
    this.extensionIconUrl,
    this.extensionSourceId,
  });
}
