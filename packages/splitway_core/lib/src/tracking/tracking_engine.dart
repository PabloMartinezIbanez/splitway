import 'dart:math' as math;

import '../models/gate_definition.dart';
import '../models/lap_summary.dart';
import '../models/route_template.dart';
import '../models/sector_definition.dart';
import '../models/sector_summary.dart';
import '../models/session_run.dart';
import '../models/telemetry_point.dart';
import '../models/tracking_snapshot.dart';

class TrackingEngine {
  TrackingEngine({
    required this.route,
    this.gateCooldown = const Duration(seconds: 2),
    this.gateProximityMeters = 40,
  });

  final RouteTemplate route;
  final Duration gateCooldown;
  final double gateProximityMeters;

  final List<TelemetryPoint> _telemetryPoints = [];
  final List<SectorSummary> _sectorSummaries = [];
  final List<LapSummary> _lapSummaries = [];
  final Map<String, DateTime> _gateTriggerTimes = {};

  TelemetryPoint? _previousPoint;
  double _distanceM = 0;
  double _maxSpeedKmh = 0;

  bool _lapArmed = false;
  int _nextSectorIndex = 0;
  int _currentLapNumber = 0;
  DateTime? _lapStartedAt;
  DateTime? _segmentStartedAt;
  List<TelemetryPoint> _currentLapPoints = [];
  List<TelemetryPoint> _currentSegmentPoints = [];

  TrackingSnapshot get snapshot {
    return TrackingSnapshot(
      telemetryPoints: List.unmodifiable(_telemetryPoints),
      sectorSummaries: List.unmodifiable(_sectorSummaries),
      lapSummaries: List.unmodifiable(_lapSummaries),
      distanceM: _distanceM,
      maxSpeedKmh: _maxSpeedKmh,
      averageSpeedKmh: _averageSpeedKmh(_telemetryPoints),
      isLapArmed: _lapArmed,
      nextSectorIndex: _nextSectorIndex,
    );
  }

  void addPoint(TelemetryPoint point) {
    final previous = _previousPoint;

    _telemetryPoints.add(point);
    _maxSpeedKmh = math.max(_maxSpeedKmh, point.speedKmh);

    if (_lapArmed) {
      _currentLapPoints.add(point);
    }

    if (!route.isClosed || _lapArmed || _currentSegmentPoints.isNotEmpty) {
      _currentSegmentPoints.add(point);
    }

    if (previous != null) {
      _distanceM += _distanceBetweenPoints(previous, point);
      _handleGateLogic(previous, point);
    } else if (!route.isClosed) {
      _segmentStartedAt = point.timestamp;
    }

    _previousPoint = point;
  }

  SessionRun buildCompletedSession({
    required String sessionId,
    required String installId,
  }) {
    if (_telemetryPoints.isEmpty) {
      throw StateError('Cannot build a session without telemetry.');
    }

    return SessionRun(
      id: sessionId,
      routeTemplateId: route.id,
      installId: installId,
      status: SessionRunStatus.completed,
      startedAt: _telemetryPoints.first.timestamp,
      endedAt: _telemetryPoints.last.timestamp,
      distanceM: _distanceM,
      maxSpeedKmh: _maxSpeedKmh,
      avgSpeedKmh: _averageSpeedKmh(_telemetryPoints),
      lapSummaries: List.unmodifiable(_lapSummaries),
      sectorSummaries: List.unmodifiable(_sectorSummaries),
      manualSplitSummaries: const [],
      telemetry: List.unmodifiable(_telemetryPoints),
    );
  }

  void _handleGateLogic(TelemetryPoint previous, TelemetryPoint current) {
    if (route.isClosed) {
      _handleClosedRoute(previous, current);
      return;
    }

    _handleOpenRoute(previous, current);
  }

  void _handleClosedRoute(TelemetryPoint previous, TelemetryPoint current) {
    if (!_lapArmed) {
      if (_crossesGate(previous, current, route.startFinishGate)) {
        _armLap(current);
      }
      return;
    }

    if (_nextSectorIndex < route.sectors.length) {
      final sector = route.sectors[_nextSectorIndex];
      if (_crossesGate(previous, current, sector.gate)) {
        _recordSector(sector, current, lapNumber: _currentLapNumber);
        _nextSectorIndex += 1;
      }
      return;
    }

    if (_crossesGate(previous, current, route.startFinishGate)) {
      _recordLap(current);
      _armLap(current);
    }
  }

  void _handleOpenRoute(TelemetryPoint previous, TelemetryPoint current) {
    if (_segmentStartedAt == null) {
      _segmentStartedAt = _telemetryPoints.first.timestamp;
    }

    if (_nextSectorIndex >= route.sectors.length) {
      return;
    }

    final sector = route.sectors[_nextSectorIndex];
    if (_crossesGate(previous, current, sector.gate)) {
      _recordSector(sector, current);
      _nextSectorIndex += 1;
    }
  }

  void _armLap(TelemetryPoint triggerPoint) {
    _lapArmed = true;
    _nextSectorIndex = 0;
    _currentLapNumber = _lapSummaries.length + 1;
    _lapStartedAt = triggerPoint.timestamp;
    _segmentStartedAt = triggerPoint.timestamp;
    _currentLapPoints = [triggerPoint];
    _currentSegmentPoints = [triggerPoint];
  }

  void _recordSector(
    SectorDefinition sector,
    TelemetryPoint triggerPoint, {
    int? lapNumber,
  }) {
    final startedAt = _segmentStartedAt ?? triggerPoint.timestamp;
    final segmentPoints = List<TelemetryPoint>.unmodifiable(_currentSegmentPoints);

    _sectorSummaries.add(
      SectorSummary(
        sectorId: sector.id,
        label: sector.label,
        order: sector.order,
        lapNumber: lapNumber,
        duration: triggerPoint.timestamp.difference(startedAt),
        crossedAt: triggerPoint.timestamp,
        averageSpeedKmh: _averageSpeedKmh(segmentPoints),
        maxSpeedKmh: _maxSpeedKmhForPoints(segmentPoints),
      ),
    );

    _segmentStartedAt = triggerPoint.timestamp;
    _currentSegmentPoints = [triggerPoint];
  }

  void _recordLap(TelemetryPoint triggerPoint) {
    final startedAt = _lapStartedAt ?? triggerPoint.timestamp;
    final lapPoints = List<TelemetryPoint>.unmodifiable(_currentLapPoints);

    _lapSummaries.add(
      LapSummary(
        lapNumber: _currentLapNumber,
        duration: triggerPoint.timestamp.difference(startedAt),
        completedAt: triggerPoint.timestamp,
        averageSpeedKmh: _averageSpeedKmh(lapPoints),
        maxSpeedKmh: _maxSpeedKmhForPoints(lapPoints),
      ),
    );
  }

  bool _crossesGate(
    TelemetryPoint previous,
    TelemetryPoint current,
    GateDefinition gate,
  ) {
    final lastTriggeredAt = _gateTriggerTimes[gate.id];
    if (lastTriggeredAt != null &&
        current.timestamp.difference(lastTriggeredAt) < gateCooldown) {
      return false;
    }

    final previousSide = _sideOfGate(previous, gate);
    final currentSide = _sideOfGate(current, gate);

    final crossesForward = previousSide <= 0 && currentSide > 0;
    final crossesReverse = previousSide >= 0 && currentSide < 0;

    final directionHint = gate.directionHint?.toLowerCase();
    final matchesDirection = switch (directionHint) {
      'reverse' => crossesReverse,
      'either' => crossesForward || crossesReverse,
      _ => crossesForward,
    };

    if (!matchesDirection) {
      return false;
    }

    final previousDistance = _distanceToGateMeters(previous, gate);
    final currentDistance = _distanceToGateMeters(current, gate);
    if (math.min(previousDistance, currentDistance) > gateProximityMeters) {
      return false;
    }

    _gateTriggerTimes[gate.id] = current.timestamp;
    return true;
  }

  double _sideOfGate(TelemetryPoint point, GateDefinition gate) {
    final x1 = gate.start.longitude;
    final y1 = gate.start.latitude;
    final x2 = gate.end.longitude;
    final y2 = gate.end.latitude;
    final x = point.longitude;
    final y = point.latitude;
    return ((x2 - x1) * (y - y1)) - ((y2 - y1) * (x - x1));
  }

  double _distanceToGateMeters(TelemetryPoint point, GateDefinition gate) {
    final referenceLatitude =
        (gate.start.latitude + gate.end.latitude + point.latitude) / 3;
    final start = _project(gate.start.latitude, gate.start.longitude, referenceLatitude);
    final end = _project(gate.end.latitude, gate.end.longitude, referenceLatitude);
    final target = _project(point.latitude, point.longitude, referenceLatitude);

    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final denominator = (dx * dx) + (dy * dy);
    if (denominator == 0) {
      return math.sqrt(
        math.pow(target.x - start.x, 2) + math.pow(target.y - start.y, 2),
      );
    }

    final t = (((target.x - start.x) * dx) + ((target.y - start.y) * dy)) / denominator;
    final clampedT = t.clamp(0.0, 1.0);
    final projectedX = start.x + (dx * clampedT);
    final projectedY = start.y + (dy * clampedT);

    return math.sqrt(
      math.pow(target.x - projectedX, 2) + math.pow(target.y - projectedY, 2),
    );
  }

  double _distanceBetweenPoints(TelemetryPoint left, TelemetryPoint right) {
    final referenceLatitude = (left.latitude + right.latitude) / 2;
    final start = _project(left.latitude, left.longitude, referenceLatitude);
    final end = _project(right.latitude, right.longitude, referenceLatitude);

    return math.sqrt(
      math.pow(end.x - start.x, 2) + math.pow(end.y - start.y, 2),
    );
  }

  _ProjectedPoint _project(double latitude, double longitude, double referenceLatitude) {
    const metersPerDegree = 111320.0;
    final x = longitude *
        metersPerDegree *
        math.cos(referenceLatitude * math.pi / 180);
    final y = latitude * metersPerDegree;
    return _ProjectedPoint(x: x, y: y);
  }

  double _averageSpeedKmh(List<TelemetryPoint> points) {
    if (points.length < 2) {
      return points.isEmpty ? 0 : points.single.speedKmh;
    }

    final distance = _distanceForPoints(points);
    final durationSeconds =
        points.last.timestamp.difference(points.first.timestamp).inMilliseconds / 1000;
    if (durationSeconds <= 0) {
      return 0;
    }

    return (distance / durationSeconds) * 3.6;
  }

  double _distanceForPoints(List<TelemetryPoint> points) {
    if (points.length < 2) {
      return 0;
    }

    var distance = 0.0;
    for (var index = 1; index < points.length; index += 1) {
      distance += _distanceBetweenPoints(points[index - 1], points[index]);
    }
    return distance;
  }

  double _maxSpeedKmhForPoints(List<TelemetryPoint> points) {
    if (points.isEmpty) {
      return 0;
    }

    return points.fold<double>(
      0,
      (currentMax, point) => math.max(currentMax, point.speedKmh),
    );
  }
}

class _ProjectedPoint {
  const _ProjectedPoint({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;
}
