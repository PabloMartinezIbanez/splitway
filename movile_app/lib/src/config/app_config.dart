import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Runtime configuration loaded from `env/local.json` (bundled as an asset
/// in dev) or from --dart-define values in release. Iter 1 only reads it;
/// Mapbox + Supabase wiring happens in iter 2.
class AppConfig {
  const AppConfig({
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.mapboxToken,
    this.mapboxStyleUri,
    this.realGpsEnabled = false,
  });

  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final String? mapboxToken;
  final String? mapboxStyleUri;
  final bool realGpsEnabled;

  bool get hasSupabase =>
      (supabaseUrl?.isNotEmpty ?? false) &&
      (supabaseAnonKey?.isNotEmpty ?? false);

  bool get hasMapbox => mapboxToken?.isNotEmpty ?? false;

  static Future<AppConfig> load() async {
    Map<String, dynamic> data = const {};
    try {
      final raw = await rootBundle.loadString('env/local.json');
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // env/local.json is gitignored — absence is fine in CI / first run.
    }

    String? readEnv(String key) {
      const fromDefine = String.fromEnvironment;
      final fromDartDefine = fromDefine(key);
      if (fromDartDefine.isNotEmpty) return fromDartDefine;
      final value = data[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return AppConfig(
      supabaseUrl: readEnv('SUPABASE_URL'),
      supabaseAnonKey: readEnv('SUPABASE_ANON_KEY'),
      mapboxToken: readEnv('MAPBOX_ACCESS_TOKEN'),
      mapboxStyleUri: readEnv('MAPBOX_STYLE_URI'),
      realGpsEnabled: false,
    );
  }
}
