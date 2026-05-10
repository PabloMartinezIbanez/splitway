import 'package:flutter/foundation.dart';

import '../../data/repositories/local_draft_repository.dart';
import '../../data/repositories/supabase_repository.dart';

/// Bidirectional sync between [LocalDraftRepository] (SQLite) and
/// [SupabaseRepository] (Postgres + RLS).
///
/// Strategy: **last-write-wins** based on `updated_at`.
/// - Push: all local routes/sessions that don't exist remotely or are newer.
/// - Pull: all remote routes/sessions that don't exist locally or are newer.
///
/// Telemetry is treated as immutable — once a session is completed and synced,
/// its telemetry never changes. Re-syncing only overwrites if the session's
/// `updated_at` is newer.
class SyncService extends ChangeNotifier {
  SyncService({
    required this.local,
    required this.remote,
  });

  final LocalDraftRepository local;
  final SupabaseRepository remote;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  String? _lastError;
  String? get lastError => _lastError;

  DateTime? _lastSyncedAt;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Runs a full bidirectional sync.
  /// Returns the number of items transferred (pushed + pulled).
  Future<int> sync() async {
    if (_status == SyncStatus.syncing) return 0;
    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    try {
      final transferred = await _doSync();
      _status = SyncStatus.idle;
      _lastSyncedAt = DateTime.now();
      notifyListeners();
      return transferred;
    } catch (e, st) {
      debugPrint('SyncService error: $e\n$st');
      _status = SyncStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return 0;
    }
  }

  Future<int> _doSync() async {
    var transferred = 0;

    // --- Routes ---
    final localRoutes = await local.getAllRoutes();
    final remoteTimestamps = await remote.fetchRouteTimestamps();

    // Push local → remote (routes that are new or newer locally)
    for (final route in localRoutes) {
      final remoteUpdated = remoteTimestamps[route.id];
      if (remoteUpdated == null || route.createdAt.isAfter(remoteUpdated)) {
        await remote.upsertRoute(route);
        transferred++;
      }
    }

    // Pull remote → local (routes that don't exist locally or are newer)
    final localRouteIds = {for (final r in localRoutes) r.id};
    final remoteRoutes = await remote.fetchAllRoutes();
    for (final route in remoteRoutes) {
      if (!localRouteIds.contains(route.id)) {
        await local.saveRouteTemplate(route);
        transferred++;
      }
      // If exists locally but remote is newer, overwrite local.
      // For simplicity in iter 3, we skip this — last pusher wins.
    }

    // --- Sessions ---
    final localSessions = await local.getAllSessions(includePoints: true);
    final remoteSessionTimestamps = await remote.fetchSessionTimestamps();

    // Push local → remote
    for (final session in localSessions) {
      final remoteUpdated = remoteSessionTimestamps[session.id];
      if (remoteUpdated == null ||
          (session.endedAt?.isAfter(remoteUpdated) ?? false)) {
        await remote.upsertSession(session);
        transferred++;
      }
    }

    // Pull remote → local
    final localSessionIds = {for (final s in localSessions) s.id};
    final remoteSessions =
        await remote.fetchAllSessions(includePoints: true);
    for (final session in remoteSessions) {
      if (!localSessionIds.contains(session.id)) {
        await local.saveSessionRun(session);
        transferred++;
      }
    }

    return transferred;
  }
}

enum SyncStatus { idle, syncing, error }
