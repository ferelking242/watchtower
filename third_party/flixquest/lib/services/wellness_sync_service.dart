import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../controllers/wellness_database_controller.dart';
import '../models/wellness.dart';

enum WellnessSyncStatus { idle, syncing, success, error }

class WellnessSyncService {
  WellnessSyncService({
    WellnessDatabaseController? database,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _database = database ?? WellnessDatabaseController.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final WellnessDatabaseController _database;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  bool _syncing = false;

  final ValueNotifier<WellnessSyncStatus> status =
      ValueNotifier<WellnessSyncStatus>(WellnessSyncStatus.idle);
  final ValueNotifier<DateTime?> lastSynced = ValueNotifier<DateTime?>(null);

  User? get currentUser => _auth.currentUser;
  bool get canSync => currentUser != null && !currentUser!.isAnonymous;
  String? get currentUid => canSync ? currentUser!.uid : null;

  Future<bool> syncNow() async {
    if (!canSync || _syncing) return false;
    _syncing = true;
    status.value = WellnessSyncStatus.syncing;
    final uid = currentUser!.uid;
    final ownerId = 'user:$uid';
    debugPrint('[WellnessSync] sync start uid=$uid');
    try {
      final collection =
          _firestore.collection('wellness-v1').doc(uid).collection('sessions');
      final cloudSnapshot = await collection.get();
      debugPrint(
        '[WellnessSync] read cloud sessions: ${cloudSnapshot.docs.length}',
      );
      final localSessions = await _database.sessionsForOwner(
        ownerId,
        includeDeleted: true,
      );
      final localById = <String, WellnessViewingSession>{
        for (final session in localSessions) session.id: session,
      };
      final pulled = <WellnessViewingSession>[];
      for (final doc in cloudSnapshot.docs) {
        final cloud = WellnessViewingSession.fromMap(<String, dynamic>{
          ...doc.data(),
          'id': doc.id,
          'ownerId': ownerId,
          'synced': true,
        });
        final local = localById[cloud.id];
        if (local == null || !local.updatedAtUtc.isAfter(cloud.updatedAtUtc)) {
          pulled.add(cloud.copyWith(synced: true));
        }
      }
      if (pulled.isNotEmpty) {
        await _database.upsertSessions(pulled, ownerId: ownerId);
        debugPrint('[WellnessSync] applied ${pulled.length} pulled sessions');
      }

      final pending = await _database.pendingSessions(ownerId);
      debugPrint('[WellnessSync] uploading ${pending.length} pending sessions');
      for (var offset = 0; offset < pending.length; offset += 450) {
        final chunk = pending.skip(offset).take(450).toList(growable: false);
        final batch = _firestore.batch();
        for (final session in chunk) {
          batch.set(
            collection.doc(session.id),
            session.toCloudMap(),
            SetOptions(merge: true),
          );
        }
        await batch.commit();
        await _database.markSynced(
          ownerId,
          chunk.map((session) => session.id),
        );
      }
      debugPrint('[WellnessSync] sessions uploaded to cloud');
      await _syncDailySummaries(uid, ownerId);
      lastSynced.value = DateTime.now();
      status.value = WellnessSyncStatus.success;
      debugPrint('[WellnessSync] sync success');
      return true;
    } catch (error, stackTrace) {
      debugPrint('[WellnessSync] sync FAILED: $error');
      debugPrintStack(stackTrace: stackTrace, label: '[WellnessSync]');
      status.value = WellnessSyncStatus.error;
      return false;
    } finally {
      _syncing = false;
      if (status.value == WellnessSyncStatus.syncing) {
        status.value = WellnessSyncStatus.idle;
      }
    }
  }

  Future<void> _syncDailySummaries(String uid, String ownerId) async {
    final summaries = await _database.dailySummaries(ownerId);
    final collection =
        _firestore.collection('wellness-v1').doc(uid).collection('daily');
    final remote = await collection.get();
    final remoteById = <String, Map<String, dynamic>>{
      for (final doc in remote.docs) doc.id: doc.data(),
    };
    final localDays =
        summaries.map((summary) => summary['local_day'].toString()).toSet();
    final operations = <_DailyWrite>[
      for (final doc in remote.docs)
        if (!localDays.contains(doc.id)) _DailyWrite.delete(doc.reference),
      for (final summary in summaries)
        if ((summary['updated_at_utc'] as num?)?.toInt() !=
            (remoteById[summary['local_day'].toString()]?['updatedAtUtc']
                    as num?)
                ?.toInt())
          _DailyWrite.set(
            collection.doc(summary['local_day'].toString()),
            <String, dynamic>{
              'localDay': summary['local_day'],
              'timezoneOffsetMinutes': summary['timezone_offset_minutes'],
              'watchedMs': summary['watched_ms'],
              'movieMs': summary['movie_ms'],
              'episodeMs': summary['episode_ms'],
              'liveMs': summary['live_ms'],
              'completedMovies': summary['completed_movies'],
              'completedEpisodes': summary['completed_episodes'],
              'sessionCount': summary['session_count'],
              'updatedAtUtc': summary['updated_at_utc'],
            },
          ),
    ];
    for (var offset = 0; offset < operations.length; offset += 450) {
      final batch = _firestore.batch();
      for (final operation in operations.skip(offset).take(450)) {
        if (operation.data == null) {
          batch.delete(operation.reference);
        } else {
          batch.set(operation.reference, operation.data!);
        }
      }
      await batch.commit();
    }
  }

  Future<void> deleteRemoteAccountData(String uid) async {
    for (final child in const <String>['sessions', 'daily']) {
      final collection =
          _firestore.collection('wellness-v1').doc(uid).collection(child);
      while (true) {
        final snapshot = await collection.limit(450).get();
        if (snapshot.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await _firestore.collection('wellness-v1').doc(uid).delete();
  }
}

class _DailyWrite {
  const _DailyWrite._(this.reference, this.data);

  factory _DailyWrite.delete(DocumentReference<Map<String, dynamic>> ref) =>
      _DailyWrite._(ref, null);

  factory _DailyWrite.set(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) =>
      _DailyWrite._(ref, data);

  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic>? data;
}
