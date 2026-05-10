import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:splitway_core/splitway_core.dart';

enum LiveControllerState { idle, recording, finished }

class LiveTrackingController extends ChangeNotifier {
  LiveTrackingController({required this.route, String? sessionId})
      : sessionId = sessionId ?? 'sess-${DateTime.now().microsecondsSinceEpoch}',
        _engine = TrackingEngine(
          route: route,
          sessionId: sessionId ?? 'sess-${DateTime.now().microsecondsSinceEpoch}',
        );

  final RouteTemplate route;
  final String sessionId;
  final TrackingEngine _engine;

  LiveControllerState _state = LiveControllerState.idle;
  LiveControllerState get state => _state;

  TrackingSnapshot _snapshot = TrackingSnapshot.initial;
  TrackingSnapshot get snapshot => _snapshot;

  final List<TrackingEvent> _events = [];
  List<TrackingEvent> get events => List.unmodifiable(_events);

  final List<TelemetryPoint> _ingested = [];
  List<TelemetryPoint> get ingested => List.unmodifiable(_ingested);

  StreamSubscription<TrackingEvent>? _eventSub;
  Timer? _ticker;

  void startSession() {
    if (_state != LiveControllerState.idle) return;
    _engine.start();
    _state = LiveControllerState.recording;
    _eventSub = _engine.events.listen((evt) {
      _events.add(evt);
      notifyListeners();
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _snapshot = _engine.snapshot;
      notifyListeners();
    });
    _snapshot = _engine.snapshot;
    notifyListeners();
  }

  /// Iter 1: feed simulated points (one per tap or scripted) so the engine
  /// can be exercised end-to-end without GPS hardware.
  void ingestSimulatedPoint(TelemetryPoint point) {
    if (_state != LiveControllerState.recording) return;
    _ingested.add(point);
    _engine.ingest(point);
    _snapshot = _engine.snapshot;
    notifyListeners();
  }

  /// Builds a synthetic track from the route's path that will hit start +
  /// every sector + close lap once. Used by the "auto-simulate" button to
  /// drive a complete demo lap in a few seconds.
  List<TelemetryPoint> buildAutoLapScript({required DateTime startTime}) {
    final path = route.path;
    if (path.isEmpty) return const [];
    // Place a point slightly outside the start gate, then walk the route.
    final start = route.startFinishGate.center;
    // Approach point — offset a few meters inside the loop.
    final approach = GeoPoint(
      latitude: start.latitude - 0.0001,
      longitude: start.longitude - 0.0001,
    );
    final points = <GeoPoint>[approach, start, ...path, start, approach];
    return [
      for (var i = 0; i < points.length; i++)
        TelemetryPoint(
          timestamp: startTime.add(Duration(milliseconds: i * 600)),
          location: points[i],
          speedMps: 12,
        ),
    ];
  }

  SessionRun finishSession() {
    if (_state == LiveControllerState.finished) {
      // Engine already finalized; rebuild a snapshot session.
      return _engine.finish();
    }
    final session = _engine.finish();
    _state = LiveControllerState.finished;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
    return session;
  }

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    await _eventSub?.cancel();
    await _engine.dispose();
    super.dispose();
  }
}
