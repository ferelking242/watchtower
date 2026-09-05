import 'dart:async';

import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/modules/browse/diag_detail_widgets.dart';
import 'package:watchtower/modules/browse/diag_ui_widgets.dart';
import 'package:watchtower/services/diag_notification_service.dart';
import 'package:watchtower/services/extension_diagnostics.dart';
import 'package:watchtower/utils/language.dart';

// ─── View model enums ─────────────────────────────────────────────────────────

/// The three main pages of the diagnostic screen (navigation, not drawers).
enum _DiagView { diag, extensions, results }

/// ExtStatus & ReportFormat are declared in diag_ui_widgets.dart.

/// Filter presets over the extension list.
enum _StatusFilter { all, ok, failed, running, idle }

/// Sorting applied to the visible extension list.
enum _SortMode { name, status, duration }

// ─── Screen ───────────────────────────────────────────────────────────────────

class ExtensionDiagnosticScreen extends StatefulWidget {
  final ItemType itemType;
  const ExtensionDiagnosticScreen({required this.itemType, super.key});

  @override
  State<ExtensionDiagnosticScreen> createState() =>
      _ExtensionDiagnosticScreenState();
}

class _ExtensionDiagnosticScreenState extends State<ExtensionDiagnosticScreen> {
  // ── Sources & selection scope ──────────────────────────────────────────────
  List<Source> _allSources = [];
  final Set<int> _scopeIds = {};

  // ── Filters / sort ─────────────────────────────────────────────────────────
  String _search = '';
  String? _filterLangCode;
  SourceCodeLanguage? _filterType;
  bool? _filterNsfw;
  _StatusFilter _statusFilter = _StatusFilter.all;
  _SortMode _sortMode = _SortMode.name;
  bool _onlyErrors = false;
  bool _onlyTested = false;

  // ── Layout ─────────────────────────────────────────────────────────────────
  bool _wide = false;
  bool _panelOpen = false; // narrow: bottom sheet · wide: side panel
  bool _detailVisible = false;
  _DiagView _view = _DiagView.diag;

  // ── Run state ──────────────────────────────────────────────────────────────
  bool _running = false;
  bool _paused = false;
  bool _cancelling = false;
  bool _started = false;
  int _done = 0;
  int _total = 0;
  List<Source> _runSnapshot = [];
  final Map<int, ExtStatus> _statusMap = {};
  final Map<int, ExtDiagResult> _resultMap = {};
  final List<String> _logLines = [];
  DateTime? _startTime;
  Timer? _elapsedTimer;
  String _elapsedLabel = '0s';
  DiagRunControls? _controls;

  // ── Detail / selection ─────────────────────────────────────────────────────
  Source? _selectedSource;

  // ── Reports (multi-format) ─────────────────────────────────────────────────
  final Map<ReportFormat, String> _reports = {};
  List<String> _savedPaths = const [];
  ReportFormat _format = ReportFormat.markdown;
  bool _rawReport = false;

  final ScrollController _logScroll = ScrollController();

  // ── Filtering / sorting ────────────────────────────────────────────────────

  List<Source> get _filteredByCriterias {
    var list = _allSources;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((s) =>
              (s.name ?? '').toLowerCase().contains(q) ||
              (s.lang ?? '').toLowerCase().contains(q) ||
              (s.baseUrl ?? '').toLowerCase().contains(q))
          .toList();
    }
    if (_filterLangCode != null) {
      list = list
          .where((s) => s.lang?.toLowerCase() == _filterLangCode)
          .toList();
    }
    if (_filterType != null) {
      list = list.where((s) => s.sourceCodeLanguage == _filterType).toList();
    }
    if (_filterNsfw != null) {
      list = list.where((s) => (s.isNsfw ?? false) == _filterNsfw).toList();
    }
    return list;
  }

  List<Source> get _visibleSources {
    var list = _filteredByCriterias;
    switch (_statusFilter) {
      case _StatusFilter.all:
        break;
      case _StatusFilter.ok:
        list = list.where((s) => _resultMap[s.id!]?.allOk == true).toList();
        break;
      case _StatusFilter.failed:
        list = list.where((s) => _resultMap[s.id!]?.anyFailed == true).toList();
        break;
      case _StatusFilter.running:
        list = list
            .where((s) =>
                (_statusMap[s.id] ?? ExtStatus.idle) == ExtStatus.running)
            .toList();
        break;
      case _StatusFilter.idle:
        list = list
            .where((s) =>
                _statusMap[s.id] == null || _statusMap[s.id] == ExtStatus.idle)
            .toList();
        break;
    }
    if (_onlyErrors) {
      list = list.where((s) => _resultMap[s.id!]?.anyFailed == true).toList();
    }
    if (_onlyTested) {
      list = list.where((s) => _resultMap.containsKey(s.id)).toList();
    }

    int statusPriority(Source s) {
      switch (_statusOf(s)) {
        case ExtStatus.running:
          return 0;
        case ExtStatus.failed:
          return 1;
        case ExtStatus.skipped:
          return 2;
        case ExtStatus.done:
          return 3;
        case ExtStatus.idle:
          return 4;
      }
    }

    switch (_sortMode) {
      case _SortMode.name:
        list.sort((a, b) => (a.name ?? '')
            .toLowerCase()
            .compareTo((b.name ?? '').toLowerCase()));
        break;
      case _SortMode.status:
        list.sort((a, b) {
          final c = statusPriority(a).compareTo(statusPriority(b));
          return c != 0
              ? c
              : (a.name ?? '')
                  .toLowerCase()
                  .compareTo((b.name ?? '').toLowerCase());
        });
        break;
      case _SortMode.duration:
        list.sort((a, b) {
          final ra = _resultMap[a.id];
          final rb = _resultMap[b.id];
          if (ra == null && rb == null) {
            return (a.name ?? '').compareTo(b.name ?? '');
          }
          if (ra == null) return 1;
          if (rb == null) return -1;
          final c = rb.totalMs.compareTo(ra.totalMs);
          return c != 0
              ? c
              : (a.name ?? '')
                  .toLowerCase()
                  .compareTo((b.name ?? '').toLowerCase());
        });
        break;
    }
    return list;
  }

  List<String> get _availableLangCodes => _allSources
      .map((s) => s.lang?.toLowerCase() ?? '')
      .where((l) => l.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<Source> get _runSources =>
      _filteredByCriterias.where((s) => _scopeIds.contains(s.id)).toList();

  int get _selectedScopeCountOfAll() =>
      _allSources.where((s) => _scopeIds.contains(s.id)).length;

  int get _okCount => _resultMap.values.where((r) => r.allOk).length;
  int get _failCount => _resultMap.values.where((r) => r.anyFailed).length;
  double get _progress => _total == 0 ? 0 : _done / _total;
  bool get _isComplete =>
      _started &&
      !_running &&
      !_cancelling &&
      _total > 0 &&
      (_controls?.isCancelled ?? false) == false;
  bool get _isInterrupted =>
      _started && _total > 0 && (_controls?.isCancelled ?? false);

  String get _scopeLabel {
    if (_filterLangCode != null) {
      return 'Langue: ${completeLanguageName(_filterLangCode!)}';
    }
    if (_filterType != null) return 'Type: ${_filterType!.name}';
    if (_filterNsfw == true) return 'NSFW seulement';
    if (_filterNsfw == false) return 'SFW seulement';
    return 'Toutes les extensions';
  }

  ExtDiagResult? get _selectedResult =>
      _selectedSource != null ? _resultMap[_selectedSource!.id] : null;

  String get _typeLabel => switch (widget.itemType) {
        ItemType.anime => 'Anime',
        ItemType.manga => 'Manga',
        ItemType.novel => 'Novel',
        _ => widget.itemType.name,
      };

  String get _title => 'Diagnostic $_typeLabel';

  // ── Status helpers ─────────────────────────────────────────────────────────

  ExtStatus _statusOf(Source s) => _statusMap[s.id] ?? ExtStatus.idle;

  bool _inCurrentRun(Source s) =>
      _started && _runSnapshot.any((r) => r.id == s.id);

  ExtStatus _displayStatus(Source s) {
    final st = _statusOf(s);
    if (st == ExtStatus.idle &&
        _isInterrupted &&
        _inCurrentRun(s) &&
        _resultMap[s.id!] == null) {
      return ExtStatus.skipped;
    }
    return st;
  }

  String _fmtDuration(int ms) {
    if (ms <= 0) return '';
    if (ms < 1000) return '${ms}ms';
    final s = ms ~/ 1000;
    if (s < 60) return '${s}.${((ms % 1000) ~/ 100)}s';
    return '${s ~/ 60}m${(s % 60).toString().padLeft(2, "0")}s';
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  @override
  void dispose() {
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
    setState(() {
      _allSources = sources;
      for (final s in sources) {
        if (s.id != null) _scopeIds.add(s.id!);
      }
    });
  }

  // ── Navigation / selection ─────────────────────────────────────────────────

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/browse');
    }
  }

  void _switchView(_DiagView v) {
    setState(() {
      _view = v;
      if (v == _DiagView.diag) _detailVisible = _selectedSource != null;
    });
  }

  void _selectSource(Source s) {
    setState(() {
      _selectedSource = s;
      _detailVisible = true;
      _view = _DiagView.diag;
    });
  }

  void _toggleScope(int id) {
    setState(() {
      if (!_scopeIds.remove(id)) _scopeIds.add(id);
    });
  }

  void _setAllScope(bool selected) {
    setState(() {
      if (selected) {
        for (final s in _allSources) {
          if (s.id != null) _scopeIds.add(s.id!);
        }
      } else {
        _scopeIds.clear();
      }
    });
  }

  void _togglePanel() => setState(() => _panelOpen = !_panelOpen);

  // ── Run control ────────────────────────────────────────────────────────────

  Future<void> _startDiagnostics() async {
    final sources = _runSources;
    if (sources.isEmpty) {
      _showSnack(_allSources.isNotEmpty
          ? 'Aucune extension sélectionnée — activez-en au moins une.'
          : 'Aucune extension pour ce filtre.');
      return;
    }
    if (_running) return;

    final controls = DiagRunControls();

    setState(() {
      _running = true;
      _paused = false;
      _cancelling = false;
      _started = true;
      _done = 0;
      _total = sources.length;
      _runSnapshot = List.of(sources);
      _statusMap.clear();
      _resultMap.clear();
      _reports.clear();
      _savedPaths = const [];
      _format = ReportFormat.markdown;
      _rawReport = false;
      _controls = controls;
      for (final s in sources) {
        if (s.id != null) _statusMap[s.id!] = ExtStatus.idle;
      }
      _startTime = DateTime.now();
      _elapsedLabel = '0s';
    });

    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_running) return;
      final el = DateTime.now().difference(_startTime!);
      setState(() => _elapsedLabel = _fmtDuration(el.inMilliseconds));
    });

    unawaited(DiagNotificationService.instance.showProgress(
      done: 0,
      total: sources.length,
      title: 'Diagnostic $_typeLabel en cours…',
      force: true,
    ));

    await runDiagnosticsForSources(
      sources,
      widget.itemType,
      concurrency: 6,
      controls: controls,
      onResult: (result) {
        if (!mounted || result.source.id == null) return;
        final status = result.cancelled
            ? ExtStatus.skipped
            : result.allOk
                ? ExtStatus.done
                : ExtStatus.failed;
        setState(() {
          _resultMap[result.source.id!] = result;
          _statusMap[result.source.id!] = status;
          _done++;
        });
        DiagNotificationService.instance
            .showProgress(
              done: _done,
              total: _total,
              title: 'Diagnostic $_typeLabel',
              body: '$_done / $_total — ${result.source.name}',
            )
            .ignore();
      },
      onLog: _appendRunLog,
    );

    _elapsedTimer?.cancel();

    if (controls.isCancelled) {
      await DiagNotificationService.instance.dismiss();
      await DiagNotificationService.instance
          .showInterrupted(done: _done, total: _total);
      if (mounted) {
        setState(() {
          _running = false;
          _paused = false;
          _cancelling = false;
        });
        _showSnack('Diagnostic annulé — $_done / $_total analysée(s).');
      }
      return;
    }

    // Completed run → build + save every export format.
    final ok = _okCount;
    final failed = _failCount;
    final resultsList = _resultMap.values.toList();
    final ms = resultsList.fold<int>(0, (a, r) => a + r.totalMs);

    String? md;
    String? json;
    String? txt;
    String? csv;
    List<String> saved = const [];
    try {
      md = generateMarkdownReport(
        results: resultsList,
        itemType: widget.itemType,
        scopeLabel: _scopeLabel,
      );
      json = generateJsonReport(
        results: resultsList,
        itemType: widget.itemType,
        scopeLabel: _scopeLabel,
      );
      txt = generateTextReport(
        results: resultsList,
        itemType: widget.itemType,
        scopeLabel: _scopeLabel,
      );
      csv = generateCsvReport(
        results: resultsList,
        itemType: widget.itemType,
        scopeLabel: _scopeLabel,
      );
      saved = await saveDiagnosticReports(
        results: resultsList,
        itemType: widget.itemType,
        scopeLabel: _scopeLabel,
      );
    } catch (_) {}

    await DiagNotificationService.instance.dismiss();
    if (md != null) {
      await DiagNotificationService.instance.showSummary(
        ok: ok,
        failed: failed,
        total: resultsList.length,
        ms: ms,
      );
    }

    if (mounted) {
      setState(() {
        _running = false;
        _paused = false;
        _cancelling = false;
        if (md != null) _reports[ReportFormat.markdown] = md;
        if (json != null) _reports[ReportFormat.json] = json;
        if (txt != null) _reports[ReportFormat.text] = txt;
        if (csv != null) _reports[ReportFormat.csv] = csv;
        _savedPaths = saved;
      });
      _showSnack('Diagnostic terminé — $ok OK · $failed échec(s).');
    }
  }

  void _togglePause() {
    final c = _controls;
    if (c == null) return;
    setState(() {
      _paused = !_paused;
      if (_paused) {
        c.pause();
      } else {
        c.resume();
      }
    });
  }

  void _cancelDiagnostics() {
    final c = _controls;
    if (c == null) return;
    setState(() => _cancelling = true);
    c.cancel();
    _showSnack('Annulation du diagnostic…');
  }

  /// Retries a single extension (manual retry or post-Cloudflare).
  Future<void> _retrySource(Source s) async {
    if (_running || s.id == null) return;
    setState(() => _statusMap[s.id!] = ExtStatus.running);
    final result = await diagnoseSource(
      s,
      widget.itemType,
      onLog: _appendRunLog,
    );
    if (!mounted) return;
    setState(() {
      if (result != null) {
        _resultMap[s.id!] = result;
        _statusMap[s.id!] = result.cancelled
            ? ExtStatus.skipped
            : result.allOk
                ? ExtStatus.done
                : ExtStatus.failed;
      } else {
        _statusMap[s.id!] = ExtStatus.failed;
      }
    });
    if (result == null) {
      _showSnack('Retest annulé pour ${s.name}.');
    } else if (result.allOk) {
      _showSnack('✅ ${s.name} répond correctement maintenant.');
    } else {
      _showSnack('❌ ${s.name} échoue toujours — voir les logs de l’étape.');
    }
  }

  void _appendRunLog(String line) {
    if (!mounted) return;
    for (final s in _runSnapshot) {
      if (line.contains('"${s.name}"') && line.contains('[RUN]')) {
        if (s.id != null && _statusMap[s.id] != ExtStatus.running) {
          _statusMap[s.id!] = ExtStatus.running;
        }
      }
    }
    setState(() {
      _logLines.add(line);
      if (_logLines.length > 2000) {
        _logLines.removeRange(0, _logLines.length - 1500);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients && _logScroll.position.maxScrollExtent > 0) {
        _logScroll.animateTo(
          _logScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _resetDiagnostics() {
    if (_running) return;
    setState(() {
      _started = false;
      _done = 0;
      _total = 0;
      _runSnapshot = [];
      _logLines.clear();
      _resultMap.clear();
      _statusMap.clear();
      _savedPaths = const [];
      _reports.clear();
      _selectedSource = null;
      _detailVisible = false;
      _controls = null;
    });
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _filterLangCode = null;
      _filterType = null;
      _filterNsfw = null;
      _statusFilter = _StatusFilter.all;
      _sortMode = _SortMode.name;
      _onlyErrors = false;
      _onlyTested = false;
    });
  }

  // ── Misc helpers ───────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _copyActiveReport() async {
    final content = _reports[_format];
    if (content == null) {
      _showSnack('Aucun rapport disponible — lancez un diagnostic.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: content));
    _showSnack('Rapport ${_formatLabel(_format)} copié ✓');
  }

  String _formatLabel(ReportFormat f) => switch (f) {
        ReportFormat.markdown => 'Markdown',
        ReportFormat.json => 'JSON',
        ReportFormat.text => 'TXT',
        ReportFormat.csv => 'CSV',
      };

  String _statusFilterLabel(_StatusFilter f) => switch (f) {
        _StatusFilter.all => 'Toutes',
        _StatusFilter.ok => 'OK',
        _StatusFilter.failed => 'Erreurs',
        _StatusFilter.running => 'En cours',
        _StatusFilter.idle => 'En attente',
      };

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _wide = constraints.maxWidth >= 860;
            return Column(
              children: [
                _buildTopBar(cs),
                _NavBar(
                  view: _view,
                  panelOpen: _panelOpen,
                  diagCount: _visibleSources.length,
                  extCount: _allSources.length,
                  resCount: _resultMap.length,
                  cs: cs,
                  onPanel: _togglePanel,
                  onView: _switchView,
                ),
                const Divider(height: 1),
                Expanded(
                  child:
                      _wide ? _buildWideContent(cs) : _buildNarrowContent(cs),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Toolbar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(ColorScheme cs) {
    final canReset = !_running && _started;
    final showStart = _allSources.isNotEmpty && !_running;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: cs.surface),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
          onPressed: _handleBack,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: -0.2),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _running
                    ? (_paused
                        ? 'En pause — $_done / $_total'
                        : 'En cours — $_done / $_total')
                    : _isInterrupted
                        ? 'Interrompu — $_done / $_total'
                        : _isComplete
                            ? 'Terminé · $_okCount OK · $_failCount erreur(s)'
                            : '${_allSources.length} extensions · ${_selectedScopeCountOfAll()} sélectionnées',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (_running)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _paused
                ? Icon(Icons.pause_circle_outline_rounded,
                    size: 18, color: Colors.amber.shade700)
                : SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.primary)),
          ),
        PopupMenuButton<_ToolAction>(
          tooltip: 'Actions',
          icon: const Icon(Icons.more_vert_rounded, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onSelected: _onToolAction,
          itemBuilder: (_) => [
            if (showStart && !_started)
              const PopupMenuItem(
                  value: _ToolAction.start,
                  child: _MenuTile('Lancer le diagnostic', Icons.play_arrow_rounded)),
            if (_running) ...[
              PopupMenuItem(
                  value: _ToolAction.pause,
                  child: _MenuTile(
                      _paused ? 'Reprendre' : 'Mettre en pause',
                      _paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded)),
              const PopupMenuItem(
                  value: _ToolAction.cancel,
                  child:
                      _MenuTile('Annuler / interrompre', Icons.stop_circle_outlined)),
            ],
            if (canReset)
              const PopupMenuItem(
                  value: _ToolAction.reset,
                  child: _MenuTile('Réinitialiser', Icons.restart_alt_rounded)),
            if (showStart && _started)
              PopupMenuItem(
                  value: _ToolAction.relaunch,
                  child: _MenuTile('Relancer le diagnostic', Icons.replay_rounded)),
            if (_reports.isNotEmpty) ...[
              const PopupMenuDivider(),
              PopupMenuItem(
                  value: _ToolAction.copy,
                  child: _MenuTile(
                      'Copier le rapport ${_formatLabel(_format)}', Icons.copy_rounded)),
            ],
          ],
        ),
      ]),
    );
  }

  void _onToolAction(_ToolAction a) {
    switch (a) {
      case _ToolAction.start:
        unawaited(_startDiagnostics());
        break;
      case _ToolAction.relaunch:
        unawaited(_startDiagnostics());
        break;
      case _ToolAction.pause:
        _togglePause();
        break;
      case _ToolAction.cancel:
        _cancelDiagnostics();
        break;
      case _ToolAction.reset:
        _resetDiagnostics();
        break;
      case _ToolAction.copy:
        unawaited(_copyActiveReport());
        break;
    }
  }

  // ── Layouts ────────────────────────────────────────────────────────────────

  Widget _buildWideContent(ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_panelOpen) ...[SizedBox(width: 292, child: _PanelView(cs)),
          VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),
        ],
        Expanded(child: _pageContent(cs)),
      ],
    );
  }

  Widget _buildNarrowContent(ColorScheme cs) {
    return Stack(
      children: [
        Positioned.fill(child: _pageContent(cs)),
        // Scrim
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_panelOpen,
            child: AnimatedOpacity(
              opacity: _panelOpen ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: GestureDetector(
                onTap: () => setState(() => _panelOpen = false),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
          ),
        ),
        // Bottom control sheet
        Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            ignoring: !_panelOpen,
            child: AnimatedSlide(
              offset: _panelOpen ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _panelOpen ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: _narrowPanel(cs),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _narrowPanel(ColorScheme cs) {
    final insets = MediaQuery.of(context).viewInsets;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      clipBehavior: Clip.antiAlias,
      elevation: 12,
      shadowColor: Colors.black45,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(child: _PanelView(cs)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageContent(ColorScheme cs) {
    final child = switch (_view) {
      _DiagView.diag => _diagPage(cs),
      _DiagView.extensions => _extensionsPage(cs),
      _DiagView.results => _resultsPage(cs),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(_view), child: child),
    );
  }

  // ── Diagnostic page ────────────────────────────────────────────────────────

  Widget _diagPage(ColorScheme cs) {
    final hasDetail = _selectedSource != null && _detailVisible;
    final statusCard = _allSources.isNotEmpty
        ? _StatusCard(
            key: const ValueKey('status-card'),
            running: _running,
            paused: _paused,
            cancelling: _cancelling,
            started: _started,
            interrupted: _isInterrupted,
            complete: _isComplete,
            done: _done,
            total: _total,
            okCount: _okCount,
            failCount: _failCount,
            progress: _progress,
            elapsedLabel: _elapsedLabel,
            cs: cs,
            onStart: _running || _runSources.isEmpty
                ? null
                : _startDiagnostics,
            onPause: _running ? _togglePause : null,
            onCancel: _running ? _cancelDiagnostics : null,
          )
        : const SizedBox.shrink();

    if (_wide && _allSources.isNotEmpty) {
      // Master-detail: list + workspace side by side.
      return Column(children: [
        statusCard,
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 316, child: _buildSourceList(cs, forDiagnostic: true)),
              VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),
              Expanded(
                child: hasDetail
                    ? _detailPane(cs, showBack: false)
                    : _detailEmpty(cs),
              ),
            ],
          ),
        ),
      ]);
    }

    return Column(children: [
      statusCard,
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: hasDetail
              ? KeyedSubtree(
                  key: ValueKey('detail-${_selectedSource!.id}'),
                  child: _detailPane(cs, showBack: true))
              : KeyedSubtree(
                  key: const ValueKey('list'),
                  child: _buildSourceList(cs, forDiagnostic: true)),
        ),
      ),
    ]);
  }

  // ── Extensions page ────────────────────────────────────────────────────────

  Widget _extensionsPage(ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _StatusLegend(
        tested: _resultMap.length,
        ok: _okCount,
        fail: _failCount,
        scopeSelected: _selectedScopeCountOfAll(),
        cs: cs,
      ),
      Expanded(child: _buildSourceList(cs, forDiagnostic: false)),
    ]);
  }

  // ── Shared source list ────────────────────────────────────────────────────

  Widget _buildSourceList(ColorScheme cs, {required bool forDiagnostic}) {
    final list = _visibleSources;
    final showScope = !forDiagnostic;

    if (_allSources.isEmpty) {
      return EmptyHero(
        icon: Icons.extension_off_outlined,
        title: 'Aucune extension installée',
        subtitle:
            'Ajoutez des extensions depuis le Marketplace avant de lancer un diagnostic.',
        actionLabel: 'Retour',
        onAction: _handleBack,
        cs: cs,
      );
    }
    if (list.isEmpty) {
      return EmptyHero(
        icon: Icons.filter_alt_off_outlined,
        title: forDiagnostic
            ? 'Aucune extension pour ces filtres'
            : 'Aucun résultat',
        subtitle: 'Modifiez la recherche ou les filtres depuis le panneau Panel.',
        actionLabel: 'Ouvrir le Panel',
        onAction: () => setState(() => _panelOpen = true),
        cs: cs,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final s = list[i];
        final status = _displayStatus(s);
        final selected = _selectedSource?.id == s.id;
        final scopeSelected = _scopeIds.contains(s.id);
        final r = _resultMap[s.id];

        String? subtitle;
        if (r != null) {
          final dur = _fmtDuration(r.totalMs);
          subtitle = r.cancelled
              ? 'Interrompu'
              : '${r.okCount}/${r.steps.length} étapes OK'
                  '${r.failCount > 0 ? ' · ${r.failCount} erreur(s)' : ''}'
                  '${dur.isNotEmpty ? ' · $dur' : ''}';
        } else if (_running && _inCurrentRun(s)) {
          subtitle = status == ExtStatus.running
              ? 'Analyse en cours…'
              : 'En attente…';
        } else {
          final parts = <String>[];
          if (s.sourceCodeLanguage != null) {
            parts.add(s.sourceCodeLanguage!.name);
          }
          if (s.isNsfw == true) parts.add('NSFW');
          if (s.hasCloudflare == true) parts.add('Cloudflare');
          subtitle = parts.join(' · ');
        }

        return SourceRow(
          source: s,
          status: status,
          selected: selected,
          dimmed: !scopeSelected && showScope,
          subtitle: subtitle,
          cs: cs,
          trailing: _rowTrailing(s, showScope, scopeSelected, cs),
          onTap: showScope
              ? () => _toggleScope(s.id!)
              : () => _selectSource(s),
          onOpenDetail: showScope && !_running
              ? () => _selectSource(s)
              : null,
        );
      },
    );
  }

  Widget _rowTrailing(
      Source s, bool showScope, bool scopeSelected, ColorScheme cs) {
    final r = _resultMap[s.id];
    final dur = r != null ? _fmtDuration(r.totalMs) : '';

    if (showScope) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        if (dur.isNotEmpty)
          Text(dur,
              style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
        const SizedBox(width: 6),
        MiniCheck(checked: scopeSelected, cs: cs),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (dur.isNotEmpty)
        Text(
          dur,
          style: TextStyle(
              fontSize: 10.5,
              color: cs.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      const SizedBox(width: 8),
      StatusDot(status: _displayStatus(s), cs: cs, size: 9),
    ]);
  }

  // ── Detail pane ────────────────────────────────────────────────────────────

  Widget _detailPane(ColorScheme cs, {required bool showBack}) {
    final s = _selectedSource;
    if (s == null) return _detailEmpty(cs);

    return Column(children: [
      if (showBack)
        DetailBar(
          source: s,
          cs: cs,
          onBack: () => setState(() => _detailVisible = false),
        ),
      Expanded(
        child: ExtensionDetail(
          key: ValueKey('ext-detail-${s.id}'),
          source: s,
          result: _selectedResult,
          status: _displayStatus(s),
          running: _running,
          itemType: widget.itemType,
          cs: cs,
          onRetry: _running ? null : () => _retrySource(s),
          onResolveCloudflare: _running ? null : () => _retrySource(s),
        ),
      ),
    ]);
  }

  Widget _detailEmpty(ColorScheme cs) {
    return EmptyHero(
      icon: Icons.touch_app_outlined,
      title: 'Aucune extension sélectionnée',
      subtitle:
          'Touchez une extension dans la liste pour afficher ses étapes, logs et erreurs détaillées.',
      actionLabel: 'Voir les extensions',
      onAction: () => _switchView(_DiagView.extensions),
      cs: cs,
    );
  }

  // ── Results page ───────────────────────────────────────────────────────────

  Widget _resultsPage(ColorScheme cs) {
    if (_resultMap.isEmpty) {
      return EmptyHero(
        icon: Icons.assessment_outlined,
        title: _started ? 'Pas encore de résultats' : 'Aucun rapport',
        subtitle: _started
            ? 'Les extensions analysées apparaîtront ici avec leurs étapes et logs.'
            : 'Lancez un diagnostic pour obtenir un rapport détaillé exportable (Markdown, JSON, TXT, CSV).',
        actionLabel: _started ? null : 'Lancer le diagnostic',
        onAction: _started ? null : () => unawaited(_startDiagnostics()),
        cs: cs,
      );
    }

    final results = _resultMap.values.toList();
    final sorted = [
      ...results.where((r) => r.anyFailed),
      ...results.where((r) => r.allOk),
    ];

    return Column(children: [
      ExportBar(
        formats: ReportFormat.values,
        active: _format,
        rawReport: _rawReport,
        canCopy: _reports.isNotEmpty,
        savedCount: _savedPaths.length,
        cs: cs,
        onFormat: (f) => setState(() {
          _format = f;
          _rawReport = false;
        }),
        onToggleRaw: () => setState(() => _rawReport = !_rawReport),
        onCopy: _copyActiveReport,
      ),
      Expanded(
        child: _rawReport && _reports[_format] != null
            ? RawReportView(
                content: _reports[_format]!,
                format: _formatLabel(_format),
                cs: cs,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final r = sorted[i];
                  return ResultCard(
                    result: r,
                    itemType: widget.itemType,
                    cs: cs,
                    onOpen: () => _selectSource(r.source),
                  );
                },
              ),
      ),
    ]);
  }

  // ── Panel content (shared narrow bottom sheet / wide side panel) ──────────

  Widget _PanelView(ColorScheme cs) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          border: Border(
              bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5))),
        ),
        child: Row(children: [
          Icon(Icons.tune_rounded, size: 17, color: cs.primary),
          const SizedBox(width: 8),
          const Text('Panel de contrôle',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _panelOpen = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _panelSectionTitle(cs, 'Recherche'),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Rechercher une extension…',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => setState(() => _search = ''),
                      ),
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _panelSectionTitle(cs, 'Statut'),
            _statusChips(cs),
            const SizedBox(height: 14),
            _panelSectionTitle(cs, 'Trier'),
            _sortChips(cs),
            const SizedBox(height: 14),
            if (_availableLangCodes.isNotEmpty) ...[_panelSectionTitle(cs, 'Langue'),
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    MiniChip(
                        label: 'Toutes',
                        selected: _filterLangCode == null,
                        cs: cs,
                        onTap: () => setState(() => _filterLangCode = null)),
                    ..._availableLangCodes.map((l) => MiniChip(
                          label: l.toUpperCase(),
                          selected: _filterLangCode == l,
                          cs: cs,
                          onTap: () => setState(() => _filterLangCode =
                              _filterLangCode == l ? null : l),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            _panelSectionTitle(cs, 'Type'),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                MiniChip(
                    label: 'Tout',
                    selected: _filterType == null,
                    cs: cs,
                    onTap: () => setState(() => _filterType = null)),
                for (final t in SourceCodeLanguage.values)
                  MiniChip(
                      label: t.name,
                      selected: _filterType == t,
                      cs: cs,
                      onTap: () => setState(
                          () => _filterType = _filterType == t ? null : t)),
              ],
            ),
            const SizedBox(height: 14),
            _panelSectionTitle(cs, 'Contenu'),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                MiniChip(
                    label: 'Tout',
                    selected: _filterNsfw == null,
                    cs: cs,
                    onTap: () => setState(() => _filterNsfw = null)),
                MiniChip(
                    label: 'SFW',
                    selected: _filterNsfw == false,
                    cs: cs,
                    onTap: () => setState(
                        () => _filterNsfw = _filterNsfw == false ? null : false)),
                MiniChip(
                    label: 'NSFW',
                    selected: _filterNsfw == true,
                    cs: cs,
                    danger: true,
                    onTap: () => setState(
                        () => _filterNsfw = _filterNsfw == true ? null : true)),
              ],
            ),
            const SizedBox(height: 14),
            _panelSectionTitle(cs, 'Options'),
            SwitchListTile.adaptive(
              value: _onlyErrors,
              onChanged: (v) => setState(() => _onlyErrors = v),
              title: const Text('Afficher uniquement les erreurs',
                  style: TextStyle(fontSize: 12.5)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            SwitchListTile.adaptive(
              value: _onlyTested,
              onChanged: (v) => setState(() => _onlyTested = v),
              title: const Text('Afficher uniquement les extensions testées',
                  style: TextStyle(fontSize: 12.5)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 4),
            Text(
              '${_selectedScopeCountOfAll()} / ${_allSources.length} extensions sélectionnées pour le diagnostic',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            _panelSectionTitle(cs, 'Actions'),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _running ? null : () => _setAllScope(true),
                  icon: const Icon(Icons.done_all_rounded, size: 15),
                  label: const Text('Tout sélectionner',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _running ? null : () => _setAllScope(false),
                  icon: const Icon(Icons.deselect_rounded, size: 15),
                  label: const Text('Tout désélectionner',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _running ? null : _startDiagnostics,
              icon: Icon(
                  _isComplete
                      ? Icons.replay_rounded
                      : Icons.play_arrow_rounded,
                  size: 17),
              label: Text(
                  _isComplete
                      ? 'Relancer le diagnostic'
                      : 'Lancer le diagnostic',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
            ),
            if (_running) ...[const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _togglePause,
                    icon: Icon(
                        _paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: 16),
                    label: Text(_paused ? 'Reprendre' : 'Pause',
                        style: const TextStyle(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelling ? null : _cancelDiagnostics,
                    icon: const Icon(Icons.stop_rounded, size: 16),
                    label: Text(_cancelling ? 'Annulation…' : 'Annuler',
                        style: const TextStyle(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        visualDensity: VisualDensity.compact),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _running ? null : _resetFilters,
              icon: const Icon(Icons.restart_alt_rounded, size: 15),
              label: const Text('Réinitialiser les filtres'),
              style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  visualDensity: VisualDensity.compact),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _panelSectionTitle(ColorScheme cs, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: cs.onSurfaceVariant)),
      );

  Widget _statusChips(ColorScheme cs) {
    final counts = <_StatusFilter, int>{
      _StatusFilter.all: _allSources.length,
      _StatusFilter.ok: _okCount,
      _StatusFilter.failed: _failCount,
      _StatusFilter.running:
          _statusMap.values.where((s) => s == ExtStatus.running).length,
      _StatusFilter.idle: _allSources
          .where((s) =>
              _statusMap[s.id] == null || _statusMap[s.id] == ExtStatus.idle)
          .length,
    };
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final f in _StatusFilter.values)
          MiniChip(
            label:
                '${_statusFilterLabel(f)}${counts[f]! > 0 ? ' (${counts[f]})' : ''}',
            selected: _statusFilter == f && !_onlyErrors,
            cs: cs,
            danger: f == _StatusFilter.failed,
            onTap: () => setState(() {
              _statusFilter = f;
              _onlyErrors = false;
            }),
          ),
      ],
    );
  }

  Widget _sortChips(ColorScheme cs) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final m in _SortMode.values)
          MiniChip(
            label: switch (m) {
              _SortMode.name => 'Nom',
              _SortMode.status => 'Statut',
              _SortMode.duration => 'Durée',
            },
            selected: _sortMode == m,
            cs: cs,
            onTap: () => setState(() => _sortMode = m),
          ),
      ],
    );
  }

}

enum _ToolAction { start, pause, cancel, reset, copy, relaunch }

// ─── Page navigation bar ─────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final _DiagView view;
  final bool panelOpen;
  final int diagCount;
  final int extCount;
  final int resCount;
  final ColorScheme cs;
  final VoidCallback onPanel;
  final ValueChanged<_DiagView> onView;

  const _NavBar({
    required this.view,
    required this.panelOpen,
    required this.diagCount,
    required this.extCount,
    required this.resCount,
    required this.cs,
    required this.onPanel,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
            bottom:
                BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        // Panel opener — controls only, never a page.
        _NavPill(
          icon: Icons.tune_rounded,
          label: 'Panel',
          active: panelOpen,
          cs: cs,
          onTap: onPanel,
        ),
        const SizedBox(width: 8),
        Container(
            width: 1,
            height: 18,
            color: cs.outlineVariant.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(children: [
              _NavPill(
                icon: Icons.science_outlined,
                label: 'Diagnostic',
                count: diagCount,
                active: view == _DiagView.diag,
                cs: cs,
                onTap: () => onView(_DiagView.diag),
              ),
              const SizedBox(width: 6),
              _NavPill(
                icon: Icons.extension_outlined,
                label: 'Extensions',
                count: extCount,
                active: view == _DiagView.extensions,
                cs: cs,
                onTap: () => onView(_DiagView.extensions),
              ),
              const SizedBox(width: 6),
              _NavPill(
                icon: Icons.assessment_outlined,
                label: 'Résultats',
                count: resCount,
                active: view == _DiagView.results,
                cs: cs,
                onTap: () => onView(_DiagView.results),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _NavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;
  final bool active;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.cs,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? cs.primaryContainer : cs.surfaceContainerHigh;
    final fg = active ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: fg)),
            if (count != null && count! > 0) ...[const SizedBox(width: 5),
              Text('$count',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? cs.onPrimaryContainer.withValues(alpha: 0.75)
                          : cs.onSurfaceVariant.withValues(alpha: 0.75))),
            ],
          ]),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MenuTile(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 17),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 13)),
    ]);
  }
}

// ─── Run status card (compact dashboard) ─────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final bool running;
  final bool paused;
  final bool cancelling;
  final bool started;
  final bool interrupted;
  final bool complete;
  final int done;
  final int total;
  final int okCount;
  final int failCount;
  final double progress;
  final String elapsedLabel;
  final ColorScheme cs;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onCancel;

  const _StatusCard({
    super.key,
    required this.running,
    required this.paused,
    required this.cancelling,
    required this.started,
    required this.interrupted,
    required this.complete,
    required this.done,
    required this.total,
    required this.okCount,
    required this.failCount,
    required this.progress,
    required this.elapsedLabel,
    required this.cs,
    required this.onStart,
    required this.onPause,
    required this.onCancel,
  });

  String get _stateLabel {
    if (!started) return 'Prêt à diagnostiquer';
    if (cancelling) return 'Annulation…';
    if (paused) return 'En pause';
    if (running) return 'Diagnostic en cours';
    if (interrupted) return 'Interrompu';
    if (complete) {
      return failCount == 0 ? 'Diagnostic terminé' : 'Terminé avec erreurs';
    }
    return 'Prêt';
  }

  int get _pct => total == 0 ? 0 : (progress * 100).round();

  @override
  Widget build(BuildContext context) {
    final showProgress = started && total > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _statusOrb(cs),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(_stateLabel,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (showProgress) ...[const SizedBox(width: 8),
                    Text('$_pct%',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: running ? cs.primary : cs.onSurfaceVariant,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                  ],
                ]),
                if (showProgress) ...[const SizedBox(height: 2),
                  Text(
                    '$done / $total extensions analysées · $elapsedLabel',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ] else
                  Text(
                    'Lancez l’analyse pour tester chaque étape (Popular · Latest · Détail · Médias).',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ]),
        // Thin rounded animated progress bar
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: showProgress
              ? Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => LinearProgressIndicator(
                        value: v,
                        minHeight: 3,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(paused
                            ? Colors.amber.shade600
                            : cancelling || interrupted
                                ? cs.error
                                : complete && failCount == 0
                                    ? Colors.green.shade500
                                    : cs.primary),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (started && total > 0) ...[const SizedBox(height: 9),
          Row(children: [
            _StatPill(
                icon: Icons.check_rounded,
                value: okCount,
                color: Colors.green.shade600,
                cs: cs),
            const SizedBox(width: 6),
            _StatPill(
                icon: Icons.close_rounded,
                value: failCount,
                color: cs.error,
                cs: cs),
            const Spacer(),
            if (complete && okCount == total)
              Text('Toutes les sources répondent ✓',
                  style:
                      TextStyle(fontSize: 10.5, color: Colors.green.shade700))
            else if (interrupted)
              Text('${total - done} non analysée(s)',
                  style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant))
            else
              Text('${(done - okCount - failCount).clamp(0, 999)} restantes',
                  style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
          ]),
        ],
        // Run / pause / cancel / relaunch
        if (!started || complete || running || interrupted) ...[const SizedBox(height: 10),
          if (running)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPause,
                  icon: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 16),
                  label: Text(paused ? 'Reprendre' : 'Pause',
                      style: const TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cancelling ? null : onCancel,
                  icon: const Icon(Icons.stop_rounded, size: 16),
                  label: Text(cancelling ? 'Annulation…' : 'Annuler',
                      style: const TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      visualDensity: VisualDensity.compact),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: Text(interrupted ? 'Relancer' : 'Relancer',
                      style: const TextStyle(fontSize: 12.5)),
                  style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ),
            ])
          else
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded, size: 17),
              label: Text(
                  started ? 'Relancer le diagnostic' : 'Lancer le diagnostic',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(38),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
            ),
        ],
      ]),
    );
  }

  Widget _statusOrb(ColorScheme cs) {
    final (icon, color, spin) = (!started)
        ? (Icons.science_outlined, cs.onSurfaceVariant, false)
        : cancelling
            ? (Icons.stop_circle_outlined, cs.error, false)
            : paused
                ? (Icons.pause_circle_outline_rounded, Colors.amber.shade700, false)
                : running
                    ? (Icons.radar_rounded, cs.primary, true)
                    : interrupted
                        ? (Icons.error_outline_rounded, cs.error, false)
                        : complete && failCount == 0
                            ? (Icons.check_circle_rounded, Colors.green.shade600, false)
                            : (Icons.warning_amber_rounded, cs.error, false);

    Widget inner = Icon(icon, size: 20, color: color);
    if (spin) {
      inner = SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: color));
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: Center(child: inner),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  final ColorScheme cs;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text('$value',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

// ─── Status legend (extensions page) ─────────────────────────────────────────

class _StatusLegend extends StatelessWidget {
  final int tested;
  final int ok;
  final int fail;
  final int scopeSelected;
  final ColorScheme cs;

  const _StatusLegend({
    required this.tested,
    required this.ok,
    required this.fail,
    required this.scopeSelected,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
            bottom:
                BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            'Cochez les extensions à tester · $scopeSelected sélectionnées',
            style: const TextStyle(fontSize: 11.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _DotLegend(label: 'OK', color: Colors.green.shade500, value: ok, cs: cs),
        const SizedBox(width: 8),
        _DotLegend(label: 'Err.', color: cs.error, value: fail, cs: cs),
        const SizedBox(width: 8),
        _DotLegend(
            label: 'Testées', color: cs.onSurfaceVariant, value: tested, cs: cs),
      ]),
    );
  }
}

class _DotLegend extends StatelessWidget {
  final String label;
  final Color color;
  final int value;
  final ColorScheme cs;

  const _DotLegend({
    required this.label,
    required this.color,
    required this.value,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 3),
      Text('$value',
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant)),
    ]);
  }
}

// __PART_F_END__
