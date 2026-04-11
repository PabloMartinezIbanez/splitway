import 'package:carnometer_core/carnometer_core.dart';
import 'package:test/test.dart';

void main() {
  group('TrackingEngine', () {
    test('records sector and lap summaries for a closed route', () {
      final engine = TrackingEngine(
        route: _closedRoute(),
        gateCooldown: const Duration(seconds: 2),
        gateProximityMeters: 80,
      );

      for (final point in _closedLapPoints()) {
        engine.addPoint(point);
      }

      final snapshot = engine.snapshot;

      expect(snapshot.sectorSummaries, hasLength(2));
      expect(snapshot.lapSummaries, hasLength(1));
      expect(snapshot.sectorSummaries[0].duration, const Duration(seconds: 20));
      expect(snapshot.sectorSummaries[1].duration, const Duration(seconds: 20));
      expect(snapshot.lapSummaries.single.duration, const Duration(seconds: 60));
      expect(snapshot.lapSummaries.single.lapNumber, 1);
      expect(snapshot.maxSpeedKmh, closeTo(90, 0.001));
    });

    test('does not create laps for an open route', () {
      final engine = TrackingEngine(
        route: _openRoute(),
        gateCooldown: const Duration(seconds: 2),
        gateProximityMeters: 80,
      );

      for (final point in _openRoutePoints()) {
        engine.addPoint(point);
      }

      final snapshot = engine.snapshot;

      expect(snapshot.sectorSummaries, hasLength(2));
      expect(snapshot.lapSummaries, isEmpty);
      expect(snapshot.sectorSummaries[0].lapNumber, isNull);
    });

    test('ignores gate jitter inside the cooldown window', () {
      final engine = TrackingEngine(
        route: _routeWithoutIntermediateSectors(),
        gateCooldown: const Duration(seconds: 5),
        gateProximityMeters: 80,
      );

      for (final point in _jitterPoints()) {
        engine.addPoint(point);
      }

      final snapshot = engine.snapshot;

      expect(snapshot.lapSummaries, hasLength(1));
      expect(snapshot.lapSummaries.single.duration, const Duration(seconds: 11));
    });
  });
}

RouteTemplate _closedRoute() {
  return RouteTemplate(
    id: 'closed',
    name: 'Closed route',
    difficulty: RouteDifficulty.medium,
    isClosed: true,
    rawGeometry: const [
      GeoPoint(latitude: -0.0002, longitude: 0),
      GeoPoint(latitude: 0.0022, longitude: 0),
      GeoPoint(latitude: -0.0002, longitude: 0),
    ],
    startFinishGate: _gate('start', 0),
    sectors: [
      SectorDefinition(
        id: 'sector-1',
        routeTemplateId: 'closed',
        order: 1,
        label: 'Sector 1',
        gate: _gate('sector-1', 0.001),
      ),
      SectorDefinition(
        id: 'sector-2',
        routeTemplateId: 'closed',
        order: 2,
        label: 'Sector 2',
        gate: _gate('sector-2', 0.002),
      ),
    ],
    createdAt: DateTime.utc(2026, 4, 10),
  );
}

RouteTemplate _openRoute() {
  return RouteTemplate(
    id: 'open',
    name: 'Open route',
    difficulty: RouteDifficulty.medium,
    isClosed: false,
    rawGeometry: const [
      GeoPoint(latitude: -0.0002, longitude: 0),
      GeoPoint(latitude: 0.0022, longitude: 0),
    ],
    startFinishGate: _gate('start', 0),
    sectors: [
      SectorDefinition(
        id: 'sector-1',
        routeTemplateId: 'open',
        order: 1,
        label: 'Sector 1',
        gate: _gate('sector-1', 0.001),
      ),
      SectorDefinition(
        id: 'sector-2',
        routeTemplateId: 'open',
        order: 2,
        label: 'Sector 2',
        gate: _gate('sector-2', 0.002),
      ),
    ],
    createdAt: DateTime.utc(2026, 4, 10),
  );
}

RouteTemplate _routeWithoutIntermediateSectors() {
  return RouteTemplate(
    id: 'jitter',
    name: 'Jitter route',
    difficulty: RouteDifficulty.medium,
    isClosed: true,
    rawGeometry: const [
      GeoPoint(latitude: -0.0002, longitude: 0),
      GeoPoint(latitude: 0.0002, longitude: 0),
    ],
    startFinishGate: _gate('start', 0),
    sectors: const [],
    createdAt: DateTime.utc(2026, 4, 10),
  );
}

GateDefinition _gate(String id, double latitude) {
  return GateDefinition(
    id: id,
    label: id,
    start: GeoPoint(latitude: latitude, longitude: -0.001),
    end: GeoPoint(latitude: latitude, longitude: 0.001),
  );
}

List<TelemetryPoint> _closedLapPoints() {
  final base = DateTime.utc(2026, 4, 10, 10);
  return [
    _point(base.add(const Duration(seconds: 0)), -0.0002, 0, 15),
    _point(base.add(const Duration(seconds: 10)), 0.0002, 0, 25),
    _point(base.add(const Duration(seconds: 20)), 0.0008, 0, 20),
    _point(base.add(const Duration(seconds: 30)), 0.0012, 0, 18),
    _point(base.add(const Duration(seconds: 40)), 0.0018, 0, 17),
    _point(base.add(const Duration(seconds: 50)), 0.0022, 0, 19),
    _point(base.add(const Duration(seconds: 60)), -0.0002, 0, 16),
    _point(base.add(const Duration(seconds: 70)), 0.0002, 0, 16),
  ];
}

List<TelemetryPoint> _openRoutePoints() {
  final base = DateTime.utc(2026, 4, 10, 11);
  return [
    _point(base.add(const Duration(seconds: 0)), -0.0002, 0, 10),
    _point(base.add(const Duration(seconds: 10)), 0.0002, 0, 12),
    _point(base.add(const Duration(seconds: 20)), 0.0008, 0, 13),
    _point(base.add(const Duration(seconds: 30)), 0.0012, 0, 13),
    _point(base.add(const Duration(seconds: 40)), 0.0018, 0, 15),
    _point(base.add(const Duration(seconds: 50)), 0.0022, 0, 16),
  ];
}

List<TelemetryPoint> _jitterPoints() {
  final base = DateTime.utc(2026, 4, 10, 12);
  return [
    _point(base.add(const Duration(seconds: 0)), -0.0002, 0, 10),
    _point(base.add(const Duration(seconds: 10)), 0.0002, 0, 12),
    _point(base.add(const Duration(seconds: 11)), -0.0002, 0, 12),
    _point(base.add(const Duration(seconds: 12)), 0.0002, 0, 12),
    _point(base.add(const Duration(seconds: 20)), -0.0002, 0, 12),
    _point(base.add(const Duration(seconds: 21)), 0.0002, 0, 12),
  ];
}

TelemetryPoint _point(DateTime timestamp, double latitude, double longitude, double speedMps) {
  return TelemetryPoint(
    timestamp: timestamp,
    latitude: latitude,
    longitude: longitude,
    speedMps: speedMps,
    accuracyM: 5,
    headingDeg: 0,
  );
}
