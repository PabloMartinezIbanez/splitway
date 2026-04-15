import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../services/tracking/live_tracking_controller.dart';

enum LiveSessionPhase { idle, running, paused, finished }

class LiveSessionController extends ChangeNotifier {
  LiveSessionController({required this.route})
    : _trackingController = LiveTrackingController(route: route) {
    _trackingController.addListener(_handleTrackingUpdate);
  }

  final RouteTemplate route;
  final LiveTrackingController _trackingController;

  Timer? _uiTimer;
  final Stopwatch _stopwatch = Stopwatch();
  final List<ManualSplitSummary> _manualSplitSummaries = [];

  LiveSessionPhase _phase = LiveSessionPhase.idle;
  Duration _elapsed = Duration.zero;
  Duration _lastSplitMark = Duration.zero;
  DateTime? _startedAt;
  DateTime? _endedAt;
  double _currentSpeedKmh = 0;

  LiveSessionPhase get phase => _phase;
  Duration get elapsed => _elapsed;
  double get currentSpeedKmh => _currentSpeedKmh;
  TrackingSnapshot get snapshot => _trackingController.snapshot;
  List<ManualSplitSummary> get manualSplitSummaries =>
      List.unmodifiable(_manualSplitSummaries);
  bool get isRunning => _phase == LiveSessionPhase.running;
  bool get isPaused => _phase == LiveSessionPhase.paused;
  bool get isFinished => _phase == LiveSessionPhase.finished;

  Future<void> start() async {
    if (_phase != LiveSessionPhase.idle) {
      return;
    }

    _startedAt = DateTime.now().toUtc();
    _phase = LiveSessionPhase.running;
    _stopwatch
      ..reset()
      ..start();
    _startTicker();
    notifyListeners();

    unawaited(_trackingController.startGpsTracking().catchError((_) {}));
  }

  Future<void> pause() async {
    if (_phase != LiveSessionPhase.running) {
      return;
    }

    _stopwatch.stop();
    _elapsed = _stopwatch.elapsed;
    _uiTimer?.cancel();
    await _trackingController.stopGpsTracking();
    _phase = LiveSessionPhase.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_phase != LiveSessionPhase.paused) {
      return;
    }

    _phase = LiveSessionPhase.running;
    _stopwatch.start();
    _startTicker();
    notifyListeners();

    unawaited(_trackingController.startGpsTracking().catchError((_) {}));
  }

  void markManualSplit() {
    if (_phase != LiveSessionPhase.running) {
      return;
    }

    final markedAt = _stopwatch.elapsed;
    final splitNumber = _manualSplitSummaries.length + 1;
    _manualSplitSummaries.add(
      ManualSplitSummary(
        splitNumber: splitNumber,
        label: 'Manual $splitNumber',
        duration: markedAt - _lastSplitMark,
        markedAt: markedAt,
      ),
    );
    _lastSplitMark = markedAt;
    _elapsed = markedAt;
    notifyListeners();
  }

  Future<void> finish() async {
    if (_phase != LiveSessionPhase.running && _phase != LiveSessionPhase.paused) {
      return;
    }

    _stopwatch.stop();
    _elapsed = _stopwatch.elapsed;
    _endedAt = (_startedAt ?? DateTime.now().toUtc()).add(_elapsed);
    _uiTimer?.cancel();
    await _trackingController.stopGpsTracking();
    _phase = LiveSessionPhase.finished;
    notifyListeners();
  }

  Future<void> loadDemoLap() async {
    if (_phase != LiveSessionPhase.idle) {
      return;
    }

    await _trackingController.simulateDemoLap();
    final points = snapshot.telemetryPoints;
    if (points.isNotEmpty) {
      _startedAt = points.first.timestamp;
      _endedAt = points.last.timestamp;
      _elapsed = points.last.timestamp.difference(points.first.timestamp);
    }
    _phase = LiveSessionPhase.finished;
    _handleTrackingUpdate();
    notifyListeners();
  }

  SessionRun buildCompletedSession({
    required String sessionId,
    required String installId,
  }) {
    final telemetry = snapshot.telemetryPoints;
    final startedAt = _startedAt ?? DateTime.now().toUtc();
    final endedAt = _endedAt ?? startedAt.add(_elapsed);

    if (telemetry.isNotEmpty) {
      final base = _trackingController.buildCompletedSession(
        sessionId: sessionId,
        installId: installId,
      );
      return SessionRun(
        id: base.id,
        routeTemplateId: base.routeTemplateId,
        installId: base.installId,
        status: base.status,
        startedAt: base.startedAt,
        endedAt: base.endedAt,
        distanceM: base.distanceM,
        maxSpeedKmh: base.maxSpeedKmh,
        avgSpeedKmh: base.avgSpeedKmh,
        lapSummaries: base.lapSummaries,
        sectorSummaries: base.sectorSummaries,
        manualSplitSummaries: manualSplitSummaries,
        telemetry: base.telemetry,
      );
    }

    return SessionRun(
      id: sessionId,
      routeTemplateId: route.id,
      installId: installId,
      status: SessionRunStatus.completed,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceM: snapshot.distanceM,
      maxSpeedKmh: snapshot.maxSpeedKmh,
      avgSpeedKmh: snapshot.averageSpeedKmh,
      lapSummaries: snapshot.lapSummaries,
      sectorSummaries: snapshot.sectorSummaries,
      manualSplitSummaries: manualSplitSummaries,
      telemetry: telemetry,
    );
  }

  @override
  Future<void> dispose() async {
    _uiTimer?.cancel();
    _trackingController.removeListener(_handleTrackingUpdate);
    await _trackingController.stopGpsTracking();
    _trackingController.dispose();
    super.dispose();
  }

  void _startTicker() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _elapsed = _stopwatch.elapsed;
      notifyListeners();
    });
  }

  void _handleTrackingUpdate() {
    final points = snapshot.telemetryPoints;
    if (points.isEmpty) {
      return;
    }

    _currentSpeedKmh = points.last.speedMps * 3.6;
    notifyListeners();
  }
}
