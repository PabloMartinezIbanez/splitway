import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../data/repositories/local_draft_repository.dart';
import '../../services/tracking/live_tracking_controller.dart';

enum LiveSessionStage { selecting, ready, running, finished }

class LiveSessionController extends ChangeNotifier {
  LiveSessionController(this._repo);

  final LocalDraftRepository _repo;

  LiveSessionStage _stage = LiveSessionStage.selecting;
  LiveSessionStage get stage => _stage;

  List<RouteTemplate> _routes = const [];
  List<RouteTemplate> get routes => _routes;

  RouteTemplate? _selected;
  RouteTemplate? get selected => _selected;

  LiveTrackingController? _tracker;
  LiveTrackingController? get tracker => _tracker;

  SessionRun? _result;
  SessionRun? get result => _result;

  Timer? _autoSimulator;
  int _autoIndex = 0;
  List<TelemetryPoint> _autoScript = const [];

  Future<void> load() async {
    _routes = await _repo.getAllRoutes();
    _selected ??= _routes.isNotEmpty ? _routes.first : null;
    if (_selected != null) _stage = LiveSessionStage.ready;
    notifyListeners();
  }

  void selectRoute(RouteTemplate route) {
    _selected = route;
    _stage = LiveSessionStage.ready;
    notifyListeners();
  }

  void startSession() {
    final route = _selected;
    if (route == null) return;
    _tracker?.dispose();
    _tracker = LiveTrackingController(route: route)
      ..addListener(_onTrackerChange)
      ..startSession();
    _stage = LiveSessionStage.running;
    notifyListeners();
  }

  void simulateOnePoint() {
    final t = _tracker;
    final route = _selected;
    if (t == null || route == null) return;
    final base = DateTime.now();
    if (_autoScript.isEmpty) {
      _autoScript = t.buildAutoLapScript(startTime: base);
      _autoIndex = 0;
    }
    if (_autoIndex >= _autoScript.length) return;
    final original = _autoScript[_autoIndex];
    // Re-stamp with current time so manual stepping shows realistic deltas.
    final point = TelemetryPoint(
      timestamp: base,
      location: original.location,
      speedMps: original.speedMps,
    );
    t.ingestSimulatedPoint(point);
    _autoIndex++;
    notifyListeners();
  }

  void toggleAutoSimulate() {
    if (_autoSimulator != null) {
      _autoSimulator?.cancel();
      _autoSimulator = null;
      notifyListeners();
      return;
    }
    final t = _tracker;
    if (t == null) return;
    if (_autoScript.isEmpty) {
      _autoScript = t.buildAutoLapScript(startTime: DateTime.now());
      _autoIndex = 0;
    }
    _autoSimulator = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (_autoIndex >= _autoScript.length) {
        _autoSimulator?.cancel();
        _autoSimulator = null;
        notifyListeners();
        return;
      }
      final scripted = _autoScript[_autoIndex];
      final point = TelemetryPoint(
        timestamp: DateTime.now(),
        location: scripted.location,
        speedMps: scripted.speedMps,
      );
      t.ingestSimulatedPoint(point);
      _autoIndex++;
      notifyListeners();
    });
    notifyListeners();
  }

  bool get isAutoSimulating => _autoSimulator != null;

  Future<SessionRun?> finishSession() async {
    _autoSimulator?.cancel();
    _autoSimulator = null;
    final t = _tracker;
    if (t == null) return null;
    final session = t.finishSession();
    await _repo.saveSessionRun(session);
    _result = session;
    _stage = LiveSessionStage.finished;
    notifyListeners();
    return session;
  }

  void resetForNewSession() {
    _tracker?.removeListener(_onTrackerChange);
    _tracker?.dispose();
    _tracker = null;
    _autoIndex = 0;
    _autoScript = const [];
    _result = null;
    _stage = _selected == null
        ? LiveSessionStage.selecting
        : LiveSessionStage.ready;
    notifyListeners();
  }

  void _onTrackerChange() => notifyListeners();

  @override
  void dispose() {
    _autoSimulator?.cancel();
    _tracker?.removeListener(_onTrackerChange);
    _tracker?.dispose();
    super.dispose();
  }
}
