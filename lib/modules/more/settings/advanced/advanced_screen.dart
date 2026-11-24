import 'dart:io'
    if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/log/logger.dart';
import 'package:watchtower/modules/more/about/providers/logs_state.dart';
import 'package:watchtower/modules/library/services/library_maintenance.dart';
import 'package:watchtower/modules/more/settings/advanced/providers/ui_scale_provider.dart';
import 'package:watchtower/modules/more/settings/general/providers/general_state_provider.dart';
import 'package:watchtower/modules/more/settings/widgets/settings_subpage_scaffold.dart';
import 'package:watchtower/providers/storage_provider.dart';
import 'package:watchtower/services/cache_storage_manager.dart';
import 'package:watchtower/services/device_capabilities.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/services/anti_bot/remote_bypass_service.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/services/silent_installer_service.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/core/icon_fonts/broken_icons.dart';

// ─── Hive-backed Advanced Settings helpers ────────────────────────────────────

const _kBoxName = 'advanced_settings';
const _kShareCrashKey = 'share_crash_reports';
const _kDetailedReportsKey = 'detailed_reports';
const _kOldDecoderKey = 'old_decoder';
const _kNonAsciiKey = 'no_non_ascii';
const _kBitmapThresholdKey = 'bitmap_threshold';

Future<Box> _openBox() => Hive.openBox(_kBoxName);

Future<bool> _getBool(String key, {bool defaultValue = false}) async {
  final box = await _openBox();
  return box.get(key, defaultValue: defaultValue) as bool;
}

Future<void> _setBool(String key, bool value) async {
  final box = await _openBox();
  await box.put(key, value);
}

Future<int> _getInt(String key, {int defaultValue = 0}) async {
  final box = await _openBox();
  return box.get(key, defaultValue: defaultValue) as int;
}

Future<void> _setInt(String key, int value) async {
  final box = await _openBox();
  await box.put(key, value);
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class AdvancedScreen extends ConsumerStatefulWidget {
  const AdvancedScreen({super.key});

  @override
  ConsumerState<AdvancedScreen> createState() => _AdvancedScreenState();
}

class _AdvancedScreenState extends ConsumerState<AdvancedScreen> {
  bool _shareCrash = false;
  bool _detailedReports = false;
  bool _oldDecoder = false;
  bool _noNonAscii = false;
  int _bitmapThreshold = 4096;
  double _uiScale = 1.0;

  // ── Icon cache ───────────────────────────────────────────────────────────────
  String _iconCacheSizeStr = '…';
  String _libCacheSizeStr = '…';

  // ── Global cache ceiling ─────────────────────────────────────────────────────
  int _cacheLimitBytes = CacheStorageManager.defaultLimitForTier(
    DeviceCapabilities.ramTier,
  );
  String _totalCacheSizeStr = '…';

  // ── Remote bypass (FlareSolverr) ────────────────────────────────────────────
  RemoteBypassSettings _remoteBypass = const RemoteBypassSettings();
  final _rbUrlCtrl = TextEditingController();
  final _rbKeyCtrl = TextEditingController();
  final _rbTimeoutCtrl = TextEditingController();

  // ── Log settings ────────────────────────────────────────────────────────────
  int _logMode = 1; // 0=normal,1=verbose,2=debug,3=extreme
  bool _logSuppressImages = true;
  bool _logTagExt = true;
  bool _logTagDl = true;
  bool _logTagNet = true;
  bool _logTagUi = true;
  bool _logTagManga = false;
  bool _logTagPage = false;
  bool _logTagHls = false;
  bool _logTagInstall = true;
  bool _logTagReader = false;
  bool _logTagWatch = true;
  bool _logTagMaint = true;
  bool _logTagImg = true;

  bool _loading = true;
  SilentInstallStatus _silentStatus = SilentInstallStatus.unknown;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadRemoteBypass();
    _loadCacheSizes();
    _loadSilentInstallStatus();
  }

  Future<void> _loadSilentInstallStatus() async {
    final s = await SilentInstallerService.instance.checkStatus();
    if (mounted) setState(() => _silentStatus = s);
  }

  @override
  void dispose() {
    _rbUrlCtrl.dispose();
    _rbKeyCtrl.dispose();
    _rbTimeoutCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRemoteBypass() async {
    final s = await RemoteBypassService.instance.loadSettings();
    if (!mounted) return;
    setState(() {
      _remoteBypass = s;
      _rbUrlCtrl.text = s.url;
      _rbKeyCtrl.text = s.apiKey;
      _rbTimeoutCtrl.text = s.timeoutMs.toString();
    });
  }

  Future<void> _saveRemoteBypass() async {
    await RemoteBypassService.instance.saveSettings(_remoteBypass);
  }

  Future<void> _showRemoteBypassDialog() async {
    _rbUrlCtrl.text = _remoteBypass.url;
    _rbKeyCtrl.text = _remoteBypass.apiKey;
    _rbTimeoutCtrl.text = _remoteBypass.timeoutMs.toString();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          title: Text(context.l10n.settings_remote_bypass_title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.settings_remote_bypass_help,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rbUrlCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.settings_remote_server_url,
                    hintText: 'http://localhost:8191',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rbKeyCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.settings_remote_api_key,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rbTimeoutCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.settings_remote_timeout,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.settings_remote_trigger_mode,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...RemoteBypassMode.values.map(
                  (m) => RadioGroup<RemoteBypassMode>(
                    groupValue: _remoteBypass.mode,
                    onChanged: (v) {
                      setInner(() {});
                      setState(() {
                        _remoteBypass = _remoteBypass.copyWith(mode: v!);
                      });
                    },
                    child: RadioListTile<RemoteBypassMode>(
                      dense: true,
                      title: Text(
                        m == RemoteBypassMode.auto
                            ? context.l10n.settings_remote_mode_auto
                            : context.l10n.settings_remote_mode_on_demand,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        m == RemoteBypassMode.auto
                            ? context.l10n.settings_remote_mode_auto_desc
                            : context.l10n
                                .settings_remote_mode_on_demand_desc,
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: m,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final url = _rbUrlCtrl.text.trim();
                final key = _rbKeyCtrl.text.trim();
                final timeout =
                    int.tryParse(_rbTimeoutCtrl.text.trim()) ?? 60000;
                setState(() {
                  _remoteBypass = _remoteBypass.copyWith(
                    url: url,
                    apiKey: key,
                    timeoutMs: timeout,
                  );
                });
                await _saveRemoteBypass();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(context.l10n.settings_save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPrefs() async {
    final results = await Future.wait([
      _getBool(_kShareCrashKey),
      _getBool(_kDetailedReportsKey),
      _getBool(_kOldDecoderKey),
      _getBool(_kNonAsciiKey),
      _getInt(_kBitmapThresholdKey, defaultValue: 4096),
      // Log settings
      _getInt(kLogMode, defaultValue: LogMode.verbose.index),
      _getInt(kLogMinLevel, defaultValue: 0),
      _getBool(kLogSuppressImages, defaultValue: true),
      _getBool(kLogTagExt, defaultValue: true),
      _getBool(kLogTagDl, defaultValue: true),
      _getBool(kLogTagNet, defaultValue: true),
      _getBool(kLogTagUi, defaultValue: true),
      _getBool(kLogTagManga, defaultValue: true),
      _getBool(kLogTagPage, defaultValue: false),
      _getBool(kLogTagHls, defaultValue: true),
      _getBool(kLogTagInstall, defaultValue: true),
      _getBool(kLogTagReader, defaultValue: false),
      _getBool(kLogTagWatch, defaultValue: true),
      _getBool(kLogTagMaint, defaultValue: true),
      _getBool(kLogTagImg, defaultValue: true),
    ]);
    if (mounted) {
      setState(() {
        _shareCrash = results[0] as bool;
        _detailedReports = results[1] as bool;
        _oldDecoder = results[2] as bool;
        _noNonAscii = results[3] as bool;
        _bitmapThreshold = results[4] as int;
        _logMode = results[5] as int;
        _logSuppressImages = results[7] as bool;
        _logTagExt = results[8] as bool;
        _logTagDl = results[9] as bool;
        _logTagNet = results[10] as bool;
        _logTagUi = results[11] as bool;
        _logTagManga = results[12] as bool;
        _logTagPage = results[13] as bool;
        _logTagHls = results[14] as bool;
        _logTagInstall = results[15] as bool;
        _logTagReader = results[16] as bool;
        _logTagWatch = results[17] as bool;
        _logTagMaint = results[18] as bool;
        _logTagImg = results[19] as bool;
        _loading = false;
      });
      // Load UI scale separately
      final advBox = await _openBox();
      final loadedScale =
          (advBox.get(kUiScaleKey, defaultValue: 1.0) as num).toDouble();
      if (mounted) setState(() => _uiScale = loadedScale);
    }
  }

  Future<void> _saveLogSetting(String key, dynamic value) async {
    final box = await Hive.openBox('advanced_settings');
    await box.put(key, value);
    await AppLogger.reloadSettings();
  }

  Future<void> _applyMode(LogMode mode) async {
    final l10n = context.l10n;
    final tags = mode.defaultTags;
    setState(() {
      _logMode = mode.index;
      _logTagExt = tags[kLogTagExt]!;
      _logTagDl = tags[kLogTagDl]!;
      _logTagNet = tags[kLogTagNet]!;
      _logTagUi = tags[kLogTagUi]!;
      _logTagManga = tags[kLogTagManga]!;
      _logTagPage = tags[kLogTagPage]!;
      _logTagHls = tags[kLogTagHls]!;
      _logTagInstall = tags[kLogTagInstall]!;
      _logTagReader = tags[kLogTagReader]!;
      _logTagWatch = tags[kLogTagWatch]!;
      _logTagMaint = tags[kLogTagMaint]!;
      _logTagImg = tags[kLogTagImg]!;
    });
    final box = await Hive.openBox('advanced_settings');
    await box.put(kLogMode, mode.index);
    await box.put(kLogMinLevel, mode.minLevel);
    for (final e in tags.entries) {
      await box.put(e.key, e.value);
    }
    await AppLogger.reloadSettings();
    if (mode.isHeavy) {
      botToast(
        mode == LogMode.extreme
            ? l10n.settings_extreme_warning
            : l10n.settings_debug_warning,
        second: 5,
      );
    }
  }

  void _toast(String msg) => botToast(msg);

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _clearCookies() async {
    final l10n = context.l10n;
    AppLogger.log(
      'MAINT clearCookies: début',
      tag: LogTag.maintenance,
      logLevel: LogLevel.info,
    );
    try {
      await CookieManager.instance().deleteAllCookies();
      MClient.deleteAllCookies("");
      AppLogger.log(
        'MAINT clearCookies: ok',
        tag: LogTag.maintenance,
        logLevel: LogLevel.info,
      );
      _toast(l10n.settings_cookies_cleared);
    } catch (e, st) {
      AppLogger.log(
        'MAINT clearCookies: ÉCHEC $e',
        tag: LogTag.maintenance,
        logLevel: LogLevel.error,
        error: e,
        stackTrace: st,
      );
      _toast(l10n.settings_cookies_clear_failed);
    }
  }

  Future<void> _clearWebViewData() async {
    final l10n = context.l10n;
    AppLogger.log(
      'MAINT clearWebViewData: début',
      tag: LogTag.maintenance,
      logLevel: LogLevel.info,
    );
    try {
      final mgr = CookieManager.instance();
      await mgr.deleteAllCookies();
      if (!kIsWeb && Platform.isAndroid) {
        await InAppWebViewController.clearAllCache();
      }
      AppLogger.log(
        'MAINT clearWebViewData: ok',
        tag: LogTag.maintenance,
        logLevel: LogLevel.info,
      );
      _toast(l10n.settings_webview_data_cleared);
    } catch (e, st) {
      AppLogger.log(
        'MAINT clearWebViewData: ÉCHEC $e',
        tag: LogTag.maintenance,
        logLevel: LogLevel.error,
        error: e,
        stackTrace: st,
      );
      _toast(l10n.settings_webview_clear_failed);
    }
  }

  Future<void> _clearDatabase() async {
    final l10n = context.l10n;
    try {
      final nonFavIds =
          (await isar.mangas
                  .filter()
                  .favoriteIsNull()
                  .or()
                  .favoriteEqualTo(false)
                  .idProperty()
                  .findAll())
              .whereType<int>()
              .toList();
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.settings_clear_database),
          content: Text(
            context.l10n
                .settings_clear_database_body('${nonFavIds.length}'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                context.l10n.settings_clear,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await isar.writeTxn(() async => isar.mangas.deleteAll(nonFavIds));
        _toast(l10n.settings_db_cleared('${nonFavIds.length}'));
      }
    } catch (e) {
      _toast(l10n.settings_error);
    }
  }

  // ── Download reindex ─────────────────────────────────────────────────────────

  /// Scans every Download record in Isar. For any entry that is NOT yet marked
  /// complete, checks whether the actual file already exists on disk — this
  /// can happen after a crash, a migration, or a manual file copy.  Marks
  /// found files as [isDownload = true] so the UI correctly shows them.
  Future<void> _reindexDownloads() async {
    _toast(context.l10n.settings_reindexing);
    try {
      final result = await reindexDownloads();
      if (!mounted) return;
      _toast(
        context.l10n.settings_reindex_done('${result.fixed}', '${result.total}'),
      );
    } catch (e) {
      if (!mounted) return;
      _toast(context.l10n.settings_error);
    }
  }

  /// Adds to the library every fully-downloaded chapter whose parent manga,
  /// anime or novel is not a favourite yet, plus the archives the sister
  /// download extension left in the download folder.
  Future<void> _addDownloadsToLibrary() async {
    _toast(context.l10n.settings_checking);
    try {
      final added = await addDownloadedToLibrary();
      if (!mounted) return;
      _toast(context.l10n.settings_added_to_library('$added'));
    } catch (e) {
      if (!mounted) return;
      _toast(context.l10n.settings_error);
    }
  }

  // ── Icon / Library cache helpers ─────────────────────────────────────────────

  static String _fmtSize(BuildContext context, int bytes) {
    final l10n = context.l10n;
    if (bytes < 1024) return l10n.settings_bytes_o('$bytes');
    if (bytes < 1024 * 1024) {
      return l10n.settings_bytes_ko((bytes / 1024).toStringAsFixed(1));
    }
    if (bytes < 1024 * 1024 * 1024) {
      return l10n.settings_bytes_mo((bytes / (1024 * 1024)).toStringAsFixed(1));
    }
    return l10n.settings_bytes_go((bytes / (1024 * 1024 * 1024)).toStringAsFixed(2));
  }

  Future<void> _loadCacheSizes() async {
    final storage = StorageProvider();
    final manager = CacheStorageManager.instance;
    final iconSize =
        await manager.directorySize(
          await storage.getPersistentCacheDirectory('cacheimagecover'),
        ) +
        await manager.directorySize(
          await storage.getCacheDirectory('cacheimagecover'),
        );
    final libSize = await manager.directorySize(
      await storage.getCacheDirectory('cacheimagemanga'),
    );
    final limit = await manager.getLimitBytes();
    final total = await manager.totalSizeBytes();
    if (!mounted) return;
    setState(() {
      _iconCacheSizeStr = _fmtSize(context, iconSize);
      _libCacheSizeStr = _fmtSize(context, libSize);
      _cacheLimitBytes = limit;
      _totalCacheSizeStr = _fmtSize(context, total);
    });
  }

  Future<void> _clearIconCache() async {
    final l10n = context.l10n;
    try {
      await CacheStorageManager.instance.clearLocations(const [
        CacheStorageManager.coverLabel,
        CacheStorageManager.legacyCoverLabel,
      ]);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      _toast(l10n.settings_icon_cache_cleared);
    } catch (e) {
      _toast(l10n.settings_error);
    } finally {
      await _loadCacheSizes();
    }
  }

  Future<void> _clearLibraryCache() async {
    final l10n = context.l10n;
    try {
      await CacheStorageManager.instance.clearLocations(const [
        CacheStorageManager.libraryCoverLabel,
      ]);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      _toast(l10n.settings_cover_cache_cleared);
    } catch (e) {
      _toast(l10n.settings_error);
    } finally {
      await _loadCacheSizes();
    }
  }

  Future<void> _clearAllImageCaches() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.l10n.settings_clear_image_caches_title),
        content: Text(context.l10n.settings_clear_image_caches_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.settings_empty),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await CacheStorageManager.instance.clearAll();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      _toast(l10n.settings_all_caches_cleared);
    } catch (e) {
      _toast(l10n.settings_error);
    } finally {
      await _loadCacheSizes();
    }
  }

  Future<void> _resetUserAgent() async {
    try {
      final settings = (isar.settings.getSync(kSettingsId) ?? Settings());
      isar.writeTxnSync(
        () => isar.settings.putSync(
          settings
            ..userAgent = defaultUserAgent
            ..updatedAt = DateTime.now().millisecondsSinceEpoch,
        ),
      );
      ref.invalidate(userAgentStateProvider);
      _toast(context.l10n.settings_user_agent_reset);
    } catch (_) {
      _toast(context.l10n.settings_user_agent_reset_failed);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openBatterySettings() async {
    final l10n = context.l10n;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await launchUrl(
          Uri.parse('android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        _toast(l10n.settings_battery_settings_failed);
      }
    }
  }

  Future<void> _openNotificationSettings() async {
    final l10n = context.l10n;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await launchUrl(
          Uri.parse('android.settings.APP_NOTIFICATION_SETTINGS'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        _toast(l10n.settings_notifications_hint_android);
      }
    } else {
      _toast(l10n.settings_notifications_hint_ios);
    }
  }

  // ── Widgets helpers ─────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _toggle({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
    bool danger = false,
    bool disabled = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final activeColor = danger ? Colors.orange : primary;
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: disabled ? context.secondaryColor : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: context.secondaryColor),
      ),
      value: value,
      onChanged: disabled ? null : onChanged,
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
        }
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.selected)) {
          return activeColor;
        }
        return null;
      }),
    );
  }

  Widget _action({
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    IconData? trailing,
  }) {
    return ListTile(
      title: Text(title, style: TextStyle(fontSize: 14, color: titleColor)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: context.secondaryColor),
            )
          : null,
      trailing: trailing != null
          ? Icon(trailing, size: 18, color: context.secondaryColor)
          : null,
      onTap: onTap,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      // Not `const`: SettingsSubpageScaffold's assert reads slivers.length,
      // which is not allowed inside a constant expression.
      return SettingsSubpageScaffold(
        title: context.l10n.settings_advanced,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return SettingsSubpageScaffold(
      title: context.l10n.settings_advanced,
      body: ListView(
        children: [
          // ── Section : Installation automatique ─────────────────────────
          if (!kIsWeb && Platform.isAndroid) ...[
            _sectionHeader(context.l10n.settings_auto_install),
            _SilentInstallTile(
              status: _silentStatus,
              onChanged: (success) {
                if (success) {
                  setState(() => _silentStatus = SilentInstallStatus.active);
                } else {
                  _loadSilentInstallStatus();
                }
              },
            ),
          ],
          // ── Section : Avancé ────────────────────────────────────────────
          _sectionHeader(context.l10n.settings_advanced),
          _toggle(
            title: context.l10n.settings_share_crash_reports,
            subtitle: context.l10n.settings_share_crash_reports_desc,
            value: _shareCrash,
            onChanged: (v) {
              setState(() => _shareCrash = v);
              _setBool(_kShareCrashKey, v);
            },
          ),
          _toggle(
            title: context.l10n.settings_detailed_reports,
            subtitle: context.l10n.settings_detailed_reports_desc,
            value: _detailedReports,
            onChanged: (v) {
              setState(() => _detailedReports = v);
              _setBool(_kDetailedReportsKey, v);
            },
            danger: true,
          ),
          _action(
            title: context.l10n.settings_onboarding_guide,
            subtitle: context.l10n.settings_onboarding_guide_desc,
            onTap: () => context.push('/onboarding'),
            trailing: Broken.arrow_right_3,
          ),
          _action(
            title: context.l10n.notifications_title,
            subtitle: context.l10n.settings_manage_notifications,
            onTap: _openNotificationSettings,
            trailing: Broken.arrow_right_3,
          ),

          // ── Section : Activité en arrière-plan ──────────────────────────
          _sectionHeader(context.l10n.settings_background_activity),
          if (!kIsWeb && Platform.isAndroid)
            _action(
              title: context.l10n.settings_disable_battery_optimisation,
              subtitle: context.l10n.settings_disable_battery_optimisation_desc,
              onTap: _openBatterySettings,
              trailing: Broken.arrow_right_3,
            ),
          _action(
            title: "Don't kill my app!",
            subtitle: context.l10n.settings_dont_kill_my_app_desc,
            onTap: () => _openUrl("https://dontkillmyapp.com"),
            trailing: Broken.export,
          ),

          // ── Section : Contournement Cloudflare distant ──────────────────
          _sectionHeader(context.l10n.settings_remote_section),
          SwitchListTile(
            title: Text(
              context.l10n.settings_remote_enable,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              _remoteBypass.isConfigured
                  ? context.l10n.settings_remote_connected(_remoteBypass.url)
                  : context.l10n.settings_remote_none_configured,
              style: TextStyle(
                fontSize: 12,
                color: _remoteBypass.isConfigured ? Colors.green : null,
              ),
            ),
            value: _remoteBypass.enabled,
            onChanged: (v) async {
              setState(() {
                _remoteBypass = _remoteBypass.copyWith(enabled: v);
              });
              await _saveRemoteBypass();
            },
          ),
          _action(
            title: context.l10n.settings_remote_configure,
            subtitle: context.l10n.settings_remote_configure_desc,
            onTap: _showRemoteBypassDialog,
            trailing: Broken.setting_2,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Broken.info_circle,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'FlareSolverr',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.settings_flaresolverr_help,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _openUrl(
                        'https://github.com/FlareSolverr/FlareSolverr',
                      ),
                      child: Text(
                        'github.com/FlareSolverr/FlareSolverr →',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Section : Données ───────────────────────────────────────────
          _sectionHeader(context.l10n.settings_data),
          _action(
            title: context.l10n.settings_reindex_downloads,
            subtitle: context.l10n.settings_reindex_downloads_desc,
            onTap: _reindexDownloads,
          ),
          _action(
            title: context.l10n.settings_downloads_not_in_library,
            subtitle: context.l10n.settings_downloads_not_in_library_desc,
            onTap: _addDownloadsToLibrary,
          ),
          _action(
            title: context.l10n.settings_clear_database,
            subtitle: context.l10n.settings_clear_database_desc,
            onTap: _clearDatabase,
            titleColor: Colors.red,
          ),

          // ── Section : Réseau ────────────────────────────────────────────
          _sectionHeader(context.l10n.settings_network),
          _action(
            title: context.l10n.settings_clear_cookies,
            onTap: _clearCookies,
          ),
          _action(
            title: context.l10n.settings_clear_webview_data,
            onTap: _clearWebViewData,
          ),
          ListTile(
            title: Text(
              context.l10n.settings_doh,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              "Google",
              style: TextStyle(fontSize: 12, color: context.secondaryColor),
            ),
            trailing: Icon(
              Broken.arrow_right_3,
              size: 18,
              color: context.secondaryColor,
            ),
            onTap: () => context.push('/general'),
          ),
          Builder(
            builder: (context) {
              final ua = ref.watch(userAgentStateProvider);
              return ListTile(
                title: Text(
                  context.l10n.settings_default_user_agent_list,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  ua,
                  style: TextStyle(fontSize: 11, color: context.secondaryColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
          _action(
            title: context.l10n.settings_reset_user_agent,
            onTap: _resetUserAgent,
          ),

          // ── Section : Cache des icônes ──────────────────────────────────
          _sectionHeader(context.l10n.settings_icon_cover_cache),
          ListTile(
            title: Text(
              context.l10n.settings_max_cache_size,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.settings_max_cache_size_desc,
                  style: TextStyle(fontSize: 12, color: context.secondaryColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _cacheLimitBytes.toDouble(),
                        min: CacheStorageManager.minLimitBytes.toDouble(),
                        max: CacheStorageManager.maxLimitBytes.toDouble(),
                        divisions: 31,
                        label: _fmtSize(context, _cacheLimitBytes),
                        onChanged: (v) =>
                            setState(() => _cacheLimitBytes = v.round()),
                        onChangeEnd: (v) async {
                          final bytes = v.round();
                          await CacheStorageManager.instance.setLimitBytes(
                            bytes,
                          );
                          await _loadCacheSizes();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        _fmtSize(context, _cacheLimitBytes),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _action(
            title: context.l10n.settings_clear_icon_cache,
            subtitle: context.l10n.settings_current_size(_iconCacheSizeStr),
            onTap: _clearIconCache,
            trailing: Broken.broom,
          ),
          _action(
            title: context.l10n.settings_clear_cover_cache,
            subtitle: context.l10n.settings_current_size(_libCacheSizeStr),
            onTap: _clearLibraryCache,
            trailing: Broken.broom,
          ),
          _action(
            title: context.l10n.settings_clear_all_image_caches,
            subtitle:
                context.l10n.settings_current_total_size(_totalCacheSizeStr),
            onTap: _clearAllImageCaches,
            trailing: Broken.trash,
          ),
          _action(
            title: context.l10n.settings_refresh_cache_sizes,
            subtitle: context.l10n.settings_refresh_cache_sizes_desc,
            onTap: () async {
              setState(() {
                _iconCacheSizeStr = '…';
                _libCacheSizeStr = '…';
                _totalCacheSizeStr = '…';
              });
              await _loadCacheSizes();
            },
            trailing: Broken.refresh,
          ),

          // ── Section : Bibliothèque ──────────────────────────────────────
          _sectionHeader(context.l10n.settings_library),
          _action(
            title: context.l10n.settings_refresh_library_covers,
            onTap: () {
              _toast(context.l10n.settings_refreshing_covers);
            },
          ),
          _action(
            title: context.l10n.settings_reset_reader_per_series,
            subtitle: context.l10n.settings_reset_reader_per_series_desc,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(context.l10n.settings_reset_reader_title),
                  content: Text(
                    context.l10n.settings_reset_reader_per_series_desc,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(context.l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(context.l10n.reset),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  final settings =
                      (isar.settings.getSync(kSettingsId) ?? Settings());
                  isar.writeTxnSync(
                    () => isar.settings.putSync(
                      settings
                        ..personalReaderModeList = []
                        ..updatedAt = DateTime.now().millisecondsSinceEpoch,
                    ),
                  );
                  _toast(l10n.settings_reader_reset_done);
                } catch (_) {
                  _toast(l10n.settings_error);
                }
              }
            },
          ),
          _action(
            title: context.l10n.settings_update_library_titles,
            subtitle: context.l10n.settings_update_library_titles_desc,
            onTap: () {
              _toast(context.l10n.settings_updating_titles);
            },
          ),
          _toggle(
            title: context.l10n.settings_no_non_ascii,
            subtitle: context.l10n.settings_no_non_ascii_desc,
            value: _noNonAscii,
            onChanged: (v) {
              setState(() => _noNonAscii = v);
              _setBool(_kNonAsciiKey, v);
            },
          ),

          // ── Section : Lecteur ───────────────────────────────────────────
          _sectionHeader(context.l10n.settings_reader),
          ListTile(
            title: Text(
              context.l10n.settings_bitmap_threshold,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.settings_bitmap_threshold_desc,
                  style: TextStyle(fontSize: 12, color: context.secondaryColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _bitmapThreshold.toDouble(),
                        min: 512,
                        max: 8192,
                        divisions: 15,
                        label: _bitmapThreshold.toString(),
                        onChanged: (v) {
                          setState(() => _bitmapThreshold = v.round());
                          _setInt(_kBitmapThresholdKey, v.round());
                        },
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        _bitmapThreshold.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _toggle(
            title: context.l10n.settings_old_decoder,
            subtitle: context.l10n.settings_old_decoder_desc,
            value: _oldDecoder,
            onChanged: (v) {
              setState(() => _oldDecoder = v);
              _setBool(_kOldDecoderKey, v);
            },
            danger: true,
          ),
          _action(
            title: context.l10n.settings_custom_display_profile,
            trailing: Broken.arrow_right_3,
            onTap: () => context.push('/appearance'),
          ),

          // ── Section : Extensions ────────────────────────────────────────
          _sectionHeader(context.l10n.extensions),
          ListTile(
            title: Text(
              context.l10n.settings_installer,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              "PackageInstaller",
              style: TextStyle(fontSize: 12, color: context.secondaryColor),
            ),
          ),
          _action(
            title: context.l10n.settings_revoke_extra_repo_extensions,
            titleColor: Colors.orange,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(context.l10n.settings_revoke_extensions_title),
                  content: Text(context.l10n.settings_revoke_extensions_body),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(context.l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        context.l10n.settings_revoke,
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                _toast(l10n.settings_extensions_revoked);
              }
            },
          ),

          // ── Section : Logs avancés ──────────────────────────────────────
          // ── Section : Affichage / DPI ────────────────────────────────────
          _sectionHeader(context.l10n.settings_display),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.settings_interface_scale,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      context.l10n
                          .settings_percent('${(_uiScale * 100).round()}'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.settings_interface_scale_desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Slider(
                  value: _uiScale,
                  min: 0.75,
                  max: 1.50,
                  divisions: 15,
                  label: context.l10n
                      .settings_percent('${(_uiScale * 100).round()}'),
                  onChanged: (v) async {
                    setState(() => _uiScale = v);
                    ref.read(uiScaleProvider.notifier).set(v);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '75%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      context.l10n.settings_scale_default,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '150%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Broken.refresh, size: 16),
                    label: Text(
                      context.l10n.reset,
                      style: const TextStyle(fontSize: 13),
                    ),
                    onPressed: () async {
                      setState(() => _uiScale = 1.0);
                      ref.read(uiScaleProvider.notifier).reset();
                    },
                  ),
                ),
              ],
            ),
          ),
          _sectionHeader(context.l10n.settings_advanced_logs),
          _LogAdvancedSection(
            logMode: _logMode,
            logSuppressImages: _logSuppressImages,
            logTagExt: _logTagExt,
            logTagDl: _logTagDl,
            logTagNet: _logTagNet,
            logTagUi: _logTagUi,
            logTagManga: _logTagManga,
            logTagPage: _logTagPage,
            logTagHls: _logTagHls,
            logTagInstall: _logTagInstall,
            logTagReader: _logTagReader,
            logTagWatch: _logTagWatch,
            logTagMaint: _logTagMaint,
            logTagImg: _logTagImg,
            onModeChanged: (mode) => _applyMode(mode),
            onSuppressImagesChanged: (v) {
              setState(() => _logSuppressImages = v);
              _saveLogSetting(kLogSuppressImages, v);
            },
            onTagChanged: (key, v) {
              setState(() {
                switch (key) {
                  case kLogTagExt:
                    _logTagExt = v;
                    break;
                  case kLogTagDl:
                    _logTagDl = v;
                    break;
                  case kLogTagNet:
                    _logTagNet = v;
                    break;
                  case kLogTagUi:
                    _logTagUi = v;
                    break;
                  case kLogTagManga:
                    _logTagManga = v;
                    break;
                  case kLogTagPage:
                    _logTagPage = v;
                    break;
                  case kLogTagHls:
                    _logTagHls = v;
                    break;
                  case kLogTagInstall:
                    _logTagInstall = v;
                    break;
                  case kLogTagReader:
                    _logTagReader = v;
                    break;
                  case kLogTagWatch:
                    _logTagWatch = v;
                    break;
                  case kLogTagMaint:
                    _logTagMaint = v;
                    break;
                  case kLogTagImg:
                    _logTagImg = v;
                    break;
                }
              });
              _saveLogSetting(key, v);
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log Advanced Section — 4 preset modes + per-tag customization
// ─────────────────────────────────────────────────────────────────────────────

/// Maps the logger's preset mode to the localized label / description. Kept
/// here rather than on [LogMode] because that enum lives in the logger, which
/// must stay free of a BuildContext.
String _logModeName(AppLocalizations l10n, LogMode mode) => switch (mode) {
      LogMode.normal => l10n.settings_log_mode_normal,
      LogMode.verbose => l10n.settings_log_mode_verbose,
      LogMode.debug => l10n.settings_log_mode_debug,
      LogMode.extreme => l10n.settings_log_mode_extreme,
    };

String _logModeDescription(AppLocalizations l10n, LogMode mode) =>
    switch (mode) {
      LogMode.normal => l10n.settings_log_mode_normal_desc,
      LogMode.verbose => l10n.settings_log_mode_verbose_desc,
      LogMode.debug => l10n.settings_log_mode_debug_desc,
      LogMode.extreme => l10n.settings_log_mode_extreme_desc,
    };

class _LogAdvancedSection extends ConsumerWidget {
  final int logMode;
  final bool logSuppressImages;
  final bool logTagExt;
  final bool logTagDl;
  final bool logTagNet;
  final bool logTagUi;
  final bool logTagManga;
  final bool logTagPage;
  final bool logTagHls;
  final bool logTagInstall;
  final bool logTagReader;
  final bool logTagWatch;
  final bool logTagMaint;
  final bool logTagImg;
  final void Function(LogMode) onModeChanged;
  final void Function(bool) onSuppressImagesChanged;
  final void Function(String, bool) onTagChanged;

  const _LogAdvancedSection({
    required this.logMode,
    required this.logSuppressImages,
    required this.logTagExt,
    required this.logTagDl,
    required this.logTagNet,
    required this.logTagUi,
    required this.logTagManga,
    required this.logTagPage,
    required this.logTagHls,
    required this.logTagInstall,
    required this.logTagReader,
    required this.logTagWatch,
    required this.logTagMaint,
    required this.logTagImg,
    required this.onModeChanged,
    required this.onSuppressImagesChanged,
    required this.onTagChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsEnabled = ref.watch(logsStateProvider);
    final cs = Theme.of(context).colorScheme;
    final secondary =
        Theme.of(context).textTheme.bodySmall?.color ??
        cs.onSurface.withValues(alpha: 0.6);
    final selectedMode = LogMode.values[logMode.clamp(0, 3)];
    final l10n = context.l10n;

    // ── Tag toggle helper ──────────────────────────────────────────────────
    Widget logToggle({
      required String title,
      required String subtitle,
      required String tagKey,
      required bool value,
      bool danger = false,
    }) {
      final activeColor = danger ? Colors.red : cs.primary;
      return SwitchListTile(
        dense: true,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            color: logsEnabled ? null : secondary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11.5, color: secondary),
        ),
        value: value,
        onChanged: logsEnabled ? (v) => onTagChanged(tagKey, v) : null,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return cs.onSurface.withValues(alpha: 0.3);
          }
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return cs.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.selected)) return activeColor;
          return null;
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Logs disabled notice ───────────────────────────────────────────
        if (!logsEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Broken.info_circle,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.settings_logs_enable_hint,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Mode selector ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settings_log_mode,
                style: TextStyle(fontSize: 13, color: secondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: LogMode.values.map((mode) {
                  final selected = logMode == mode.index;
                  final Color chipColor;
                  switch (mode) {
                    case LogMode.normal:
                      chipColor = Colors.green;
                      break;
                    case LogMode.verbose:
                      chipColor = Colors.blue;
                      break;
                    case LogMode.debug:
                      chipColor = Colors.orange;
                      break;
                    case LogMode.extreme:
                      chipColor = Colors.red;
                      break;
                  }
                  return ChoiceChip(
                    label: Text(
                      _logModeName(l10n, mode),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : logsEnabled
                            ? chipColor
                            : secondary,
                      ),
                    ),
                    selected: selected,
                    selectedColor: logsEnabled ? chipColor : secondary,
                    backgroundColor: logsEnabled
                        ? chipColor.withValues(alpha: 0.1)
                        : cs.surfaceContainerHighest,
                    side: BorderSide(
                      color: selected
                          ? Colors.transparent
                          : logsEnabled
                          ? chipColor.withValues(alpha: 0.4)
                          : secondary.withValues(alpha: 0.2),
                    ),
                    onSelected: logsEnabled ? (_) => onModeChanged(mode) : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                _logModeDescription(l10n, selectedMode),
                style: TextStyle(
                  fontSize: 11,
                  color: secondary.withValues(alpha: 0.75),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 20, indent: 16, endIndent: 16),

        // ── Suppress image errors ──────────────────────────────────────────
        SwitchListTile(
          dense: true,
          title: Text(
            l10n.settings_log_suppress_images,
            style: TextStyle(
              fontSize: 13.5,
              color: logsEnabled ? null : secondary,
            ),
          ),
          subtitle: Text(
            l10n.settings_log_suppress_images_desc,
            style: TextStyle(fontSize: 11.5, color: secondary),
          ),
          value: logSuppressImages,
          onChanged: logsEnabled ? onSuppressImagesChanged : null,
        ),

        const Divider(height: 20, indent: 16, endIndent: 16),

        // ── Active tags (fully customizable) ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: [
              Text(
                l10n.settings_log_active_categories,
                style: TextStyle(fontSize: 13, color: secondary),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l10n.settings_log_customisable,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        logToggle(
          title: l10n.settings_log_tag_ext,
          subtitle: l10n.settings_log_tag_ext_desc,
          tagKey: kLogTagExt,
          value: logTagExt,
        ),
        logToggle(
          title: l10n.settings_log_tag_install,
          subtitle: l10n.settings_log_tag_install_desc,
          tagKey: kLogTagInstall,
          value: logTagInstall,
        ),
        logToggle(
          title: l10n.settings_log_tag_dl,
          subtitle: l10n.settings_log_tag_dl_desc,
          tagKey: kLogTagDl,
          value: logTagDl,
        ),
        logToggle(
          title: l10n.settings_log_tag_hls,
          subtitle: l10n.settings_log_tag_hls_desc,
          tagKey: kLogTagHls,
          value: logTagHls,
        ),
        logToggle(
          title: l10n.settings_log_tag_net,
          subtitle: l10n.settings_log_tag_net_desc,
          tagKey: kLogTagNet,
          value: logTagNet,
        ),
        logToggle(
          title: l10n.settings_log_tag_manga,
          subtitle: l10n.settings_log_tag_manga_desc,
          tagKey: kLogTagManga,
          value: logTagManga,
        ),
        logToggle(
          title: l10n.settings_log_tag_reader,
          subtitle: l10n.settings_log_tag_reader_desc,
          tagKey: kLogTagReader,
          value: logTagReader,
        ),
        logToggle(
          title: l10n.settings_log_tag_page,
          subtitle: l10n.settings_log_tag_page_desc,
          tagKey: kLogTagPage,
          value: logTagPage,
          danger: true,
        ),
        logToggle(
          title: l10n.settings_log_tag_watch,
          subtitle: l10n.settings_log_tag_watch_desc,
          tagKey: kLogTagWatch,
          value: logTagWatch,
        ),
        logToggle(
          title: l10n.settings_log_tag_maint,
          subtitle: l10n.settings_log_tag_maint_desc,
          tagKey: kLogTagMaint,
          value: logTagMaint,
        ),
        logToggle(
          title: l10n.settings_log_tag_ui,
          subtitle: l10n.settings_log_tag_ui_desc,
          tagKey: kLogTagUi,
          value: logTagUi,
        ),
        logToggle(
          title: l10n.settings_log_tag_img,
          subtitle: l10n.settings_log_tag_img_desc,
          tagKey: kLogTagImg,
          value: logTagImg,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Silent-install setup tile (shown in Advanced settings)
// ─────────────────────────────────────────────────────────────────────────────

class _SilentInstallTile extends StatefulWidget {
  const _SilentInstallTile({required this.status, required this.onChanged});
  final SilentInstallStatus status;
  final ValueChanged<bool> onChanged;

  @override
  State<_SilentInstallTile> createState() => _SilentInstallTileState();
}

class _SilentInstallTileState extends State<_SilentInstallTile> {
  bool _busy = false;

  String _subtitle(BuildContext context) {
    final l10n = context.l10n;
    switch (widget.status) {
      case SilentInstallStatus.active:
        return l10n.settings_silent_active;
      case SilentInstallStatus.shizukuRequired:
        return l10n.settings_silent_shizuku_required;
      case SilentInstallStatus.shizukuNotRunning:
        return l10n.settings_silent_shizuku_not_running;
      case SilentInstallStatus.unknown:
        return l10n.settings_silent_checking;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        widget.status == SilentInstallStatus.active
            ? Broken.tick_circle
            : Broken.document_download,
        color: widget.status == SilentInstallStatus.active
            ? Colors.green
            : Theme.of(context).colorScheme.secondary,
      ),
      title: Text(context.l10n.settings_silent_updates),
      subtitle: Text(_subtitle(context)),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (widget.status == SilentInstallStatus.active
                ? null
                : const Icon(Broken.arrow_right_3)),
      onTap: widget.status == SilentInstallStatus.active || _busy
          ? null
          : () async {
              setState(() => _busy = true);
              bool success = false;
              try {
                success = await SilentInstallerService.instance
                    .setupWithShizuku(context);
              } finally {
                if (mounted) setState(() => _busy = false);
                widget.onChanged(success);
              }
            },
    );
  }
}
