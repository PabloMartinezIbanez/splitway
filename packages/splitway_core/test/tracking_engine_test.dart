import 'package:splitway_core/splitway_core.dart';
import 'package:test/test.dart';

RouteTemplate _buildTestRoute() {
  final start = const GateDefinition(
    left: GeoPoint(latitude: 0, longitude: -0.001),
    right: GeoPoint(latitude: 0, longitude: 0.001),
  );
  final s1 = SectorDefinition(
    id: 'sec-1',
    order: 0,
    label: 'Sector 1',
    gate: const GateDefinition(
      left: GeoPoint(latitude: 0.001, longitude: 0.0005),
      right: GeoPoint(latitude: 0.001, longitude: 0.0015),
    ),
  );
  final s2 = SectorDefinition(
    id: 'sec-2',
    order: 1,
    label: 'Sector 2',
    gate: const GateDefinition(
      left: GeoPoint(latitude: 0.0005, longitude: 0.002),
      right: GeoPoint(latitude: 0.0015, longitude: 0.002),
    ),
  );
  return RouteTemplate(
    id: 'route-test',
    name: 'Test loop',
    path: const [
      GeoPoint(latitude: 0, longitude: 0),
      GeoPoint(latitude: 0.001, longitude: 0.001),
      GeoPoint(latitude: 0.001, longitude: 0.002),
      GeoPoint(latitude: 0, longitude: 0),
    ],
    startFinishGate: start,
    sectors: [s1, s2],
    difficulty: RouteDifficulty.easy,
    createdAt: DateTime.parse('2026-04-29T10:00:00Z'),
  );
}

TelemetryPoint _p(double lat, double lng, DateTime t, {double speed = 10}) {
  return TelemetryPoint(
    timestamp: t,
    location: GeoPoint(latitude: lat, longitude: lng),
    speedMps: speed,
  );
}

void main() {
  test('engine emits started, sectorCrossed, lapClosed in order', () async {
    final route = _buildTestRoute();
    final base = DateTime.parse('2026-04-29T10:00:00Z');
    final engine =
        TrackingEngine(route: route, sessionId: 'sess-1', clock: () => base);
    final received = <TrackingEvent>[];
    engine.events.listen(received.add);

    engine.start();
    // Approach the start gate.
    engine.ingest(_p(-0.0005, 0, base));
    // Cross start gate (mid-gate at lng~0.0004).
    engine.ingest(_p(0.0005, 0.0008, base.add(const Duration(seconds: 1))));
    // Cross sector 1 gate (mid-gate at lng=0.0008).
    engine.ingest(_p(0.0015, 0.0008, base.add(const Duration(seconds: 4))));
    // Cross sector 2 gate.
    engine.ingest(_p(0.001, 0.0025, base.add(const Duration(seconds: 7))));
    // Cross start gate again to close lap 1.
    engine.ingest(_p(-0.0005, 0, base.add(const Duration(seconds: 10))));

    await Future<void>.delayed(Duration.zero);

    expect(received, isNotEmpty);
    expect(received.first, isA<TrackingStarted>());
    final sectorEvents = received.whereType<SectorCrossed>().toList();
    expect(sectorEvents.length, 2);
    expect(sectorEvents[0].sectorId, 'sec-1');
    expect(sectorEvents[1].sectorId, 'sec-2');
    final lapEvents = received.whereType<LapClosed>().toList();
    expect(lapEvents.length, 1);
    expect(lapEvents.first.lap.lapNumber, 1);
    expect(lapEvents.first.lap.duration, const Duration(seconds: 9));
    await engine.dispose();
  });

  test('engine ignores points before start() is called', () {
    final route = _buildTestRoute();
    final base = DateTime.parse('2026-04-29T10:00:00Z');
    final engine =
        TrackingEngine(route: route, sessionId: 'sess-2', clock: () => base);

    engine.ingest(_p(0.0005, 0, base));
    expect(engine.snapshot.status, TrackingStatus.idle);
    expect(engine.snapshot.totalDistanceMeters, 0);
  });

  test('finish() returns a SessionRun with the recorded laps', () async {
    final route = _buildTestRoute();
    final base = DateTime.parse('2026-04-29T10:00:00Z');
    final engine =
        TrackingEngine(route: route, sessionId: 'sess-3', clock: () => base);

    engine.start();
    engine.ingest(_p(-0.0005, 0, base));
    engine.ingest(_p(0.0005, 0.0008, base.add(const Duration(seconds: 1))));
    engine.ingest(_p(0.0015, 0.0008, base.add(const Duration(seconds: 4))));
    engine.ingest(_p(0.001, 0.0025, base.add(const Duration(seconds: 7))));
    engine.ingest(_p(-0.0005, 0, base.add(const Duration(seconds: 10))));

    final session = engine.finish();
    expect(session.id, 'sess-3');
    expect(session.routeTemplateId, route.id);
    expect(session.status, SessionStatus.completed);
    expect(session.laps.length, greaterThanOrEqualTo(1));
    expect(session.laps.first.completed, isTrue);
    expect(session.sectorSummaries.length, 2);
    expect(session.totalDistanceMeters, greaterThan(0));
    await engine.dispose();
  });

  test('finish() with an open lap marks it as incomplete', () async {
    final route = _buildTestRoute();
    final base = DateTime.parse('2026-04-29T10:00:00Z');
    final engine =
        TrackingEngine(route: route, sessionId: 'sess-4', clock: () => base);

    engine.start();
    engine.ingest(_p(-0.0005, 0, base));
    engine.ingest(_p(0.0005, 0.0008, base.add(const Duration(seconds: 1))));
    engine.ingest(_p(0.0015, 0.0008, base.add(const Duration(seconds: 4))));

    final session = engine.finish();
    expect(session.laps.length, 1);
    expect(session.laps.first.completed, isFalse);
    await engine.dispose();
  });
}
