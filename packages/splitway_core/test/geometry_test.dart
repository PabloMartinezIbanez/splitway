import 'package:splitway_core/splitway_core.dart';
import 'package:test/test.dart';

void main() {
  group('segmentsIntersect', () {
    test('crosses when segments form an X', () {
      final a1 = const GeoPoint(latitude: 0, longitude: 0);
      final a2 = const GeoPoint(latitude: 1, longitude: 1);
      final b1 = const GeoPoint(latitude: 0, longitude: 1);
      final b2 = const GeoPoint(latitude: 1, longitude: 0);
      expect(segmentsIntersect(a1, a2, b1, b2), isTrue);
    });

    test('does not cross when segments are parallel', () {
      final a1 = const GeoPoint(latitude: 0, longitude: 0);
      final a2 = const GeoPoint(latitude: 0, longitude: 1);
      final b1 = const GeoPoint(latitude: 1, longitude: 0);
      final b2 = const GeoPoint(latitude: 1, longitude: 1);
      expect(segmentsIntersect(a1, a2, b1, b2), isFalse);
    });

    test('does not cross when segments are far apart', () {
      final a1 = const GeoPoint(latitude: 0, longitude: 0);
      final a2 = const GeoPoint(latitude: 0.0001, longitude: 0.0001);
      final b1 = const GeoPoint(latitude: 5, longitude: 5);
      final b2 = const GeoPoint(latitude: 5, longitude: 6);
      expect(segmentsIntersect(a1, a2, b1, b2), isFalse);
    });

    test('collinear overlap is treated as no-cross', () {
      final a1 = const GeoPoint(latitude: 0, longitude: 0);
      final a2 = const GeoPoint(latitude: 0, longitude: 2);
      final b1 = const GeoPoint(latitude: 0, longitude: 1);
      final b2 = const GeoPoint(latitude: 0, longitude: 3);
      expect(segmentsIntersect(a1, a2, b1, b2), isFalse);
    });

    test('endpoint touching the other segment counts as no-cross', () {
      // Strict crossing only — touching corners should not fire.
      final a1 = const GeoPoint(latitude: 0, longitude: 0);
      final a2 = const GeoPoint(latitude: 1, longitude: 1);
      final b1 = const GeoPoint(latitude: 1, longitude: 1);
      final b2 = const GeoPoint(latitude: 2, longitude: 0);
      expect(segmentsIntersect(a1, a2, b1, b2), isFalse);
    });
  });

  group('GateDefinition.crossedBy', () {
    test('detects a perpendicular cross', () {
      final gate = const GateDefinition(
        left: GeoPoint(latitude: 0, longitude: -1),
        right: GeoPoint(latitude: 0, longitude: 1),
      );
      final from = const GeoPoint(latitude: -1, longitude: 0);
      final to = const GeoPoint(latitude: 1, longitude: 0);
      expect(gate.crossedBy(from, to), isTrue);
    });

    test('does not fire for parallel motion', () {
      final gate = const GateDefinition(
        left: GeoPoint(latitude: 0, longitude: -1),
        right: GeoPoint(latitude: 0, longitude: 1),
      );
      final from = const GeoPoint(latitude: 0.0001, longitude: -0.5);
      final to = const GeoPoint(latitude: 0.0001, longitude: 0.5);
      expect(gate.crossedBy(from, to), isFalse);
    });
  });

  group('GeoPoint.distanceTo', () {
    test('haversine returns ~111km for one degree of latitude', () {
      final a = const GeoPoint(latitude: 0, longitude: 0);
      final b = const GeoPoint(latitude: 1, longitude: 0);
      final d = a.distanceTo(b);
      expect(d, inInclusiveRange(110000, 112000));
    });

    test('returns 0 for the same point', () {
      final a = const GeoPoint(latitude: 40.0, longitude: -3.0);
      expect(a.distanceTo(a), 0);
    });
  });
}
