# Carnometer Mobile

Flutter shell for the Android-first Carnometer PoC.

## Current scope

- Bootstraps anonymous Supabase auth when credentials are provided.
- Stores routes and sessions locally in SQLite.
- Shows a map canvas with a route editor shell.
- Lets you replay a demo lap to validate the tracking engine indoors.
- Exposes clear integration points for real GPS tracking and sync.

## First run

1. Install Flutter locally.
2. From `apps/mobile`, generate the native Android shell if it is still missing:

```bash
flutter create . --platforms=android
```

3. Install dependencies:

```bash
flutter pub get
```

4. Run the app:

```bash
flutter run \
  --dart-define=MAPBOX_ACCESS_TOKEN=your-public-mapbox-token \
  --dart-define=MAPBOX_STYLE_URI=mapbox://styles/mapbox/streets-v12
```

## Optional backend wiring

Add the following defines when you are ready to wire Supabase and Mapbox-backed routing:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=MAPBOX_ACCESS_TOKEN=your-public-mapbox-token \
  --dart-define=MAPBOX_STYLE_URI=mapbox://styles/mapbox/streets-v12 \
  --dart-define=MAPBOX_BASE_URL=https://api.mapbox.com
```
