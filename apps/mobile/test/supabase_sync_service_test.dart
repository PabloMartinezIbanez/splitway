import 'package:splitway_mobile/src/data/repositories/supabase_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses GeoJSON line string coordinates into geo points', () {
    const service = SupabaseSyncService(
      client: null,
      mapboxBaseUrl: 'https://api.mapbox.com',
    );

    final geometry = service.parseGeometry({
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [-3.7038, 40.4168],
          [-3.7025, 40.4175],
        ],
      },
    });

    expect(geometry, hasLength(2));
    final firstPoint = geometry!.first;
    expect(firstPoint.latitude, closeTo(40.4168, 0.000001));
    expect(firstPoint.longitude, closeTo(-3.7038, 0.000001));
  });
}
