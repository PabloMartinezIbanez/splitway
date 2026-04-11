class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.mapboxAccessToken,
    required this.mapboxStyleUri,
    required this.mapboxBaseUrl,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
        mapboxAccessToken: String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
        mapboxStyleUri: String.fromEnvironment(
          'MAPBOX_STYLE_URI',
          defaultValue: 'mapbox://styles/mapbox/streets-v12',
        ),
        mapboxBaseUrl: String.fromEnvironment(
          'MAPBOX_BASE_URL',
          defaultValue: 'https://api.mapbox.com',
        ),
      );

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String mapboxAccessToken;
  final String mapboxStyleUri;
  final String mapboxBaseUrl;

  bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get hasMapboxToken => mapboxAccessToken.isNotEmpty;
}
