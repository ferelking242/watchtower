import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/wellness_database_controller.dart';
import '../models/wellness.dart';
import '../models/wellness_insights.dart';
import '../services/wellness_sync_service.dart';

class WellnessProvider extends ChangeNotifier {
  WellnessProvider._();

  static final WellnessProvider instance = WellnessProvider._();
  static const guestOwnerId = 'guest';
  static const _deviceIdKey = 'wellness.device_id.v1';

  final WellnessDatabaseController _database =
      WellnessDatabaseController.instance;
  late final WellnessSyncService _syncService;
  StreamSubscription<User?>? _authSubscription;
  Timer? _syncDebounce;
  List<WellnessViewingSession> _sessions = const <WellnessViewingSession>[];
  WellnessRange _range = WellnessRange.week;
  bool _loading = true;
  bool _guestMergeDismissed = false;
  bool _hasGuestHistory = false;
  String _ownerId = guestOwnerId;
  String _deviceId = '';

  List<WellnessViewingSession> get sessions => _sessions;
  WellnessRange get range => _range;
  bool get loading => _loading;
  bool get canSync => _syncService.canSync;
  WellnessSyncService get syncService => _syncService;
  String get activeOwnerId => _ownerId;
  String get deviceId => _deviceId;
  bool get shouldOfferGuestMerge =>
      canSync && _hasGuestHistory && !_guestMergeDismissed;

  WellnessInsights get insights => WellnessInsights.fromSessions(
        _sessions,
        period: WellnessPeriod.forRange(_range, DateTime.now()),
      );

  WellnessInsights get previousInsights => WellnessInsights.fromSessions(
        _sessions,
        period: WellnessPeriod.forRange(_range, DateTime.now()).previous(),
      );

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey) ?? _newDeviceId();
    await prefs.setString(_deviceIdKey, _deviceId);
    _syncService = WellnessSyncService(database: _database);
    _syncService.status.addListener(notifyListeners);
    _syncService.lastSynced.addListener(notifyListeners);
    await _applyUser(FirebaseAuth.instance.currentUser, sync: false);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
          (user) => unawaited(_applyUser(user)),
        );
    if (canSync) unawaited(syncNow());
  }

  String _newDeviceId() {
    final random = Random.secure();
    final entropy = List<int>.generate(4, (_) => random.nextInt(1 << 32))
        .map((value) => value.toRadixString(16).padLeft(8, '0'))
        .join();
    return '${DateTime.now().microsecondsSinceEpoch}-$entropy';
  }

  Future<void> _applyUser(User? user, {bool sync = true}) async {
    final registered = user != null && !user.isAnonymous;
    _ownerId = registered ? 'user:${user.uid}' : guestOwnerId;
    _guestMergeDismissed = false;
    await reload();
    _hasGuestHistory = await _database.ownerSessionCount(guestOwnerId) > 0;
    notifyListeners();
    if (sync && registered) await syncNow();
  }

  Future<void> reload() async {
    _loading = true;
    notifyListeners();
    _sessions = await _database.sessionsForOwner(_ownerId);
    _loading = false;
    notifyListeners();
  }

  void setRange(WellnessRange range) {
    if (_range == range) return;
    _range = range;
    notifyListeners();
  }

  Future<void> recordPlayback({
    required String sessionId,
    required WellnessPlaybackTracker tracker,
    required WellnessMediaType mediaType,
    required WellnessPlaybackSource source,
    required String contentId,
    required String title,
    required int durationMs,
    required int progressEndMs,
    required bool completed,
    String? seriesId,
    String? subtitle,
    int? seasonNumber,
    int? episodeNumber,
    String? posterPath,
    String? backdropPath,
    int? releaseYear,
    String? provider,
    List<String> genres = const <String>[],
    List<String> languages = const <String>[],
    List<String> countries = const <String>[],
    bool syncImmediately = false,
  }) async {
    final now = DateTime.now();
    final segments = tracker.snapshot(now);
    final watchedMs = segments.fold<int>(
      0,
      (total, segment) => total + segment.watchedMs,
    );
    if (watchedMs < const Duration(seconds: 30).inMilliseconds) return;
    final ownerAtWrite = _ownerId;
    final session = WellnessViewingSession(
      id: sessionId,
      ownerId: ownerAtWrite,
      deviceId: _deviceId,
      mediaType: mediaType,
      source: source,
      contentId: contentId,
      seriesId: seriesId,
      title: title,
      subtitle: subtitle,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      startedAtUtc: tracker.createdAtUtc,
      endedAtUtc: now.toUtc(),
      timezoneOffsetMinutes: now.timeZoneOffset.inMinutes,
      watchedMs: watchedMs,
      durationMs: durationMs,
      progressEndMs: progressEndMs,
      completed:
          completed || (durationMs > 0 && progressEndMs / durationMs >= 0.85),
      segments: segments,
      posterPath: posterPath,
      backdropPath: backdropPath,
      releaseYear: releaseYear,
      provider: provider,
      genres: genres,
      languages: languages,
      countries: countries,
      updatedAtUtc: now.toUtc(),
      synced: false,
    );
    await _database.upsertSession(session);
    if (ownerAtWrite == _ownerId) {
      _sessions = await _database.sessionsForOwner(_ownerId);
      notifyListeners();
    }
    if (ownerAtWrite.startsWith('user:')) {
      if (syncImmediately) {
        _syncDebounce?.cancel();
        unawaited(syncNow());
      } else {
        _syncDebounce?.cancel();
        _syncDebounce = Timer(
          const Duration(minutes: 2),
          () => unawaited(syncNow()),
        );
      }
    }
  }

  Future<bool> syncNow() async {
    final success = await _syncService.syncNow();
    if (success) await reload();
    return success;
  }

  Future<void> mergeGuestHistory() async {
    if (!canSync || !_ownerId.startsWith('user:')) return;
    await _database.moveOwner(
      fromOwnerId: guestOwnerId,
      toOwnerId: _ownerId,
    );
    _hasGuestHistory = false;
    await reload();
    await syncNow();
  }

  void dismissGuestMerge() {
    _guestMergeDismissed = true;
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    await _database.tombstoneSession(_ownerId, id);
    await reload();
    if (canSync) unawaited(syncNow());
  }

  Future<void> clearHistory() async {
    await _database.tombstoneAll(_ownerId);
    await reload();
    if (canSync) unawaited(syncNow());
  }

  Future<String> exportJson() async {
    final sessions = await _database.sessionsForOwner(_ownerId);
    return WellnessDatabaseController.encodeExport(sessions);
  }

  Future<String> exportCsv() async {
    final sessions = await _database.sessionsForOwner(_ownerId);
    return WellnessDatabaseController.encodeCsv(sessions);
  }

  Future<void> deleteAccountData(String uid) async {
    await _syncService.deleteRemoteAccountData(uid);
    await _database.permanentlyDeleteOwner('user:$uid');
    if (_ownerId == 'user:$uid') await _applyUser(null, sync: false);
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _authSubscription?.cancel();
    _syncService.status.removeListener(notifyListeners);
    _syncService.lastSynced.removeListener(notifyListeners);
    super.dispose();
  }
}
