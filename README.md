# Carnometer

Carnometer is an Android-first proof of concept for timing car routes with custom sectors, local telemetry capture, and optional cloud sync.

## What is already in this repository

- `packages/carnometer_core`
  - Pure Dart domain models for routes, sectors, sessions, and telemetry.
  - A tested tracking engine that detects sectors and laps locally on-device.
- `apps/mobile`
  - Flutter app shell with route, session, and history tabs.
  - Local SQLite persistence for routes, sessions, and pending sync items.
  - Optional anonymous Supabase bootstrap and sync wiring.
  - Demo lap playback so the core timing flow can be exercised without driving.
- `supabase`
  - Initial Postgres/PostGIS schema.
  - Edge function scaffold for Mapbox Directions and Map Matching.

## Repository layout

```text
apps/mobile              Flutter shell
packages/carnometer_core Pure Dart timing engine and models
supabase                 SQL schema and edge functions
docs                     Architecture notes
```

## Verified in this environment

The following commands were run successfully during this session:

```bash
cd packages/carnometer_core
../../.tooling/dart-sdk/dart-sdk/bin/dart test
../../.tooling/dart-sdk/dart-sdk/bin/dart analyze

cd ../../apps/mobile
../../flutter/bin/flutter.bat test test/app_config_test.dart
../../flutter/bin/flutter.bat analyze
```

The Android shell has already been generated inside `apps/mobile/android`.

## Next steps

1. Install Flutter locally.
2. Install dependencies:

```bash
cd apps/mobile
flutter pub get
```

3. Run the app in local-only mode:

```bash
flutter run \
  --dart-define=MAPBOX_ACCESS_TOKEN=your-public-mapbox-token \
  --dart-define=MAPBOX_STYLE_URI=mapbox://styles/mapbox/streets-v12
```

4. Wire Supabase and Mapbox-backed routing when ready:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=MAPBOX_ACCESS_TOKEN=your-public-mapbox-token \
  --dart-define=MAPBOX_STYLE_URI=mapbox://styles/mapbox/streets-v12 \
  --dart-define=MAPBOX_BASE_URL=https://api.mapbox.com
```
