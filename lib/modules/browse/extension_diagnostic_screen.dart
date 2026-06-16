import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
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
    if (!Platform.isAndroid && !Platform.isIOS) {
      _initialized = true;
      return;
    }
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
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(const AndroidNotificationChannel(
          _kChannelId,
          _kChannelName,
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
    required int done,
    required int total,
    required String title,
    String? body,
  }) async {
    await _init();
    if (!_initialized || kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final android = AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: 'Progression du diagnostic',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: total,
        progress: done,
        ongoing: done < total,
        autoCancel: done >= total,
        icon: '@mipmap/launcher_icon',
      );
      await _plugin.show(
        _kNotifId,
        title,
        body ?? '$done / $total extensions testées',
        NotificationDetails(android: android),
      );
    } catch (_) {}
  }

  static Future<void> dismiss() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _plugin.cancel(_kNotifId);
    } catch (_) {}
  }
}

// ─── Scope models ─────────────────────────────────────────────────────────────

enum _ScopeType { all, byLanguage, single }

// ─── Screen phases ────────────────────────────────────────────────────────────

enum _ScreenPhase { selectScope, running, done }

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
  _ScreenPhase _phase = _ScreenPhase.selectScope;

  // Scope selection
  _ScopeType _scopeType = _ScopeType.all;
  String? _selectedLang;
  Source? _selectedSource;

  // Extension filters
  SourceCodeLanguage? _compatFilter;
  bool? _nsfwFilter;

  // Running / done
  final List<String> _logLines = [];
  final List<ExtDiagResult> _results = [];
  int _total = 0;
  int _done = 0;
  String? _savedPath;

  final ScrollController _logScroll = ScrollController();

  @override
  void dispose() {
    _logScroll.dispose();
    super.dispose();
  }

  // ── Source helpers ─────────────────────────────────────────────────────────

  List<Source> _allSources() {
    var list = isar.sources
        .filter()
        .idIsNotNull()
        .and()
        .isAddedEqualTo(true)
        .and()
        .itemTypeEqualTo(widget.itemType)
        .findAllSync()
        .where((s) => !(s.name == 'local' && (s.lang?.isEmpty ?? true)))
        .toList();
    if (_compatFilter != null) {
      list = list.where((s) => s.sourceCodeLanguage == _compatFilter).toList();
    }
    if (_nsfwFilter != null) {
      list = list.where((s) => (s.isNsfw ?? false) == _nsfwFilter).toList();
    }
    return list;
  }

  List<String> _availableLangs() {
    final langs = _allSources()
        .map((s) => s.lang?.toLowerCase() ?? '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return langs;
  }

  List<Source> _scopedSources() {
    final all = _allSources();
    return switch (_scopeType) {
      _ScopeType.all => all,
      _ScopeType.byLanguage => all
          .where((s) =>
              s.lang?.toLowerCase() == (_selectedLang ?? '').toLowerCase())
          .toList(),
      _ScopeType.single =>
        _selectedSource != null ? [_selectedSource!] : [],
    };
  }

  String get _scopeLabel => switch (_scopeType) {
        _ScopeType.all => 'Toutes les extensions',
        _ScopeType.byLanguage =>
          'Langue : ${completeLanguageName(_selectedLang ?? "")}',
        _ScopeType.single =>
          _selectedSource?.name ?? 'Extension unique',
      };

  bool get _canStart {
    if (_scopeType == _ScopeType.all) return true;
    if (_scopeType == _ScopeType.byLanguage) {
      return _selectedLang != null && _selectedLang!.isNotEmpty;
    }
    return _selectedSource != null;
  }

  // ── Start diagnostics ──────────────────────────────────────────────────────

  Future<void> _startDiagnostics() async {
    final sources = _scopedSources();
    if (sources.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Aucune extension installée pour ce scope.'),
        ));
      }
      return;
    }

    setState(() {
      _phase = _ScreenPhase.running;
      _logLines.clear();
      _results.clear();
      _total = sources.length;
      _done = 0;
      _savedPath = null;
    });

    await _DiagNotifService.showProgress(
      done: 0,
      total: sources.length,
      title: 'Diagnostic ${_typeLabelShort()} en cours…',
    );

    // Pool of 4 — QuickJS+ supports multiple concurrent JS contexts
    await runDiagnosticsForSources(
      sources,
      widget.itemType,
      concurrency: 4,
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _results.add(result);
          _done++;
        });
        _DiagNotifService.showProgress(
          done: _done,
          total: _total,
          title: 'Diagnostic ${_typeLabelShort()}',
          body: '$_done / $_total — ${result.source.name}',
        );
      },
      onLog: (line) {
        if (!mounted) return;
        setState(() => _logLines.add(line));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScroll.hasClients &&
              _logScroll.position.maxScrollExtent > 0) {
            _logScroll.animateTo(
              _logScroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      },
    );

    final savedPath = await saveDiagnosticReport(
      results: _results,
      itemType: widget.itemType,
      scopeLabel: _scopeLabel,
    );

    final ok = _results.where((r) => r.allOk).length;
    final failed = _results.length - ok;

    await _DiagNotifService.dismiss();
    await _DiagNotifService.showProgress(
      done: _results.length,
      total: _results.length,
      title: 'Diagnostic terminé',
      body: '$ok OK · $failed échec(s) sur ${_results.length}',
    );

    if (mounted) {
      setState(() {
        _phase = _ScreenPhase.done;
        _savedPath = savedPath;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(switch (_phase) {
          _ScreenPhase.selectScope =>
            'Diagnostic — ${_typeLabelShort()}',
          _ScreenPhase.running => 'Diagnostic en cours…',
          _ScreenPhase.done => 'Diagnostic terminé',
        }),
        actions: [
          if (_phase == _ScreenPhase.done)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Nouveau diagnostic',
              onPressed: () => setState(() {
                _phase = _ScreenPhase.selectScope;
                _logLines.clear();
                _results.clear();
              }),
            ),
        ],
      ),
      body: switch (_phase) {
        _ScreenPhase.selectScope => _buildScopeSelector(),
        _ScreenPhase.running => _buildRunningView(),
        _ScreenPhase.done => _buildDoneView(),
      },
    );
  }

  String _typeLabelShort() => switch (widget.itemType) {
        ItemType.anime => 'Anime',
        ItemType.manga => 'Manga',
        ItemType.novel => 'Novel',
        _ => widget.itemType.name,
      };

  // ── Phase 1 : Scope selector ───────────────────────────────────────────────

  Widget _buildScopeSelector() {
    final cs = Theme.of(context).colorScheme;
    final allSources = _allSources();
    final langs = _availableLangs();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Périmètre du diagnostic',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${allSources.length} extension(s) installées · ${langs.length} langue(s)',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 22),

          _ScopeCard(
            selected: _scopeType == _ScopeType.all,
            icon: Icons.all_inclusive_rounded,
            title: 'Toutes les extensions',
            subtitle:
                '${allSources.length} extensions · parallèle (pool=4)',
            onTap: () => setState(() => _scopeType = _ScopeType.all),
          ),
          const SizedBox(height: 10),

          _ScopeCard(
            selected: _scopeType == _ScopeType.byLanguage,
            icon: Icons.language_rounded,
            title: 'Par langue',
            subtitle: 'Tester toutes les extensions d\'une langue',
            onTap: () => setState(() => _scopeType = _ScopeType.byLanguage),
          ),
          if (_scopeType == _ScopeType.byLanguage && langs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: DropdownButtonFormField<String>(
                value: _selectedLang,
                hint: const Text('Sélectionner une langue'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: langs.map((l) {
                  final count = allSources
                      .where((s) => s.lang?.toLowerCase() == l)
                      .length;
                  return DropdownMenuItem(
                    value: l,
                    child: Text('${completeLanguageName(l)} ($count)'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedLang = v),
              ),
            ),
          const SizedBox(height: 10),

          _ScopeCard(
            selected: _scopeType == _ScopeType.single,
            icon: Icons.extension_rounded,
            title: 'Une seule extension',
            subtitle: 'Tester une extension spécifique',
            onTap: () => setState(() => _scopeType = _ScopeType.single),
          ),
          if (_scopeType == _ScopeType.single && allSources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: DropdownButtonFormField<Source>(
                value: _selectedSource,
                hint: const Text('Sélectionner une extension'),
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: allSources
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            '${s.name ?? "?"} [${(s.lang ?? "?").toUpperCase()}]',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSource = v),
              ),
            ),

          const SizedBox(height: 22),

          Text(
            'Type de source',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              (null, Icons.apps_rounded, 'Toutes'),
              (SourceCodeLanguage.dart, Icons.flutter_dash, 'Dart / Natif'),
              (SourceCodeLanguage.javascript, Icons.code_rounded, 'JS'),
              (SourceCodeLanguage.mihon, Icons.android_rounded, 'Mihon/Aniyomi'),
              (SourceCodeLanguage.lnreader, Icons.menu_book_outlined, 'LNReader'),
            ].map<Widget>(((SourceCodeLanguage?, IconData, String) item) {
              final (lang, icon, label) = item;
              final sel = _compatFilter == lang;
              final cs = Theme.of(context).colorScheme;
              return GestureDetector(
                onTap: () => setState(() => _compatFilter = lang),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? cs.primaryContainer : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? cs.primary : cs.outlineVariant,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 13, color: sel ? cs.primary : cs.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(label, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? cs.primary : cs.onSurface)),
                  ]),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),

          Text(
            'Tags',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              (null, Icons.all_inclusive_rounded, 'Tout contenu'),
              (false, Icons.child_care_rounded, 'Sans NSFW'),
              (true, Icons.eighteen_up_rating_rounded, 'NSFW seulement'),
            ].map<Widget>(((bool?, IconData, String) item) {
              final (val, icon, label) = item;
              final sel = _nsfwFilter == val;
              final cs = Theme.of(context).colorScheme;
              return GestureDetector(
                onTap: () => setState(() => _nsfwFilter = val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? cs.primaryContainer : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? cs.primary : cs.outlineVariant,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 13, color: sel ? cs.primary : cs.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text(label, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? cs.primary : cs.onSurface)),
                  ]),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Lancer le diagnostic',
                  style: TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _canStart ? _startDiagnostics : null,
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 2 : Running ──────────────────────────────────────────────────────

  Widget _buildRunningView() {
    final cs = Theme.of(context).colorScheme;
    final progress = _total == 0 ? 0.0 : _done / _total;
    // Estimate how many are currently active (running concurrently)
    final activeCount = (_total - _done).clamp(0, 4);

    return Column(
      children: [
        _ProgressHeader(
          done: _done,
          total: _total,
          progress: progress,
          running: true,
          activeCount: activeCount,
          cs: cs,
        ),
        Expanded(
          child: _LogView(lines: _logLines, controller: _logScroll, cs: cs),
        ),
      ],
    );
  }

  // ── Phase 3 : Done ─────────────────────────────────────────────────────────

  Widget _buildDoneView() {
    final cs = Theme.of(context).colorScheme;
    final ok = _results.where((r) => r.allOk).length;
    final failed = _results.length - ok;

    return Column(
      children: [
        _DoneHeader(
          ok: ok,
          failed: failed,
          total: _results.length,
          savedPath: _savedPath,
          cs: cs,
          reportContent: generateMarkdownReport(
            results: _results,
            itemType: widget.itemType,
            scopeLabel: _scopeLabel,
          ),
        ),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: const [
                    Tab(icon: Icon(Icons.terminal_rounded, size: 16), text: 'Log'),
                    Tab(
                        icon: Icon(Icons.summarize_rounded, size: 16),
                        text: 'Résultats'),
                  ],
                  labelColor: cs.primary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  indicatorColor: cs.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _LogView(
                          lines: _logLines,
                          controller: ScrollController(),
                          cs: cs),
                      _ResultsList(
                          results: _results, itemType: widget.itemType, cs: cs),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Scope option card ────────────────────────────────────────────────────────

class _ScopeCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ScopeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer.withOpacity(0.4)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 20,
                  color: selected ? cs.primary : cs.onSurfaceVariant),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? cs.primary : cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Progress header ──────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final int done;
  final int total;
  final double progress;
  final bool running;
  final int activeCount;
  final ColorScheme cs;

  const _ProgressHeader({
    required this.done,
    required this.total,
    required this.progress,
    required this.running,
    required this.cs,
    this.activeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (running)
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary)),
            if (running) const SizedBox(width: 10),
            Expanded(
              child: Text(
                running
                    ? 'En cours… $done / $total'
                    : 'Terminé',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
            if (running && activeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeCount actif${activeCount > 1 ? "s" : ""} · pool=4',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: cs.primary),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Popular · Latest · Détail · Médias — 4 étapes par extension',
            style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─── Done header ─────────────────────────────────────────────────────────────

class _DoneHeader extends StatelessWidget {
  final int ok;
  final int failed;
  final int total;
  final String? savedPath;
  final String? reportContent;
  final ColorScheme cs;

  const _DoneHeader({
    required this.ok,
    required this.failed,
    required this.total,
    required this.savedPath,
    required this.cs,
    this.reportContent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: failed > 0
            ? cs.errorContainer.withOpacity(0.25)
            : Colors.green.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              failed > 0
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: failed > 0 ? cs.error : Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                failed > 0
                    ? '$failed échec(s) · $ok OK sur $total'
                    : 'Tout OK — $total extensions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: failed > 0 ? cs.error : Colors.green.shade700,
                ),
              ),
            ),
            if (reportContent != null)
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copier le rapport',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: cs.onSurfaceVariant,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: reportContent!));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Rapport copié dans le presse-papiers'),
                      duration: Duration(seconds: 2),
                    ));
                  }
                },
              ),
          ]),
          if (savedPath != null) ...[
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.save_outlined, size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Rapport : ${savedPath!.split('/').last}',
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─── Log view ─────────────────────────────────────────────────────────────────

class _LogView extends StatelessWidget {
  final List<String> lines;
  final ScrollController controller;
  final ColorScheme cs;

  const _LogView(
      {required this.lines, required this.controller, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerLowest,
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        itemCount: lines.length,
        itemBuilder: (_, i) => _LogLine(line: lines[i], cs: cs),
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final String line;
  final ColorScheme cs;
  const _LogLine({required this.line, required this.cs});

  // New log format uses tree chars + ✓/✗ + step codes
  (Color?, bool) _classify() {
    // Error / fail indicators
    if (line.contains('✗') || line.contains('FAIL')) {
      return (cs.error, true);
    }
    // Success
    if (line.contains('✅') || line.contains('✓')) {
      return (Colors.green.shade600, true);
    }
    // Start / done markers
    if (line.contains('START') || line.contains('DONE')) {
      return (cs.primary, true);
    }
    // Skip / ignored
    if (line.contains('⤼') || line.contains('skipped')) {
      return (cs.onSurfaceVariant.withOpacity(0.5), false);
    }
    // RUN marker
    if (line.contains('[RUN]')) {
      return (cs.primary, true);
    }
    // URL / HTTP lines
    if (line.contains(' URL ') || line.contains(' HTTP ')) {
      return (cs.primary.withOpacity(0.65), false);
    }
    return (null, false);
  }

  @override
  Widget build(BuildContext context) {
    if (line.isEmpty) return const SizedBox(height: 4);
    final (color, bold) = _classify();

    // Tree chars get dimmed prefix treatment
    final isTreeChar = line.trimLeft().startsWith('├') ||
        line.trimLeft().startsWith('│') ||
        line.trimLeft().startsWith('└');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        line,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.35,
          color: color ??
              (isTreeChar
                  ? cs.onSurfaceVariant.withOpacity(0.75)
                  : cs.onSurfaceVariant),
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

// ─── Results list ─────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  final List<ExtDiagResult> results;
  final ItemType itemType;
  final ColorScheme cs;

  const _ResultsList(
      {required this.results, required this.itemType, required this.cs});

  @override
  Widget build(BuildContext context) {
    final sorted = [
      ...results.where((r) => r.anyFailed),
      ...results.where((r) => r.allOk),
    ];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: sorted.length,
      itemBuilder: (_, i) =>
          _ExtDiagCard(result: sorted[i], cs: cs, itemType: itemType),
    );
  }
}

// ─── Per-extension card ───────────────────────────────────────────────────────

class _ExtDiagCard extends StatefulWidget {
  final ExtDiagResult result;
  final ColorScheme cs;
  final ItemType itemType;

  const _ExtDiagCard(
      {required this.result, required this.cs, required this.itemType});

  @override
  State<_ExtDiagCard> createState() => _ExtDiagCardState();
}

class _ExtDiagCardState extends State<_ExtDiagCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.result.anyFailed;
  }

  String _fmtMs(int ms) {
    if (ms == 0) return '—';
    if (ms < 1000) return '${ms}ms';
    final s = ms ~/ 1000;
    final rem = (ms % 1000) ~/ 100;
    return s < 60 ? '${s}.${rem}s' : '${s ~/ 60}m${(s % 60).toString().padLeft(2, "0")}s';
  }

  @override
  Widget build(BuildContext context) {
    final src = widget.result.source;
    final allOk = widget.result.allOk;
    final cs = widget.cs;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: allOk
              ? Colors.green.withOpacity(0.35)
              : cs.error.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  allOk
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  color: allOk ? Colors.green : cs.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                if ((src.iconUrl ?? '').isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.network(
                      src.iconUrl!,
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Text(
                    src.name ?? 'Unknown',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
                // Language badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (src.lang ?? '?').toUpperCase(),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                // Total time badge
                if (widget.result.totalMs > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _fmtMs(widget.result.totalMs),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ]),
              if (_expanded) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: DiagStep.values
                      .map((step) => _StepChip(
                            step: step,
                            result: widget.result.steps[step],
                            cs: cs,
                            itemType: widget.itemType,
                          ))
                      .toList(),
                ),
                ...widget.result.steps.entries
                    .where((e) => !e.value.ok && e.value.error != null)
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 13,
                                  color: cs.error.withOpacity(0.8)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '[${_stepLabel(e.key)}] ${e.value.error}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: cs.onSurfaceVariant,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _stepLabel(DiagStep step) => switch (step) {
        DiagStep.popular => 'Popular',
        DiagStep.latest => 'Latest',
        DiagStep.detail => 'Détail',
        DiagStep.media =>
          widget.itemType == ItemType.anime ? 'Vidéos' : 'Pages',
      };
}

// ─── Step chip ────────────────────────────────────────────────────────────────

class _StepChip extends StatelessWidget {
  final DiagStep step;
  final DiagStepResult? result;
  final ColorScheme cs;
  final ItemType itemType;

  const _StepChip({
    required this.step,
    required this.result,
    required this.cs,
    required this.itemType,
  });

  IconData get _stepIcon => switch (step) {
        DiagStep.popular => Icons.list_rounded,
        DiagStep.latest  => Icons.update_rounded,
        DiagStep.detail  => Icons.info_outline_rounded,
        DiagStep.media   => itemType == ItemType.anime
            ? Icons.play_circle_outline_rounded
            : Icons.description_rounded,
      };

  String get _stepName => switch (step) {
        DiagStep.popular => 'Popular',
        DiagStep.latest  => 'Latest',
        DiagStep.detail  => 'Détail',
        DiagStep.media   => itemType == ItemType.anime ? 'Vidéos' : 'Pages',
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
      return _chip(null, '…', cs.surfaceContainerHighest, cs.onSurfaceVariant);
    }
    final ok = result!.ok;
    final bg = ok
        ? Colors.green.withOpacity(0.12)
        : cs.errorContainer.withOpacity(0.5);
    final fg = ok ? Colors.green.shade700 : cs.onErrorContainer;
    final count = result!.count != null ? ' ${result!.count}' : '';
    final label = '$_stepName$count · ${_fmtMs(result!.ms)}';
    return _chip(ok ? Icons.check_rounded : Icons.close_rounded, label, bg, fg);
  }

  Widget _chip(IconData? statusIcon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_stepIcon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
          if (statusIcon != null) ...[
            const SizedBox(width: 3),
            Icon(statusIcon, size: 11, color: fg),
          ],
        ],
      ),
    );
  }
}
