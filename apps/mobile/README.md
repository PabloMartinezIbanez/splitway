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

Before the first Android build, add your Mapbox downloads token to:

```text
%USERPROFILE%\.gradle\gradle.properties
```

with:

```properties
MAPBOX_DOWNLOADS_TOKEN=your-secret-mapbox-token-with-Downloads-Read
```

4. Run the app:

```bash
flutter run \
  --dart-define=MAPBOX_ACCESS_TOKEN=your-public-mapbox-token \
  --dart-define=MAPBOX_STYLE_URI=mapbox://styles/mapbox/streets-v12
```

You can also keep local defines in `env/local.json` and run:

```bash
flutter run --dart-define-from-file=env/local.json
```

Use `env/local.example.json` as the template.

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

For local Supabase on the Android emulator, `env/local.json` should look like:

```json
{
  "SUPABASE_URL": "http://10.0.2.2:54321",
  "SUPABASE_ANON_KEY": "your-local-publishable-key",
  "MAPBOX_ACCESS_TOKEN": "your-public-mapbox-token",
  "MAPBOX_STYLE_URI": "mapbox://styles/mapbox/streets-v12",
  "MAPBOX_BASE_URL": "https://api.mapbox.com"
}
```

For a physical Android device on the same Wi-Fi network as your PC, use the LAN IP of the computer that is running Supabase, for example:

```json
{
  "SUPABASE_URL": "http://192.168.0.101:54321",
  "SUPABASE_ANON_KEY": "your-local-publishable-key",
  "MAPBOX_ACCESS_TOKEN": "your-public-mapbox-token",
  "MAPBOX_STYLE_URI": "mapbox://styles/mapbox/streets-v12",
  "MAPBOX_BASE_URL": "https://api.mapbox.com"
}
```

Keep the phone and the PC on the same network and allow inbound traffic to port `54321` in the Windows firewall.
