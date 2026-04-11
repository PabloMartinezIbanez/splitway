import 'package:carnometer_mobile/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('uses Mapbox defaults when no defines are provided', () {
      final config = AppConfig.fromEnvironment();

      expect(config.mapboxAccessToken, isEmpty);
      expect(config.mapboxBaseUrl, 'https://api.mapbox.com');
      expect(config.mapboxStyleUri, 'mapbox://styles/mapbox/streets-v12');
      expect(config.hasMapboxToken, isFalse);
    });
  });
}
