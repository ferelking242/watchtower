import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/browse/diag_video_preview.dart';
import 'package:watchtower/services/extension_diagnostics.dart';
import 'package:watchtower/utils/language.dart';

// ─── Notification helper ──────────────────────────────────────────────────────

class _DiagNotifService {
  _DiagNotifService._();
  static const _kChannelId = 'watchtower_diagnostic';
  static const _kChannelName = 'Diagnostic extensions';
  static const _kNotifId = 9902;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> _init() async {
    if (_initialized || kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) { _initialized = true; return; }
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(initSettings);
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(const AndroidNotificationChannel(
          _kChannelId, _kChannelName,
          description: 'Progression du diagnostic des extensions',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ));
      }
      _initialized = true;
    } catch (_) {}
  }

  static Future<void> showProgress({
    required int done, required int total,
    required String title, String? body,
  }) async {
    await _init();
    if (!_initialized || kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final android = AndroidNotificationDetails(
        _kChannelId, _kChannelName,
        channelDescription: 'Progression du diagnostic',
        importance: Importance.low, priority: Priority.low,
        onlyAlertOnce: true, showProgress: true,
        maxProgress: total, progress: done,
        ongoing: done < total, autoCancel: done >= total,
        icon: '@mipmap/launcher_icon',
      );
      await _plugin.show(_kNotifId, title,
          body ?? '$done / $total extensions testées',
          NotificationDetails(android: android));
    } catch (_) {}
  }

  static Future<void> dismiss() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try { await _plugin.cancel(_kNotifId); } catch (_) {}
  }
}

// ─── Extension status ─────────────────────────────────────────────────────────

enum _ExtStatus { idle, running, done, failed }

// ─── Concurrency pool label ───────────────────────────────────────────────────

const _kDefaultPool = 6;

// ─── Main screen ─────────────────────────────────────────────────────────────

class ExtensionDiagnosticScreen extends StatefulWidget {
  final ItemType itemType;
  const ExtensionDiagnosticScreen({required this.itemType, super.key});

  @override
  State<ExtensionDiagnosticScreen> createState() =>
      _ExtensionDiagnosticScreenState();
}

class _ExtensionDiagnosticScreenState
    extends State<ExtensionDiagnosticScreen> {
  // ── Sources ────────────────────────────────────────────────────────────────
  List<Source> _allSources = [];

  // ── Filters ────────────────────────────────────────────────────────────────
  String _search = '';
  String? _filterLangCode;
  SourceCodeLanguage? _filterType;
  bool? _filterNsfw;
  bool _showFilters = false;

  // ── Run state ──────────────────────────────────────────────────────────────
  bool _running = false;
  bool _started = false;
  int _done = 0;
  int _total = 0;
  final Map<int, _ExtStatus> _statusMap = {};
  final Map<int, ExtDiagResult> _resultMap = {};
  final List<String> _logLines = [];
  DateTime? _startTime;
  Timer? _elapsedTimer;
  String _elapsedLabel = '0s';
  String? _savedPath;
  String? _fullReport;

  // ── Selection & view ───────────────────────────────────────────────────────
  Source? _selectedSource;
  bool _markdownMode = false;

  // ── Log scroll ─────────────────────────────────────────────────────────────
  final ScrollController _logScroll = ScrollController();

  // ── Getters ────────────────────────────────────────────────────────────────

  List<Source> get _filtered {
    var list = _allSources;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((s) =>
          (s.name ?? '').toLowerCase().contains(q) ||
          (s.lang ?? '').toLowerCase().contains(q)).toList();
    }
    if (_filterLangCode != null) {
      list = list.where((s) =>
          s.lang?.toLowerCase() == _filterLangCode).toList();
    }
    if (_filterType != null) {
      list = list.where((s) => s.sourceCodeLanguage == _filterType).toList();
    }
    if (_filterNsfw != null) {
      list = list.where((s) => (s.isNsfw ?? false) == _filterNsfw).toList();
    }
    return list;
  }

  List<String> get _availableLangCodes {
    return _allSources
        .map((s) => s.lang?.toLowerCase() ?? '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()..sort();
  }

  int get _okCount => _resultMap.values.where((r) => r.allOk).length;
  int get _failCount => _resultMap.values.where((r) => r.anyFailed).length;
  double get _progress => _total == 0 ? 0.0 : _done / _total;
  bool get _isComplete => _started && !_running && _done == _total && _total > 0;

  String get _scopeLabel {
    if (_filterLangCode != null) return 'Langue: ${completeLanguageName(_filterLangCode!)}';
    if (_filterType != null) return 'Type: ${_filterType!.name}';
    if (_filterNsfw == true) return 'NSFW seulement';
    if (_filterNsfw == false) return 'SFW seulement';
    return 'Toutes les extensions';
  }

  ExtDiagResult? get _selectedResult =>
      _selectedSource != null ? _resultMap[_selectedSource!.id] : null;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _lockLandscape();
    _loadSources();
  }

  void _lockLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    _elapsedTimer?.cancel();
    _logScroll.dispose();
    super.dispose();
  }

  void _loadSources() {
    final sources = isar.sources
        .filter()
        .idIsNotNull()
        .and()
        .isAddedEqualTo(true)
        .and()
        .itemTypeEqualTo(widget.itemType)
        .findAllSync()
        .where((s) => !(s.name == 'local' && (s.lang?.isEmpty ?? true)))
        .toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    setState(() => _allSources = sources);
  }

  // ── Start / Stop ───────────────────────────────────────────────────────────

  Future<void> _startDiagnostics() async {
    final sources = _filtered;
    if (sources.isEmpty) {
      _showSnack('Aucune extension pour ce filtre.');
      return;
    }
    setState(() {
      _running = true;
      _started = true;
      _done = 0;
      _total = sources.length;
      _logLines.clear();
      _resultMap.clear();
      _savedPath = null;
      _fullReport = null;
      _markdownMode = false;
      for (final s in sources) {
        _statusMap[s.id!] = _ExtStatus.idle;
      }
      _startTime = DateTime.now();
      _elapsedLabel = '0s';
    });

    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final el = DateTime.now().difference(_startTime!);
      setState(() => _elapsedLabel = _fmtDuration(el.inMilliseconds));
    });

    await _DiagNotifService.showProgress(
      done: 0, total: sources.length,
      title: 'Diagnostic ${_typeLabelShort()} en cours…',
    );

    await runDiagnosticsForSources(
      sources,
      widget.itemType,
      concurrency: _kDefaultPool,
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _resultMap[result.source.id!] = result;
          _statusMap[result.source.id!] =
              result.allOk ? _ExtStatus.done : _ExtStatus.failed;
          _done++;
          if (_selectedSource?.id == result.source.id) {
            // refresh right panel
          }
        });
        _DiagNotifService.showProgress(
          done: _done, total: _total,
          title: 'Diagnostic ${_typeLabelShort()}',
          body: '$_done / $_total — ${result.source.name}',
        );
      },
      onLog: (line) {
        if (!mounted) return;
        setState(() {
          _logLines.add(line);
          // mark running
          for (final s in sources) {
            if (line.contains('"${s.name}"') && line.contains('[RUN]')) {
              _statusMap[s.id!] = _ExtStatus.running;
            }
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScroll.hasClients && _logScroll.position.maxScrollExtent > 0) {
            _logScroll.animateTo(_logScroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut);
          }
        });
      },
    );

    _elapsedTimer?.cancel();

    final savedPath = await saveDiagnosticReport(
      results: _resultMap.values.toList(),
      itemType: widget.itemType,
      scopeLabel: _scopeLabel,
    );
    final report = generateMarkdownReport(
      results: _resultMap.values.toList(),
      itemType: widget.itemType,
      scopeLabel: _scopeLabel,
    );

    final ok = _okCount;
    final failed = _failCount;
    await _DiagNotifService.dismiss();
    await _DiagNotifService.showProgress(
      done: _resultMap.length, total: _resultMap.length,
      title: 'Diagnostic terminé',
      body: '$ok OK · $failed échec(s) sur ${_resultMap.length}',
    );

    if (mounted) {
      setState(() {
        _running = false;
        _savedPath = savedPath;
        _fullReport = report;
      });
    }
  }

  void _resetDiagnostics() {
    setState(() {
      _running = false;
      _started = false;
      _done = 0;
      _total = 0;
      _logLines.clear();
      _resultMap.clear();
      _statusMap.clear();
      _savedPath = null;
      _fullReport = null;
      _selectedSource = null;
      _markdownMode = false;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _typeLabelShort() => switch (widget.itemType) {
        ItemType.anime => 'Anime',
        ItemType.manga => 'Manga',
        ItemType.novel => 'Novel',
        _ => widget.itemType.name,
      };

  String _fmtDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    final s = ms ~/ 1000;
    if (s < 60) return '${s}s';
    return '${s ~/ 60}m${(s % 60).toString().padLeft(2, "0")}s';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(msg),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _copyReport() async {
    final report = _fullReport;
    if (report == null) { _showSnack('Aucun rapport disponible.'); return; }
    await Clipboard.setData(ClipboardData(text: report));
    _showSnack('Rapport copié dans le presse-papiers ✓');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Row(
          children: [
            // ── LEFT PANEL ────────────────────────────────────────────────
            SizedBox(
              width: 300,
              child: _LeftPanel(
                allSources: _allSources,
                filtered: _filtered,
                availableLangCodes: _availableLangCodes,
                search: _search,
                filterLangCode: _filterLangCode,
                filterType: _filterType,
                filterNsfw: _filterNsfw,
                showFilters: _showFilters,
                statusMap: _statusMap,
                selectedSource: _selectedSource,
                running: _running,
                started: _started,
                cs: cs,
                onSearchChanged: (v) => setState(() => _search = v),
                onToggleFilters: () => setState(() => _showFilters = !_showFilters),
                onLangCodeFilter: (v) => setState(() => _filterLangCode = v),
                onTypeFilter: (v) => setState(() => _filterType = v),
                onNsfwFilter: (v) => setState(() => _filterNsfw = v),
                onSelectSource: (s) => setState(() => _selectedSource = s),
                onStart: _running ? null : _startDiagnostics,
                onReset: _running ? null : _resetDiagnostics,
                itemType: widget.itemType,
                typeLabelShort: _typeLabelShort(),
                onBack: () => context.pop(),
              ),
            ),

            // ── DIVIDER ───────────────────────────────────────────────────
            VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),

            // ── RIGHT PANEL ───────────────────────────────────────────────
            Expanded(
              child: _RightPanel(
                running: _running,
                started: _started,
                isComplete: _isComplete,
                done: _done,
                total: _total,
                okCount: _okCount,
                failCount: _failCount,
                progress: _progress,
                elapsedLabel: _elapsedLabel,
                savedPath: _savedPath,
                fullReport: _fullReport,
                markdownMode: _markdownMode,
                selectedSource: _selectedSource,
                selectedResult: _selectedResult,
                logLines: _logLines,
                logScroll: _logScroll,
                itemType: widget.itemType,
                cs: cs,
                onToggleMarkdown: () => setState(() => _markdownMode = !_markdownMode),
                onCopyReport: _copyReport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── LEFT PANEL ───────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final List<Source> allSources;
  final List<Source> filtered;
  final List<String> availableLangCodes;
  final String search;
  final String? filterLangCode;
  final SourceCodeLanguage? filterType;
  final bool? filterNsfw;
  final bool showFilters;
  final Map<int, _ExtStatus> statusMap;
  final Source? selectedSource;
  final bool running;
  final bool started;
  final ColorScheme cs;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleFilters;
  final ValueChanged<String?> onLangCodeFilter;
  final ValueChanged<SourceCodeLanguage?> onTypeFilter;
  final ValueChanged<bool?> onNsfwFilter;
  final ValueChanged<Source> onSelectSource;
  final VoidCallback? onStart;
  final VoidCallback? onReset;
  final ItemType itemType;
  final String typeLabelShort;
  final VoidCallback onBack;

  const _LeftPanel({
    required this.allSources,
    required this.filtered,
    required this.availableLangCodes,
    required this.search,
    required this.filterLangCode,
    required this.filterType,
    required this.filterNsfw,
    required this.showFilters,
    required this.statusMap,
    required this.selectedSource,
    required this.running,
    required this.started,
    required this.cs,
    required this.onSearchChanged,
    required this.onToggleFilters,
    required this.onLangCodeFilter,
    required this.onTypeFilter,
    required this.onNsfwFilter,
    required this.onSelectSource,
    required this.onStart,
    required this.onReset,
    required this.itemType,
    required this.typeLabelShort,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = filterLangCode != null ||
        filterType != null || filterNsfw != null || search.isNotEmpty;

    return Column(
      children: [
        // ── Header ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Diagnostic $typeLabelShort',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${filtered.length}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer),
              ),
            ),
          ]),
        ),

        // ── Search + filter toggle ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  onChanged: onSearchChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Rechercher…',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _FilterToggleBtn(
              active: showFilters,
              hasFilters: hasActiveFilters,
              cs: cs,
              onTap: onToggleFilters,
            ),
          ]),
        ),

        // ── Filter panel ──────────────────────────────────────────────
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 0),
          secondChild: _FilterPanel(
            availableLangCodes: availableLangCodes,
            filterLangCode: filterLangCode,
            filterType: filterType,
            filterNsfw: filterNsfw,
            cs: cs,
            onLangCode: onLangCodeFilter,
            onType: onTypeFilter,
            onNsfw: onNsfwFilter,
          ),
          crossFadeState: showFilters
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),

        // ── Extension list ────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('Aucune extension',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final src = filtered[i];
                    final status = statusMap[src.id] ?? _ExtStatus.idle;
                    final selected = selectedSource?.id == src.id;
                    return _ExtListItem(
                      source: src,
                      status: status,
                      selected: selected,
                      cs: cs,
                      onTap: () => onSelectSource(src),
                    );
                  },
                ),
        ),

        // ── Action buttons ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(children: [
            if (started)
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  onPressed: running ? null : onReset,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            if (started) const SizedBox(width: 8),
            Expanded(
              flex: started ? 2 : 1,
              child: FilledButton.icon(
                icon: Icon(running
                    ? Icons.hourglass_empty_rounded
                    : Icons.play_arrow_rounded, size: 16),
                label: Text(
                  running
                      ? 'En cours…'
                      : started ? 'Relancer' : 'Lancer',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: running ? null : onStart,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ─── Filter toggle button ─────────────────────────────────────────────────────

class _FilterToggleBtn extends StatelessWidget {
  final bool active;
  final bool hasFilters;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _FilterToggleBtn({
    required this.active,
    required this.hasFilters,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: active
                  ? cs.primaryContainer
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 18,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
        if (hasFilters)
          Positioned(
            top: -2, right: -2,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Filter panel ─────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final List<String> availableLangCodes;
  final String? filterLangCode;
  final SourceCodeLanguage? filterType;
  final bool? filterNsfw;
  final ColorScheme cs;
  final ValueChanged<String?> onLangCode;
  final ValueChanged<SourceCodeLanguage?> onType;
  final ValueChanged<bool?> onNsfw;

  const _FilterPanel({
    required this.availableLangCodes,
    required this.filterLangCode,
    required this.filterType,
    required this.filterNsfw,
    required this.cs,
    required this.onLangCode,
    required this.onType,
    required this.onNsfw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Langue
          if (availableLangCodes.isNotEmpty) ...[
            Text('Langue', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant, letterSpacing: 0.5)),
            const SizedBox(height: 5),
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _MiniChip(
                    label: 'Toutes',
                    selected: filterLangCode == null,
                    cs: cs,
                    onTap: () => onLangCode(null),
                  ),
                  ...availableLangCodes.map((l) => _MiniChip(
                        label: l.toUpperCase(),
                        selected: filterLangCode == l,
                        cs: cs,
                        onTap: () => onLangCode(filterLangCode == l ? null : l),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Type de source
          Text('Type', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 5),
          Wrap(
            spacing: 4, runSpacing: 4,
            children: [
              _MiniChip(label: 'Tout', selected: filterType == null, cs: cs,
                  onTap: () => onType(null)),
              _MiniChip(label: 'Dart', selected: filterType == SourceCodeLanguage.dart, cs: cs,
                  onTap: () => onType(filterType == SourceCodeLanguage.dart ? null : SourceCodeLanguage.dart)),
              _MiniChip(label: 'JS', selected: filterType == SourceCodeLanguage.javascript, cs: cs,
                  onTap: () => onType(filterType == SourceCodeLanguage.javascript ? null : SourceCodeLanguage.javascript)),
              _MiniChip(label: 'Mihon', selected: filterType == SourceCodeLanguage.mihon, cs: cs,
                  onTap: () => onType(filterType == SourceCodeLanguage.mihon ? null : SourceCodeLanguage.mihon)),
            ],
          ),
          const SizedBox(height: 8),

          // NSFW
          Text('Contenu', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant, letterSpacing: 0.5)),
          const SizedBox(height: 5),
          Row(children: [
            _MiniChip(label: 'Tout', selected: filterNsfw == null, cs: cs,
                onTap: () => onNsfw(null)),
            const SizedBox(width: 4),
            _MiniChip(label: 'SFW', selected: filterNsfw == false, cs: cs,
                onTap: () => onNsfw(filterNsfw == false ? null : false)),
            const SizedBox(width: 4),
            _MiniChip(label: 'NSFW', selected: filterNsfw == true, cs: cs,
                onTap: () => onNsfw(filterNsfw == true ? null : true),
                danger: true),
          ]),
        ],
      ),
    );
  }
}

// ─── Mini chip ────────────────────────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;
  final bool danger;

  const _MiniChip({
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? (danger ? cs.error : cs.primary)
                : cs.outlineVariant,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: fg)),
      ),
    );
  }
}

// ─── Extension list item ──────────────────────────────────────────────────────

class _ExtListItem extends StatefulWidget {
  final Source source;
  final _ExtStatus status;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _ExtListItem({
    required this.source,
    required this.status,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  @override
  State<_ExtListItem> createState() => _ExtListItemState();
}

class _ExtListItemState extends State<_ExtListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final src = widget.source;
    final status = widget.status;

    Color badgeColor;
    IconData badgeIcon;
    bool animate = false;

    switch (status) {
      case _ExtStatus.idle:
        badgeColor = cs.outlineVariant;
        badgeIcon = Icons.circle_outlined;
        break;
      case _ExtStatus.running:
        badgeColor = Colors.amber.shade400;
        badgeIcon = Icons.pending_rounded;
        animate = true;
        break;
      case _ExtStatus.done:
        badgeColor = Colors.green.shade500;
        badgeIcon = Icons.check_circle_rounded;
        break;
      case _ExtStatus.failed:
        badgeColor = cs.error;
        badgeIcon = Icons.cancel_rounded;
        break;
    }

    final bg = widget.selected
        ? cs.primaryContainer.withValues(alpha: 0.35)
        : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            // Status indicator
            animate
                ? AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Icon(badgeIcon,
                        size: 14,
                        color: badgeColor.withValues(alpha: 0.4 + 0.6 * _pulse.value)),
                  )
                : Icon(badgeIcon, size: 14, color: badgeColor),
            const SizedBox(width: 8),

            // Icon
            if ((src.iconUrl ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  src.iconUrl!,
                  width: 22, height: 22, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.extension_rounded,
                          size: 22, color: cs.onSurfaceVariant),
                ),
              )
            else
              Icon(Icons.extension_rounded,
                  size: 22, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),

            // Name
            Expanded(
              child: Text(
                src.name ?? '?',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: widget.selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: widget.selected ? cs.primary : cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Lang badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                (src.lang ?? '?').toUpperCase(),
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.5),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── RIGHT PANEL ──────────────────────────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final bool running;
  final bool started;
  final bool isComplete;
  final int done;
  final int total;
  final int okCount;
  final int failCount;
  final double progress;
  final String elapsedLabel;
  final String? savedPath;
  final String? fullReport;
  final bool markdownMode;
  final Source? selectedSource;
  final ExtDiagResult? selectedResult;
  final List<String> logLines;
  final ScrollController logScroll;
  final ItemType itemType;
  final ColorScheme cs;
  final VoidCallback onToggleMarkdown;
  final VoidCallback onCopyReport;

  const _RightPanel({
    required this.running,
    required this.started,
    required this.isComplete,
    required this.done,
    required this.total,
    required this.okCount,
    required this.failCount,
    required this.progress,
    required this.elapsedLabel,
    required this.savedPath,
    required this.fullReport,
    required this.markdownMode,
    required this.selectedSource,
    required this.selectedResult,
    required this.logLines,
    required this.logScroll,
    required this.itemType,
    required this.cs,
    required this.onToggleMarkdown,
    required this.onCopyReport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Progress header ───────────────────────────────────────────
        _ProgressHeader(
          running: running,
          started: started,
          isComplete: isComplete,
          done: done,
          total: total,
          okCount: okCount,
          failCount: failCount,
          progress: progress,
          elapsedLabel: elapsedLabel,
          savedPath: savedPath,
          fullReport: fullReport,
          markdownMode: markdownMode,
          cs: cs,
          onToggleMarkdown: onToggleMarkdown,
          onCopyReport: onCopyReport,
        ),

        // ── Content area ──────────────────────────────────────────────
        Expanded(
          child: _buildContent(context),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    // Markdown view (full report)
    if (markdownMode && fullReport != null) {
      return _MarkdownView(content: fullReport!, cs: cs);
    }

    // Not started yet
    if (!started) {
      return _EmptyState(
        icon: Icons.science_outlined,
        title: 'Prêt à diagnostiquer',
        subtitle: 'Sélectionnez vos filtres puis lancez le diagnostic.',
        cs: cs,
      );
    }

    // Nothing selected
    if (selectedSource == null) {
      return _EmptyState(
        icon: Icons.touch_app_outlined,
        title: 'Sélectionnez une extension',
        subtitle: 'Touchez une extension dans la liste pour voir ses résultats.',
        cs: cs,
      );
    }

    // Selected but not yet diagnosed
    if (selectedResult == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (running)
              const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(height: 12),
            Text(
              running ? 'Diagnostic en cours…' : 'En attente',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Show result detail
    return _ExtDetailView(
      result: selectedResult!,
      itemType: itemType,
      cs: cs,
    );
  }
}

// ─── Progress header ──────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final bool running;
  final bool started;
  final bool isComplete;
  final int done;
  final int total;
  final int okCount;
  final int failCount;
  final double progress;
  final String elapsedLabel;
  final String? savedPath;
  final String? fullReport;
  final bool markdownMode;
  final ColorScheme cs;
  final VoidCallback onToggleMarkdown;
  final VoidCallback onCopyReport;

  const _ProgressHeader({
    required this.running,
    required this.started,
    required this.isComplete,
    required this.done,
    required this.total,
    required this.okCount,
    required this.failCount,
    required this.progress,
    required this.elapsedLabel,
    required this.savedPath,
    required this.fullReport,
    required this.markdownMode,
    required this.cs,
    required this.onToggleMarkdown,
    required this.onCopyReport,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (progress * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        children: [
          Row(children: [
            // Status icon
            if (running)
              SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary))
            else if (isComplete)
              Icon(
                failCount == 0
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                size: 16,
                color: failCount == 0 ? Colors.green : cs.error,
              )
            else
              Icon(Icons.science_outlined, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),

            // Status text
            Text(
              !started
                  ? 'En attente'
                  : running
                      ? 'En cours — $done / $total ($pct%)'
                      : 'Terminé — $done extensions',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 10),

            // Stats badges
            if (started && done > 0) ...[
              _StatBadge(label: '✅ $okCount', color: Colors.green.shade600, bg: Colors.green.withValues(alpha: 0.1)),
              const SizedBox(width: 4),
              _StatBadge(label: '❌ $failCount', color: cs.error, bg: cs.errorContainer.withValues(alpha: 0.3)),
              const SizedBox(width: 4),
              _StatBadge(label: '⏱ $elapsedLabel', color: cs.onSurfaceVariant, bg: cs.surfaceContainerHighest),
            ],

            const Spacer(),

            // Actions
            if (fullReport != null) ...[
              _ActionBtn(
                icon: markdownMode
                    ? Icons.view_agenda_outlined
                    : Icons.code_rounded,
                label: markdownMode ? 'Résultats' : 'Markdown',
                active: markdownMode,
                cs: cs,
                onTap: onToggleMarkdown,
              ),
              const SizedBox(width: 6),
              _ActionBtn(
                icon: Icons.copy_rounded,
                label: 'Copier MD',
                cs: cs,
                onTap: onCopyReport,
              ),
            ],
          ]),

          if (started) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                    running ? cs.primary : (failCount == 0 ? Colors.green : cs.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _StatBadge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.cs,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? cs.primary : cs.outlineVariant),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14,
              color: active ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: active ? cs.primary : cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme cs;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: cs.onSurface)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 12, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Extension detail view ────────────────────────────────────────────────────

class _ExtDetailView extends StatelessWidget {
  final ExtDiagResult result;
  final ItemType itemType;
  final ColorScheme cs;

  const _ExtDetailView({
    required this.result,
    required this.itemType,
    required this.cs,
  });

  String _fmtMs(int ms) {
    if (ms == 0) return '—';
    if (ms < 1000) return '${ms}ms';
    final s = ms ~/ 1000;
    return '${s}.${((ms % 1000) ~/ 100)}s';
  }

  @override
  Widget build(BuildContext context) {
    final src = result.source;
    final allOk = result.allOk;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Extension header ─────────────────────────────────────────
          Row(children: [
            if ((src.iconUrl ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  src.iconUrl!,
                  width: 40, height: 40, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.extension_rounded, size: 40,
                          color: cs.onSurfaceVariant),
                ),
              )
            else
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.extension_rounded,
                    size: 22, color: cs.onSurfaceVariant),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(src.name ?? 'Unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 2),
                  Row(children: [
                    _TagBadge(
                        label: (src.lang ?? '?').toUpperCase(), cs: cs),
                    const SizedBox(width: 4),
                    if (src.sourceCodeLanguage != null)
                      _TagBadge(
                          label: src.sourceCodeLanguage!.name, cs: cs,
                          color: cs.secondaryContainer,
                          textColor: cs.onSecondaryContainer),
                    if (src.isNsfw == true) ...[
                      const SizedBox(width: 4),
                      _TagBadge(label: 'NSFW', cs: cs,
                          color: cs.errorContainer.withValues(alpha: 0.6),
                          textColor: cs.onErrorContainer),
                    ],
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: allOk
                        ? Colors.green.withValues(alpha: 0.12)
                        : cs.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    allOk ? '✅ Tout OK' : '❌ ${result.failCount} échec(s)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: allOk
                            ? Colors.green.shade700
                            : cs.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 4),
                Text(_fmtMs(result.totalMs),
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ]),

          const SizedBox(height: 16),

          // ── Step cards grid ──────────────────────────────────────────
          Text('Étapes du diagnostic',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: cs.onSurface)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: DiagStep.values.map((step) {
              final stepResult = result.steps[step];
              return _StepCard(
                  step: step,
                  result: stepResult,
                  cs: cs,
                  itemType: itemType);
            }).toList(),
          ),

          // ── Error details ─────────────────────────────────────────
          if (result.anyFailed) ...[
            const SizedBox(height: 16),
            Text('Erreurs détaillées',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: cs.error)),
            const SizedBox(height: 8),
            ...result.steps.entries
                .where((e) => !e.value.ok && e.value.error != null)
                .map((e) => _ErrorRow(
                    step: e.key,
                    error: e.value.error!,
                    cs: cs,
                    itemType: itemType)),
          ],

          // ── Media preview ─────────────────────────────────────────
          if (result.steps[DiagStep.media]?.ok == true &&
              result.previewUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            _MediaPreviewSection(
              previewUrls: result.previewUrls,
              mediaCount: result.steps[DiagStep.media]?.count ?? 0,
              itemType: itemType,
              cs: cs,
            ),
          ],
        ],
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final Color? color;
  final Color? textColor;

  const _TagBadge({
    required this.label,
    required this.cs,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: textColor ?? cs.onSurfaceVariant,
              letterSpacing: 0.3)),
    );
  }
}

// ─── Step card ────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final DiagStep step;
  final DiagStepResult? result;
  final ColorScheme cs;
  final ItemType itemType;

  const _StepCard({
    required this.step,
    required this.result,
    required this.cs,
    required this.itemType,
  });

  String get _stepName => switch (step) {
        DiagStep.popular => 'Popular',
        DiagStep.latest  => 'Latest',
        DiagStep.detail  => 'Détail',
        DiagStep.media   => itemType == ItemType.anime ? 'Vidéos' : 'Pages',
      };

  IconData get _stepIcon => switch (step) {
        DiagStep.popular => Icons.list_alt_rounded,
        DiagStep.latest  => Icons.update_rounded,
        DiagStep.detail  => Icons.info_outline_rounded,
        DiagStep.media   => itemType == ItemType.anime
            ? Icons.play_circle_outline_rounded
            : Icons.auto_stories_rounded,
      };

  String _fmtMs(int ms) {
    if (ms == 0) return '—';
    if (ms < 1000) return '${ms}ms';
    final s = ms ~/ 1000;
    return '${s}.${((ms % 1000) ~/ 100)}s';
  }

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return _cardShell(
        bg: cs.surfaceContainerHighest,
        border: cs.outlineVariant,
        child: Row(children: [
          Icon(_stepIcon, size: 18, color: cs.outlineVariant),
          const SizedBox(width: 8),
          Text(_stepName,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.outlineVariant)),
          const Spacer(),
          Icon(Icons.hourglass_empty_rounded,
              size: 14, color: cs.outlineVariant),
        ]),
      );
    }

    final ok = result!.ok;
    final bg = ok
        ? Colors.green.withValues(alpha: 0.08)
        : cs.errorContainer.withValues(alpha: 0.25);
    final border = ok
        ? Colors.green.withValues(alpha: 0.3)
        : cs.error.withValues(alpha: 0.4);
    final fg = ok ? Colors.green.shade700 : cs.error;

    return _cardShell(
      bg: bg,
      border: border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(_stepIcon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(_stepName,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: fg)),
            const Spacer(),
            Icon(
                ok ? Icons.check_rounded : Icons.close_rounded,
                size: 14, color: fg),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            if (result!.count != null)
              Text('${result!.count} résultats',
                  style: TextStyle(
                      fontSize: 10.5, color: fg.withValues(alpha: 0.85)))
            else if (result!.error != null)
              Expanded(
                child: Text(
                  result!.error!,
                  style: TextStyle(
                      fontSize: 9.5,
                      color: fg.withValues(alpha: 0.85),
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            const Spacer(),
            Text(_fmtMs(result!.ms),
                style: TextStyle(
                    fontSize: 10,
                    color: fg.withValues(alpha: 0.7))),
          ]),
        ],
      ),
    );
  }

  Widget _cardShell({
    required Color bg,
    required Color border,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

// ─── Error row ────────────────────────────────────────────────────────────────

class _ErrorRow extends StatelessWidget {
  final DiagStep step;
  final String error;
  final ColorScheme cs;
  final ItemType itemType;

  const _ErrorRow({
    required this.step,
    required this.error,
    required this.cs,
    required this.itemType,
  });

  String get _stepName => switch (step) {
        DiagStep.popular => 'Popular',
        DiagStep.latest  => 'Latest',
        DiagStep.detail  => 'Détail',
        DiagStep.media   => itemType == ItemType.anime ? 'Vidéos' : 'Pages',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 14, color: cs.error),
          const SizedBox(width: 8),
          Text('[$_stepName] ',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  color: cs.error)),
          Expanded(
            child: SelectableText(
              error,
              style: TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Media preview section ────────────────────────────────────────────────────

class _MediaPreviewSection extends StatefulWidget {
  final List<DiagMediaUrl> previewUrls;
  final int mediaCount;
  final ItemType itemType;
  final ColorScheme cs;

  const _MediaPreviewSection({
    required this.previewUrls,
    required this.mediaCount,
    required this.itemType,
    required this.cs,
  });

  @override
  State<_MediaPreviewSection> createState() => _MediaPreviewSectionState();
}

class _MediaPreviewSectionState extends State<_MediaPreviewSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isAnime = widget.itemType == ItemType.anime;
    final urls = widget.previewUrls;
    final count = widget.mediaCount;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(children: [
                Icon(
                  isAnime
                      ? Icons.play_circle_outline_rounded
                      : Icons.auto_stories_rounded,
                  size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  isAnime ? 'Prévisualisation vidéo' : 'Prévisualisation pages',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: cs.onSurface)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('$count sources',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer)),
                ),
                const Spacer(),
                Text(
                  _expanded ? 'Masquer' : 'Afficher',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: cs.primary,
                      fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18, color: cs.primary),
              ]),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: isAnime
                  ? DiagVideoPreview(urls: urls, cs: cs)
                  : _PagePreview(urls: urls, cs: cs),
            ),
        ],
      ),
    );
  }
}

// ─── Page preview (manga) — placeholder to keep file compiling ────────────────

class _FakeVideoPreviewPlaceholder {
  // _VideoPreview removed — now handled by DiagVideoPreview (conditional import)
  // See diag_video_preview.dart / diag_video_preview_io.dart / diag_video_preview_web.dart
}

// ─── Page preview (manga) ─────────────────────────────────────────────────────

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

    return Column(
      children: [
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
            Text(
              'Page ${_currentPage + 1} / ${urls.length}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface),
            ),
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
        const SizedBox(height: 8),
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
                        strokeWidth: 2,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded,
                            size: 40, color: cs.outlineVariant),
                        const SizedBox(height: 8),
                        Text('Image inaccessible',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Markdown view ────────────────────────────────────────────────────────────

class _MarkdownView extends StatelessWidget {
  final String content;
  final ColorScheme cs;

  const _MarkdownView({required this.content, required this.cs});

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');

    return Container(
      color: cs.surfaceContainerLowest,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lines.length,
        itemBuilder: (_, i) {
          final line = lines[i];
          return _MarkdownLine(line: line, cs: cs);
        },
      ),
    );
  }
}

class _MarkdownLine extends StatelessWidget {
  final String line;
  final ColorScheme cs;

  const _MarkdownLine({required this.line, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (line.isEmpty) return const SizedBox(height: 4);

    // H1
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: SelectableText(
          line.substring(2),
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: cs.onSurface),
        ),
      );
    }
    // H2
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 8),
        child: SelectableText(
          line.substring(3),
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: cs.primary),
        ),
      );
    }
    // H3
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 6),
        child: SelectableText(
          line.substring(4),
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: cs.onSurface),
        ),
      );
    }
    // Table separator
    if (RegExp(r'^\|[-|: ]+\|$').hasMatch(line)) {
      return Divider(height: 1, color: cs.outlineVariant);
    }
    // Table row
    if (line.startsWith('|') && line.endsWith('|')) {
      final cells = line
          .split('|')
          .where((c) => c.isNotEmpty)
          .map((c) => c.trim())
          .toList();
      return Container(
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: Row(
          children: cells.map((c) {
            final bold = c.startsWith('**') && c.endsWith('**');
            final text = bold ? c.substring(2, c.length - 2) : c;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 5, horizontal: 8),
                child: SelectableText(
                  text,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          bold ? FontWeight.bold : FontWeight.normal,
                      color: cs.onSurface),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }
    // Code block delimiter
    if (line.trim() == '```') {
      return Divider(color: cs.outlineVariant, height: 4);
    }
    // Horizontal rule
    if (line.trim() == '---') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: cs.outlineVariant, thickness: 1),
      );
    }
    // Summary / details tags (raw)
    if (line.startsWith('<')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: SelectableText(
          line,
          style: TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        ),
      );
    }

    // Default text
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: SelectableText(
        line,
        style: TextStyle(fontSize: 12.5, color: cs.onSurface),
      ),
    );
  }
}
