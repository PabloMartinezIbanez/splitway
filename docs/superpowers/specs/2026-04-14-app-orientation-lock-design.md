# App Orientation Lock Design

Date: 2026-04-14

## Goal

Prevent the mobile app from rotating by locking the entire Flutter application to `DeviceOrientation.portraitUp`.

## Scope

This design applies to:

- `apps/mobile/lib/main.dart`
- `apps/mobile/test/main_test.dart`

It does not introduce per-screen orientation rules or native platform manifest changes.

## Decision

Use a global Flutter-side orientation lock during app startup.

The app entrypoint already centralizes initialization in `main()`, so the orientation preference will be set immediately after `WidgetsFlutterBinding.ensureInitialized()` and before `runApp(...)`.

## Alternatives Considered

### Per-screen orientation locking

Rejected because the requirement is app-wide and this would add lifecycle complexity without benefit.

### Native Android and iOS orientation locking

Rejected because the Flutter entrypoint already provides a single cross-platform control point for the current requirement.

## Expected Behavior

- The app launches in portrait orientation.
- Device rotation does not switch the UI into landscape.
- Existing bootstrap behavior, locale initialization, and routing remain unchanged.

## Testing Strategy

- Add a test that calls `main()` and verifies `SystemChrome.setPreferredOrientations` is invoked with only `DeviceOrientation.portraitUp`.
- Re-run the targeted mobile tests after the implementation change.

## Non-Goals

- Supporting `portraitDown`
- Allowing route-specific orientation overrides
- Changing Android or iOS native configuration files
