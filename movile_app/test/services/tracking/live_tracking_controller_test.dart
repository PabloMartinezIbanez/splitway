import 'package:flutter_test/flutter_test.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:splitway_mobile/src/services/tracking/live_tracking_controller.dart';

/// Builds a straight open-circuit [RouteTemplate] with [pointCount] path
/// points running due north from lat=40.0, spaced ~10 m apart.
///
/// The start/finish gate is centred on path[0] and is perpendicular to the
/// path direction (i.e. it runs east–west), matching Splitway's auto-generated
/// gate convention.
RouteTemplate _straightRoute({required int pointCount}) {
  // ~0.00009° latitude ≈ 10 m at equator-ish latitudes.
  const latStep = 0.00009;
  final path = List.generate(
    pointCount,
    (i) => GeoPoint(latitude: 40.0 + i * latStep, longitude: -3.0),
  );

  // Gate centred on path[0], perpendicular to path (east–west).
  const gateSide = 0.0001; // ~11 m half-width
  final gate = GateDefinition(
    left: GeoPoint(
      latitude: path[0].latitude,
      longitude: path[0].longitude - gateSide,
    ),
    right: GeoPoint(
      latitude: path[0].latitude,
      longitude: path[0].longitude + gateSide,
    ),
  );

  return RouteTemplate(
    id: 'test-route',
    name: 'Test route',
    path: path,
    startFinishGate: gate,
    sectors: const [],
    difficulty: RouteDifficulty.easy,
    createdAt: DateTime(2026),
  );
}

void main() {
  group('buildAutoLapScript / _samplePath (indirect)', () {
    final startTime = DateTime(2026, 5, 9, 10);

    test('returns empty list for a path with fewer than 3 points', () {
      // 2-point path is degenerate — must return [].
      final route = _straightRoute(pointCount: 2);
      final controller = LiveTrackingController(route: route);
      final script = controller.buildAutoLapScript(startTime: startTime);
      expect(script, isEmpty);
      controller.dispose();
    });

    test(
      'path shorter than maxPathPoints: all path points used as circuit points',
      () {
        // 5-point path, max=50 → sampled = all 5 points.
        // Open circuit: circuitPoints = sampled.skip(1) → 4 points.
        // geo = [pBefore] + 4 circuit + [pBefore] = 6 points for lapCount=1.
        const pointCount = 5;
        final route = _straightRoute(pointCount: pointCount);
        final controller = LiveTrackingController(route: route);
        final script = controller.buildAutoLapScript(
          startTime: startTime,
          lapCount: 1,
          maxPathPoints: 50,
        );
        // 1 (entry pBefore) + (pointCount - 1) (circuit) + 1 (close pBefore) = pointCount + 1
        expect(script.length, pointCount + 1);
        controller.dispose();
      },
    );

    test(
      'path longer than maxPathPoints: exactly maxPathPoints are sampled',
      () {
        // 100-point path, maxPathPoints=3 (first, mid, last).
        // Open circuit: circuitPoints = sampled.skip(1) → 2 points.
        // geo for lapCount=1: [pBefore, pt1, pt2, pBefore] = 4 points.
        const pointCount = 100;
        const max = 3;
        final route = _straightRoute(pointCount: pointCount);
        final controller = LiveTrackingController(route: route);
        final script = controller.buildAutoLapScript(
          startTime: startTime,
          lapCount: 1,
          maxPathPoints: max,
        );
        // 1 (entry) + (max - 1) (circuit) + 1 (close) = max + 1
        expect(script.length, max + 1);
        controller.dispose();
      },
    );

    test(
      'maxPathPoints == 2: sampled is [first, last], script has 3 points',
      () {
        // 100-point path, max=2 → sampled = [path[0], path[99]].
        // Open circuit: circuitPoints = [path[99]] (skip first).
        // geo = [pBefore, path[99], pBefore] = 3 points.
        final route = _straightRoute(pointCount: 100);
        final controller = LiveTrackingController(route: route);
        final script = controller.buildAutoLapScript(
          startTime: startTime,
          lapCount: 1,
          maxPathPoints: 2,
        );
        expect(script.length, 3);
        controller.dispose();
      },
    );

    test('lapCount=3 produces 3x the circuit points plus entry + 3 closings',
        () {
      // 5-point path, max=50, lapCount=3.
      // circuitPoints = 4; geo = [pBefore] + 3*(4 + [pBefore]) = 1 + 3*5 = 16.
      const pointCount = 5;
      final route = _straightRoute(pointCount: pointCount);
      final controller = LiveTrackingController(route: route);
      final script = controller.buildAutoLapScript(
        startTime: startTime,
        lapCount: 3,
        maxPathPoints: 50,
      );
      const circuitLen = pointCount - 1; // 4
      expect(script.length, 1 + 3 * (circuitLen + 1)); // 1 + 3*5 = 16
      controller.dispose();
    });

    test('timestamps are monotonically increasing and spaced by intervalMs',
        () {
      final route = _straightRoute(pointCount: 5);
      final controller = LiveTrackingController(route: route);
      const interval = 500;
      final script = controller.buildAutoLapScript(
        startTime: startTime,
        lapCount: 1,
        intervalMs: interval,
      );
      for (var i = 1; i < script.length; i++) {
        final diff =
            script[i].timestamp.difference(script[i - 1].timestamp).inMilliseconds;
        expect(diff, interval);
      }
      controller.dispose();
    });
  });
}
