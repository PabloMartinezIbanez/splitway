import 'package:carnometer_core/carnometer_core.dart';
import 'package:test/test.dart';

void main() {
  group('RouteTemplate', () {
    test('serializes and restores route difficulty', () {
      final route = RouteTemplate(
        id: 'route-1',
        name: 'Madrid ring',
        difficulty: RouteDifficulty.expert,
        isClosed: true,
        rawGeometry: const [
          GeoPoint(latitude: 40.0, longitude: -3.7),
          GeoPoint(latitude: 40.1, longitude: -3.6),
        ],
        startFinishGate: GateDefinition(
          id: 'start-finish',
          label: 'Start / finish',
          start: const GeoPoint(latitude: 40.0, longitude: -3.705),
          end: const GeoPoint(latitude: 40.0, longitude: -3.695),
        ),
        sectors: const [],
        notes: 'Test route',
        createdAt: DateTime.utc(2026, 4, 10),
      );

      final json = route.toJson();
      final restored = RouteTemplate.fromJson(json);

      expect(json['difficulty'], 'expert');
      expect(restored.difficulty, RouteDifficulty.expert);
    });

    test('defaults missing difficulty to medium for legacy routes', () {
      final restored = RouteTemplate.fromJson({
        'id': 'legacy-route',
        'name': 'Legacy route',
        'isClosed': false,
        'rawGeometry': const [
          {'latitude': 40.0, 'longitude': -3.7},
          {'latitude': 40.1, 'longitude': -3.6},
        ],
        'startFinishGate': const {
          'id': 'start-finish',
          'label': 'Start / finish',
          'start': {'latitude': 40.0, 'longitude': -3.705},
          'end': {'latitude': 40.0, 'longitude': -3.695},
        },
        'sectors': const [],
        'createdAt': '2026-04-10T00:00:00.000Z',
      });

      expect(restored.difficulty, RouteDifficulty.medium);
    });

    test('prefers snapped geometry when available', () {
      final route = RouteTemplate(
        id: 'route-1',
        name: 'Madrid ring',
        difficulty: RouteDifficulty.medium,
        isClosed: true,
        rawGeometry: const [
          GeoPoint(latitude: 40.0, longitude: -3.7),
          GeoPoint(latitude: 40.1, longitude: -3.6),
        ],
        snappedGeometry: const [
          GeoPoint(latitude: 40.0, longitude: -3.71),
          GeoPoint(latitude: 40.1, longitude: -3.61),
        ],
        startFinishGate: GateDefinition(
          id: 'start-finish',
          label: 'Start / finish',
          start: const GeoPoint(latitude: 40.0, longitude: -3.705),
          end: const GeoPoint(latitude: 40.0, longitude: -3.695),
        ),
        sectors: const [],
        notes: 'Test route',
        createdAt: DateTime.utc(2026, 4, 10),
      );

      expect(route.effectiveGeometry, hasLength(2));
      expect(route.effectiveGeometry.first.longitude, closeTo(-3.71, 0.0001));
    });
  });
}
