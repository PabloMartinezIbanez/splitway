# Language Selection & Internationalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Spanish/English language selection system to the Splitway mobile app, migrating every user-facing string from hard-coded Spanish to `flutter_localizations` ARB files, with the user choice persisted in `shared_preferences`.

**Architecture:** Three phases.
- **Phase A (Infrastructure):** wire `flutter_localizations` + `gen-l10n`, create both ARB files with the complete key catalog up-front, add a `LocaleController` (ChangeNotifier backed by `shared_preferences`), wire `MaterialApp.router`, build a `SettingsScreen` with the language picker, and route to it from the drawer.
- **Phase B (String migration):** screen-by-screen, replace literal strings with `AppLocalizations.of(context).<key>`. Each screen migration is one task with a smoke test verifying both locales render.
- **Phase C (Cleanup):** make `Formatters` locale-aware (date locale via `Intl.defaultLocale`, unit strings via ARB), convert `AuthService` error messages from Spanish literals to `AuthErrorCode` enum values translated in the UI, and update all existing tests that match hard-coded Spanish.

**Tech Stack:** Flutter (Material 3), `flutter_localizations` SDK, `intl: ^0.20.0` (already a dep), `shared_preferences` (new), Dart `gen-l10n` toolchain, `go_router`. Existing app uses `MaterialApp.router` and a `StatefulShellRoute` — the locale flows from `LocaleController` into `MaterialApp.router.locale` via `ListenableBuilder`.

---

## Background — why this plan looks the way it does

1. **All current strings are hard-coded Spanish.** There is no existing l10n infrastructure (`pubspec.yaml` does not reference `flutter_localizations`, no `l10n.yaml`). Every screen will be touched.
2. **`AuthService` throws / stores Spanish error strings** (`_friendlyAuthError`, `_friendlyError`). Because those run with no `BuildContext`, we cannot call `AppLocalizations.of(context)` there — the service must expose stable `AuthErrorCode` enum values; the `LoginScreen` translates the code to a localized message.
3. **`Formatters` is a static utility with `'es_ES'` hard-coded** in `DateFormat(..., 'es_ES')`. Switching to `DateFormat(pattern)` (no locale arg) uses `Intl.defaultLocale`, which `LocaleController` sets on every locale change.
4. **Tests assert hard-coded Spanish.** `widget_test.dart:148` and `integration_test/app_test.dart` (multiple lines) match literal Spanish. They must be updated to fetch keys from the loaded `AppLocalizations` (or pump the widget tree under `Locale('es')` and use the same Spanish string from the ARB file — which is the simpler path; we'll keep `es` as the test locale).
5. **Plurals exist:** `{count} puntos`, `{count} sectores`, `{lapCount} vuelta(s)` need ICU `plural{}` syntax in ARB.
6. **`requireAuth` in `app_router.dart` passes a Spanish banner message via URL query param** (`/login?message=...`). After this work the *caller* will pass a localized message resolved from its own `context`, and the router will not need to know the message contents.

---

## File Map

### New files
| File | Purpose |
|---|---|
| `movile_app/l10n.yaml` | gen-l10n config: ARB dir, template, output class |
| `movile_app/lib/l10n/app_en.arb` | English translations (template) |
| `movile_app/lib/l10n/app_es.arb` | Spanish translations |
| `movile_app/lib/src/services/locale/locale_controller.dart` | `ChangeNotifier` holding current `Locale`; reads/writes `shared_preferences` |
| `movile_app/lib/src/services/auth/auth_error_code.dart` | `AuthErrorCode` enum + helper |
| `movile_app/lib/src/features/settings/settings_screen.dart` | Settings screen with language picker |
| `movile_app/test/services/locale/locale_controller_test.dart` | Unit tests for `LocaleController` |
| `movile_app/test/features/settings/settings_screen_test.dart` | Widget test for the language picker |

### Modified files
| File | Change |
|---|---|
| `movile_app/pubspec.yaml` | Add `shared_preferences`, `flutter_localizations` SDK dep, enable `flutter.generate: true` |
| `movile_app/lib/main.dart` | Initialize date formatting for both locales, construct `LocaleController` and pass to `SplitwayApp` |
| `movile_app/lib/src/app.dart` | Accept `LocaleController`, wrap `MaterialApp.router` in `ListenableBuilder`, configure `localizationsDelegates`, `supportedLocales`, `locale` |
| `movile_app/lib/src/routing/app_router.dart` | Pass `LocaleController` into the tree; add `/settings` route; rewrite `requireAuth` to take a `bannerMessage` already localized by the caller |
| `movile_app/lib/src/shared/widgets/app_drawer.dart` | Localize strings, wire "Configuración" menu item to `context.go('/settings')` |
| `movile_app/lib/src/features/home/home_shell.dart` | Localize nav labels, drawer tooltips |
| `movile_app/lib/src/features/auth/login_screen.dart` | Localize all strings, translate `AuthErrorCode` to localized messages |
| `movile_app/lib/src/features/editor/route_editor_screen.dart` | Localize all strings |
| `movile_app/lib/src/features/history/history_screen.dart` | Localize all strings |
| `movile_app/lib/src/features/session/live_session_screen.dart` | Localize all strings |
| `movile_app/lib/src/shared/formatters.dart` | Drop hard-coded `'es_ES'`; accept locale-aware unit labels via parameter or `AppLocalizations` extension |
| `movile_app/lib/src/services/auth/auth_service.dart` | Replace `String? error` with `AuthErrorCode? errorCode`; keep `error` as a localized convenience that *callers* (with context) resolve |
| `movile_app/test/widget_test.dart` | Set `MaterialApp.locale = const Locale('es')` so existing Spanish assertions keep working |
| `movile_app/integration_test/app_test.dart` | Same — keep Spanish as the test locale |

---

## Phase A — Infrastructure

### Task 1: Add dependencies and enable `flutter.generate`

**Files:**
- Modify: `movile_app/pubspec.yaml`

- [ ] **Step 1: Edit `pubspec.yaml`**

In the `dependencies:` block, immediately after `flutter: sdk: flutter`, add:

```yaml
  flutter_localizations:
    sdk: flutter
  shared_preferences: ^2.3.0
```

In the bottom `flutter:` block, *before* the `assets:` list, add:

```yaml
  generate: true
```

The final `flutter:` block should look like:

```yaml
flutter:
  uses-material-design: true
  generate: true
  # env/local.json is gitignored. Copy env/local.example.json to env/local.json
  # and uncomment the entry below to bundle real Mapbox/Supabase credentials.
  assets:
    - env/local.json
```

- [ ] **Step 2: Run `flutter pub get`**

Run from `movile_app/`:

```bash
flutter pub get
```

Expected: success, no errors. `shared_preferences` and `flutter_localizations` appear in `pubspec.lock`.

- [ ] **Step 3: Commit**

```bash
git add movile_app/pubspec.yaml movile_app/pubspec.lock
git commit -m "build: add flutter_localizations and shared_preferences for i18n"
```

---

### Task 2: Create `l10n.yaml` and both ARB files with the full key catalog

**Files:**
- Create: `movile_app/l10n.yaml`
- Create: `movile_app/lib/l10n/app_en.arb`
- Create: `movile_app/lib/l10n/app_es.arb`

This task seeds **every key** we will use across the app so subsequent migration tasks just reference them. The English ARB is the template (it carries `@meta` blocks); the Spanish ARB is values-only.

- [ ] **Step 1: Create `movile_app/l10n.yaml`**

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

- [ ] **Step 2: Create `movile_app/lib/l10n/app_en.arb`**

```json
{
  "@@locale": "en",

  "appTitle": "Splitway",
  "appTagline": "Smart stopwatch for routes",

  "commonCancel": "Cancel",
  "commonDelete": "Delete",
  "commonBack": "Back",
  "commonSave": "Save",
  "commonClose": "Got it",
  "commonRefresh": "Refresh",
  "commonDiscard": "Discard",

  "languageEnglish": "English",
  "languageSpanish": "Spanish",

  "navEditor": "Editor",
  "navSession": "Session",
  "navHistory": "History",

  "drawerMenu": "Menu",
  "drawerDefaultUser": "User",
  "drawerSettings": "Settings",
  "drawerStats": "Statistics",
  "drawerHelp": "Help",
  "drawerSignOut": "Sign out",
  "drawerSignIn": "Sign in",
  "drawerAppVersion": "v{version}",
  "@drawerAppVersion": { "placeholders": { "version": { "type": "String" } } },
  "drawerSyncSynced": "SYNCED",
  "drawerSyncSyncedNow": "SYNCED · now",
  "drawerSyncSyncedMinutes": "SYNCED · {minutes} min ago",
  "@drawerSyncSyncedMinutes": { "placeholders": { "minutes": { "type": "int" } } },
  "drawerSyncSyncedAt": "SYNCED · {time}",
  "@drawerSyncSyncedAt": { "placeholders": { "time": { "type": "String" } } },
  "drawerSyncSyncing": "SYNCING…",
  "drawerSyncError": "SYNC ERROR",
  "drawerSyncOffline": "OFFLINE",
  "drawerSyncNow": "Sync now",

  "loginBannerDefault": "Sign in to continue",
  "loginEmailHint": "Email",
  "loginPasswordHint": "Password",
  "loginEmailRequired": "Enter an email",
  "loginEmailInvalid": "Invalid email",
  "loginPasswordRequired": "Enter a password",
  "loginPasswordMinLength": "Minimum 6 characters",
  "loginSignInButton": "Sign in",
  "loginSignUpButton": "Create account",
  "loginOrSeparator": "— or —",
  "loginContinueWithGoogle": "Continue with Google",
  "loginToggleToSignUp": "Don’t have an account? ",
  "loginToggleToSignIn": "Already have an account? ",
  "loginToggleSignUpAction": "Sign up",
  "loginToggleSignInAction": "Sign in",
  "loginSkipButton": "Continue without account",
  "loginConfirmationTitle": "Check your inbox!",
  "loginConfirmationBody": "We sent a confirmation link to\n{email}\n\nClick the link to activate your account and sign in.",
  "@loginConfirmationBody": { "placeholders": { "email": { "type": "String" } } },

  "authErrorGoogleToken": "Could not retrieve Google token.",
  "authErrorEmailAlreadyRegistered": "This email is already registered. Sign in.",
  "authErrorInvalidCredentials": "Wrong email or password.",
  "authErrorEmailNotConfirmed": "Confirm your email before signing in.",
  "authErrorPasswordTooShort": "Password must be at least 6 characters.",
  "authErrorNoConnection": "No connection. Try again.",
  "authErrorUnexpected": "Unexpected error. Try again.",

  "editorTitle": "Route editor",
  "editorNewRouteTooltip": "New route",
  "editorNewRouteButton": "New route",
  "editorNoRoutesTitle": "No routes yet",
  "editorNoRoutesMessage": "Create your first route to start timing.",
  "editorSectorsLabel": "Sectors",
  "editorSectorCenter": "Center: {lat}, {lng}",
  "@editorSectorCenter": { "placeholders": { "lat": { "type": "String" }, "lng": { "type": "String" } } },
  "editorStartFinishLabel": "Start / finish",
  "editorCreatedAt": "Created on {date}",
  "@editorCreatedAt": { "placeholders": { "date": { "type": "String" } } },
  "editorDeleteRouteButton": "Delete route",
  "editorDeleteRouteTitle": "Delete route",
  "editorDeleteRouteConfirm": "Delete \"{routeName}\" and all its sessions?",
  "@editorDeleteRouteConfirm": { "placeholders": { "routeName": { "type": "String" } } },
  "editorModeAppendPath": "Append path",
  "editorModeStartGate": "Start/finish",
  "editorModeSectorGate": "Sector gate",
  "editorDrawingTitle": "Drawing: {draftName}",
  "@editorDrawingTitle": { "placeholders": { "draftName": { "type": "String" } } },
  "editorCancelTooltip": "Cancel",
  "editorCancelDrawingTitle": "Cancel drawing",
  "editorCancelDrawingWarning": "Unsaved points will be discarded.",
  "editorNoMapboxToken": "Mapbox token not configured. The interactive map is disabled; add a token and restart to draw.",
  "editorSegmentPath": "Path",
  "editorSegmentStartFinish": "Start / finish",
  "editorSegmentAddSector": "Add sector",
  "editorUndoPoint": "Undo point",
  "editorPathPoints": "{count, plural, =0{No points} =1{1 point} other{{count} points}}",
  "@editorPathPoints": { "placeholders": { "count": { "type": "int" } } },
  "editorStartGateUndefined": "No start",
  "editorStartGateDefined": "Start defined",
  "editorSectorsCount": "{count, plural, =0{No sectors} =1{1 sector} other{{count} sectors}}",
  "@editorSectorsCount": { "placeholders": { "count": { "type": "int" } } },
  "editorWaitingSecondPoint": "Waiting for 2nd point…",
  "editorDifficultyEasy": "Easy",
  "editorDifficultyMedium": "Medium",
  "editorDifficultyHard": "Hard",
  "editorNewRouteDialogTitle": "New route",
  "editorNameLabel": "Name",
  "editorDescriptionLabel": "Description (optional)",
  "editorDifficultyLabel": "Difficulty",
  "editorStartDrawingButton": "Start drawing",

  "historyTitle": "History",
  "historyNoSessionsTitle": "No sessions recorded yet",
  "historyNoSessionsMessage": "Go to the Session tab, pick a route, and tap \"Start\".",
  "historyDeletedRoute": "Deleted route",
  "historySessionSubtitle": "{date} · {lapCount, plural, =1{1 lap} other{{lapCount} laps}}{bestLap}",
  "@historySessionSubtitle": { "placeholders": { "date": { "type": "String" }, "lapCount": { "type": "int" }, "bestLap": { "type": "String" } } },
  "historySessionTitle": "Session",
  "historyDeleteSessionTitle": "Delete session",
  "historyIrreversibleWarning": "This action cannot be undone.",
  "historySessionNotFound": "Session not found",
  "historyLapsLabel": "Laps",
  "historySectorsLabel": "Sectors",
  "historySectorSubtitle": "Lap {lapNum} · {speed}",
  "@historySectorSubtitle": { "placeholders": { "lapNum": { "type": "int" }, "speed": { "type": "String" } } },
  "historyDistanceLabel": "Distance",
  "historyMaxSpeedLabel": "Max speed",
  "historyAvgSpeedLabel": "Avg speed",

  "sessionTitle": "Live session",
  "sessionNoRoutesTitle": "No routes to run",
  "sessionNoRoutesMessage": "Create a route in the Editor tab first to record a session.",
  "sessionSelectRoute": "Select a route",
  "sessionTelemetrySource": "Telemetry source",
  "sessionSourceSimulated": "Simulated",
  "sessionSourceRealGps": "Real GPS",
  "sessionStartButton": "Start recording",
  "sessionSimulatedHint": "Tap \"Simulate point\" to advance, or \"Auto lap\" to run a lap automatically.",
  "sessionRealGpsHint": "Make sure location is enabled. Points are captured every second.",
  "sessionSavedSnackBar": "Session saved",
  "sessionFinishButton": "Finish and save",
  "sessionCompleteTitle": "Session complete",
  "sessionRouteLabel": "Route: {routeName}",
  "@sessionRouteLabel": { "placeholders": { "routeName": { "type": "String" } } },
  "sessionLapsLabel": "Laps",
  "sessionNewSessionButton": "New session",
  "sessionCurrentLapLabel": "Current lap",
  "sessionLapNumber": "#{n}",
  "@sessionLapNumber": { "placeholders": { "n": { "type": "int" } } },
  "sessionNoLapYet": "–",
  "sessionLapTimeLabel": "Lap time",
  "sessionBestLapLabel": "Best lap",
  "sessionAwaitingStart": "Waiting for first finish-line crossing…",
  "sessionCrossingSectors": "Crossing sectors…",
  "sessionLastSector": "Last sector: {sectorId}",
  "@sessionLastSector": { "placeholders": { "sectorId": { "type": "String" } } },
  "sessionDistanceLabel": "Distance",
  "sessionMaxSpeedLabel": "Max speed",
  "sessionAvgSpeedLabel": "Avg speed",
  "sessionLapsCountLabel": "Laps",
  "sessionPermissionGranted": "Location permission granted.",
  "sessionPermissionDenied": "Location permission denied. Accept the system dialog or switch to \"Simulated\".",
  "sessionPermissionPermanentlyDenied": "Permission permanently blocked. Enable it manually in system settings.",
  "sessionServicesDisabled": "Location services disabled. Turn them on in system settings.",
  "sessionGpsStatus": "Real GPS · {count, plural, =1{1 sample} other{{count} samples}}",
  "@sessionGpsStatus": { "placeholders": { "count": { "type": "int" } } },
  "sessionGpsAccuracy": "Accuracy: {accuracy} m · {lat}, {lng}",
  "@sessionGpsAccuracy": { "placeholders": { "accuracy": { "type": "String" }, "lat": { "type": "String" }, "lng": { "type": "String" } } },
  "sessionAwaitingFirstFix": "Waiting for first fix…",
  "sessionSimulatePoint": "Simulate point",
  "sessionPauseAuto": "Pause auto",
  "sessionAutoLap": "Auto lap",

  "settingsTitle": "Settings",
  "settingsLanguageSection": "Language",
  "settingsLanguageDescription": "Choose the app display language.",

  "unitMeters": "{value} m",
  "@unitMeters": { "placeholders": { "value": { "type": "String" } } },
  "unitKilometers": "{value} km",
  "@unitKilometers": { "placeholders": { "value": { "type": "String" } } },
  "unitKmh": "{value} km/h",
  "@unitKmh": { "placeholders": { "value": { "type": "String" } } }
}
```

- [ ] **Step 3: Create `movile_app/lib/l10n/app_es.arb`**

```json
{
  "@@locale": "es",

  "appTitle": "Splitway",
  "appTagline": "Cronómetro inteligente para rutas",

  "commonCancel": "Cancelar",
  "commonDelete": "Eliminar",
  "commonBack": "Volver",
  "commonSave": "Guardar",
  "commonClose": "Entendido",
  "commonRefresh": "Recargar",
  "commonDiscard": "Descartar",

  "languageEnglish": "Inglés",
  "languageSpanish": "Español",

  "navEditor": "Editor",
  "navSession": "Sesión",
  "navHistory": "Historial",

  "drawerMenu": "Menú",
  "drawerDefaultUser": "Usuario",
  "drawerSettings": "Configuración",
  "drawerStats": "Estadísticas",
  "drawerHelp": "Ayuda",
  "drawerSignOut": "Cerrar sesión",
  "drawerSignIn": "Iniciar sesión",
  "drawerAppVersion": "v{version}",
  "drawerSyncSynced": "SINCRONIZADO",
  "drawerSyncSyncedNow": "SINCRONIZADO · ahora",
  "drawerSyncSyncedMinutes": "SINCRONIZADO · hace {minutes} min",
  "drawerSyncSyncedAt": "SINCRONIZADO · {time}",
  "drawerSyncSyncing": "SINCRONIZANDO…",
  "drawerSyncError": "ERROR DE SYNC",
  "drawerSyncOffline": "SIN CONEXIÓN",
  "drawerSyncNow": "Sincronizar ahora",

  "loginBannerDefault": "Inicia sesión para continuar",
  "loginEmailHint": "Email",
  "loginPasswordHint": "Contraseña",
  "loginEmailRequired": "Introduce un email",
  "loginEmailInvalid": "Email no válido",
  "loginPasswordRequired": "Introduce una contraseña",
  "loginPasswordMinLength": "Mínimo 6 caracteres",
  "loginSignInButton": "Iniciar sesión",
  "loginSignUpButton": "Crear cuenta",
  "loginOrSeparator": "— o —",
  "loginContinueWithGoogle": "Continuar con Google",
  "loginToggleToSignUp": "¿No tienes cuenta? ",
  "loginToggleToSignIn": "¿Ya tienes cuenta? ",
  "loginToggleSignUpAction": "Regístrate",
  "loginToggleSignInAction": "Inicia sesión",
  "loginSkipButton": "Continuar sin cuenta",
  "loginConfirmationTitle": "¡Revisa tu correo!",
  "loginConfirmationBody": "Te hemos enviado un enlace de confirmación a\n{email}\n\nHaz clic en el enlace para activar tu cuenta y poder iniciar sesión.",

  "authErrorGoogleToken": "No se pudo obtener el token de Google.",
  "authErrorEmailAlreadyRegistered": "Este email ya está registrado. Inicia sesión.",
  "authErrorInvalidCredentials": "Email o contraseña incorrectos.",
  "authErrorEmailNotConfirmed": "Confirma tu email antes de iniciar sesión.",
  "authErrorPasswordTooShort": "La contraseña debe tener al menos 6 caracteres.",
  "authErrorNoConnection": "Sin conexión. Inténtalo de nuevo.",
  "authErrorUnexpected": "Error inesperado. Inténtalo de nuevo.",

  "editorTitle": "Editor de rutas",
  "editorNewRouteTooltip": "Nueva ruta",
  "editorNewRouteButton": "Nueva ruta",
  "editorNoRoutesTitle": "Aún no tienes rutas",
  "editorNoRoutesMessage": "Crea tu primera ruta para empezar a cronometrar.",
  "editorSectorsLabel": "Sectores",
  "editorSectorCenter": "Centro: {lat}, {lng}",
  "editorStartFinishLabel": "Inicio / meta",
  "editorCreatedAt": "Creada el {date}",
  "editorDeleteRouteButton": "Eliminar ruta",
  "editorDeleteRouteTitle": "Eliminar ruta",
  "editorDeleteRouteConfirm": "¿Borrar \"{routeName}\" y todas sus sesiones?",
  "editorModeAppendPath": "Trazado",
  "editorModeStartGate": "Inicio / meta",
  "editorModeSectorGate": "Añadir sector",
  "editorDrawingTitle": "Dibujando: {draftName}",
  "editorCancelTooltip": "Cancelar",
  "editorCancelDrawingTitle": "Cancelar dibujo",
  "editorCancelDrawingWarning": "Se descartarán los puntos sin guardar.",
  "editorNoMapboxToken": "Sin Mapbox token configurado. El mapa interactivo está desactivado; para probar el dibujo, añade un token y reinicia.",
  "editorSegmentPath": "Trazado",
  "editorSegmentStartFinish": "Inicio / meta",
  "editorSegmentAddSector": "Añadir sector",
  "editorUndoPoint": "Deshacer punto",
  "editorPathPoints": "{count, plural, =0{Sin puntos} =1{1 punto} other{{count} puntos}}",
  "editorStartGateUndefined": "Sin inicio",
  "editorStartGateDefined": "Inicio definido",
  "editorSectorsCount": "{count, plural, =0{Sin sectores} =1{1 sector} other{{count} sectores}}",
  "editorWaitingSecondPoint": "Falta el 2º punto…",
  "editorDifficultyEasy": "Fácil",
  "editorDifficultyMedium": "Media",
  "editorDifficultyHard": "Difícil",
  "editorNewRouteDialogTitle": "Nueva ruta",
  "editorNameLabel": "Nombre",
  "editorDescriptionLabel": "Descripción (opcional)",
  "editorDifficultyLabel": "Dificultad",
  "editorStartDrawingButton": "Empezar a dibujar",

  "historyTitle": "Historial",
  "historyNoSessionsTitle": "Aún no has grabado ninguna sesión",
  "historyNoSessionsMessage": "Ve a la pestaña Sesión, elige una ruta y pulsa \"Comenzar\".",
  "historyDeletedRoute": "Ruta eliminada",
  "historySessionSubtitle": "{date} · {lapCount, plural, =1{1 vuelta} other{{lapCount} vueltas}}{bestLap}",
  "historySessionTitle": "Sesión",
  "historyDeleteSessionTitle": "Eliminar sesión",
  "historyIrreversibleWarning": "Esta acción no se puede deshacer.",
  "historySessionNotFound": "Sesión no encontrada",
  "historyLapsLabel": "Vueltas",
  "historySectorsLabel": "Sectores",
  "historySectorSubtitle": "Vuelta {lapNum} · {speed}",
  "historyDistanceLabel": "Distancia",
  "historyMaxSpeedLabel": "Vel. máx",
  "historyAvgSpeedLabel": "Vel. media",

  "sessionTitle": "Sesión en vivo",
  "sessionNoRoutesTitle": "No hay rutas para correr",
  "sessionNoRoutesMessage": "Crea una ruta primero en la pestaña Editor para poder grabar una sesión.",
  "sessionSelectRoute": "Selecciona una ruta",
  "sessionTelemetrySource": "Fuente de telemetría",
  "sessionSourceSimulated": "Simulada",
  "sessionSourceRealGps": "GPS real",
  "sessionStartButton": "Comenzar grabación",
  "sessionSimulatedHint": "Pulsa \"Simular punto\" para avanzar, o \"Auto vuelta\" para correr una vuelta automáticamente.",
  "sessionRealGpsHint": "Asegúrate de tener la ubicación activada. Los puntos se capturan cada segundo.",
  "sessionSavedSnackBar": "Sesión guardada",
  "sessionFinishButton": "Finalizar y guardar",
  "sessionCompleteTitle": "Sesión completa",
  "sessionRouteLabel": "Ruta: {routeName}",
  "sessionLapsLabel": "Vueltas",
  "sessionNewSessionButton": "Nueva sesión",
  "sessionCurrentLapLabel": "Vuelta actual",
  "sessionLapNumber": "#{n}",
  "sessionNoLapYet": "–",
  "sessionLapTimeLabel": "Tiempo en vuelta",
  "sessionBestLapLabel": "Mejor vuelta",
  "sessionAwaitingStart": "Esperando primer cruce de meta…",
  "sessionCrossingSectors": "Cruzando sectores…",
  "sessionLastSector": "Último sector: {sectorId}",
  "sessionDistanceLabel": "Distancia",
  "sessionMaxSpeedLabel": "Vel. máx.",
  "sessionAvgSpeedLabel": "Vel. media",
  "sessionLapsCountLabel": "Vueltas",
  "sessionPermissionGranted": "Permiso de ubicación concedido.",
  "sessionPermissionDenied": "Permiso de ubicación denegado. Acepta el diálogo del sistema o cambia a \"Simulada\".",
  "sessionPermissionPermanentlyDenied": "Permiso bloqueado permanentemente. Actívalo manualmente en los ajustes del sistema.",
  "sessionServicesDisabled": "Servicios de ubicación desactivados. Enciéndelos en los ajustes del sistema.",
  "sessionGpsStatus": "GPS real · {count, plural, =1{1 muestra} other{{count} muestras}}",
  "sessionGpsAccuracy": "Precisión: {accuracy} m · {lat}, {lng}",
  "sessionAwaitingFirstFix": "Esperando primer fix…",
  "sessionSimulatePoint": "Simular punto",
  "sessionPauseAuto": "Parar auto",
  "sessionAutoLap": "Auto vuelta",

  "settingsTitle": "Ajustes",
  "settingsLanguageSection": "Idioma",
  "settingsLanguageDescription": "Elige el idioma de la interfaz.",

  "unitMeters": "{value} m",
  "unitKilometers": "{value} km",
  "unitKmh": "{value} km/h"
}
```

- [ ] **Step 4: Generate localizations and confirm no errors**

Run from `movile_app/`:

```bash
flutter gen-l10n
```

Expected: success, generated files appear under `movile_app/lib/l10n/` (`app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_es.dart`). The generated `AppLocalizations` class can now be imported as `import 'package:splitway_mobile/l10n/app_localizations.dart';` (gen-l10n in modern Flutter generates inside the project's lib tree by default, not into the synthetic `flutter_gen` package).

- [ ] **Step 5: Commit**

```bash
git add movile_app/l10n.yaml movile_app/lib/l10n/
git commit -m "feat(i18n): seed gen-l10n config and en/es ARB files"
```

---

### Task 3: `LocaleController` — ChangeNotifier backed by `shared_preferences`

**Files:**
- Create: `movile_app/lib/src/services/locale/locale_controller.dart`
- Create: `movile_app/test/services/locale/locale_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `movile_app/test/services/locale/locale_controller_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitway_mobile/src/services/locale/locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to device locale when no preference stored', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final ctrl = await LocaleController.load(
      deviceLocale: const Locale('en'),
    );
    expect(ctrl.locale, const Locale('en'));
    debugDefaultTargetPlatformOverride = null;
  });

  test('falls back to Spanish for unsupported device locale', () async {
    final ctrl = await LocaleController.load(
      deviceLocale: const Locale('fr'),
    );
    expect(ctrl.locale, const Locale('es'));
  });

  test('loads stored preference', () async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final ctrl = await LocaleController.load(
      deviceLocale: const Locale('es'),
    );
    expect(ctrl.locale, const Locale('en'));
  });

  test('setLocale persists and notifies listeners', () async {
    final ctrl = await LocaleController.load(
      deviceLocale: const Locale('es'),
    );
    var notified = 0;
    ctrl.addListener(() => notified += 1);

    await ctrl.setLocale(const Locale('en'));

    expect(ctrl.locale, const Locale('en'));
    expect(notified, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), 'en');
  });

  test('setLocale skips notify when value is unchanged', () async {
    final ctrl = await LocaleController.load(
      deviceLocale: const Locale('es'),
    );
    var notified = 0;
    ctrl.addListener(() => notified += 1);

    await ctrl.setLocale(const Locale('es'));

    expect(notified, 0);
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/services/locale/locale_controller_test.dart
```

Expected: FAIL — `locale_controller.dart` does not exist.

- [ ] **Step 3: Implement `LocaleController`**

Create `movile_app/lib/src/services/locale/locale_controller.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mutable, listenable holder for the current app [Locale].
///
/// Persists the choice in [SharedPreferences] under the key `locale` as the
/// language code (`"en"` / `"es"`). On first launch, falls back to the device
/// locale if it is supported, otherwise to Spanish.
class LocaleController extends ChangeNotifier {
  LocaleController._(this._locale, this._prefs);

  static const String _prefsKey = 'locale';
  static const List<Locale> supported = [Locale('es'), Locale('en')];

  static const Locale _fallback = Locale('es');

  Locale _locale;
  final SharedPreferences _prefs;

  Locale get locale => _locale;

  static Future<LocaleController> load({required Locale deviceLocale}) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    final resolved = _resolve(stored, deviceLocale);
    Intl.defaultLocale = resolved.toLanguageTag();
    return LocaleController._(resolved, prefs);
  }

  static Locale _resolve(String? stored, Locale deviceLocale) {
    if (stored != null) {
      for (final l in supported) {
        if (l.languageCode == stored) return l;
      }
    }
    for (final l in supported) {
      if (l.languageCode == deviceLocale.languageCode) return l;
    }
    return _fallback;
  }

  Future<void> setLocale(Locale next) async {
    if (next == _locale) return;
    _locale = next;
    Intl.defaultLocale = next.toLanguageTag();
    await _prefs.setString(_prefsKey, next.languageCode);
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/services/locale/locale_controller_test.dart
```

Expected: PASS, all 5 tests.

- [ ] **Step 5: Commit**

```bash
git add movile_app/lib/src/services/locale/ movile_app/test/services/locale/
git commit -m "feat(i18n): LocaleController persists language choice in SharedPreferences"
```

---

### Task 4: Wire `MaterialApp.router` with localizations + accept `LocaleController`

**Files:**
- Modify: `movile_app/lib/main.dart`
- Modify: `movile_app/lib/src/app.dart`

- [ ] **Step 1: Update `main.dart`**

Replace the contents of `movile_app/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/config/app_config.dart';
import 'src/data/demo/demo_seed.dart';
import 'src/data/local/splitway_local_database.dart';
import 'src/data/repositories/local_draft_repository.dart';
import 'src/services/locale/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-load date formatting symbols for every supported locale so
  // Formatters.dateTime works regardless of which locale the user picks.
  await initializeDateFormatting('es_ES');
  await initializeDateFormatting('en_US');

  final config = await AppConfig.load();
  if (config.hasMapbox) {
    mbx.MapboxOptions.setAccessToken(config.mapboxToken!);
  }

  if (config.hasSupabase) {
    await Supabase.initialize(
      url: config.supabaseUrl!,
      anonKey: config.supabaseAnonKey!,
    );
  }

  final database = await SplitwayLocalDatabase.open();
  final seedRepo = LocalDraftRepository(database);
  await DemoSeed.ensureSeeded(seedRepo);
  await seedRepo.dispose();

  final deviceLocale =
      WidgetsBinding.instance.platformDispatcher.locale;
  final localeController =
      await LocaleController.load(deviceLocale: deviceLocale);

  runApp(SplitwayApp(
    config: config,
    database: database,
    localeController: localeController,
  ));
}
```

- [ ] **Step 2: Update `app.dart`**

Replace the entire contents of `movile_app/lib/src/app.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'data/local/splitway_local_database.dart';
import 'data/repositories/local_draft_repository.dart';
import 'data/repositories/supabase_repository.dart';
import 'routing/app_router.dart';
import 'services/auth/auth_service.dart';
import 'services/locale/locale_controller.dart';
import 'services/sync/sync_service.dart';

class SplitwayApp extends StatefulWidget {
  const SplitwayApp({
    super.key,
    required this.config,
    required this.database,
    required this.localeController,
  });

  final AppConfig config;
  final SplitwayLocalDatabase database;
  final LocaleController localeController;

  @override
  State<SplitwayApp> createState() => _SplitwayAppState();
}

class _SplitwayAppState extends State<SplitwayApp> {
  late final LocalDraftRepository _repository;
  late final AppRouter _router;
  AuthService? _authService;
  SyncService? _syncService;

  @override
  void initState() {
    super.initState();
    _repository = LocalDraftRepository(widget.database);

    if (widget.config.hasSupabase) {
      final client = Supabase.instance.client;
      _authService = AuthService(client: client);
      _authService!.addListener(_onAuthStateChanged);
      if (client.auth.currentUser != null) {
        _createSyncService(client);
      }
    }

    _router = AppRouter(
      repository: _repository,
      config: widget.config,
      authService: _authService,
      syncService: _syncService,
      localeController: widget.localeController,
    );
  }

  void _onAuthStateChanged() {
    final isLoggedIn = _authService?.isLoggedIn ?? false;

    if (isLoggedIn && _syncService == null && widget.config.hasSupabase) {
      _createSyncService(Supabase.instance.client);
      _router.syncService = _syncService;
    } else if (!isLoggedIn && _syncService != null) {
      _syncService!.stopPeriodicSync();
      _syncService!.dispose();
      _syncService = null;
      _router.syncService = null;
    }
  }

  void _createSyncService(SupabaseClient client) {
    _syncService = SyncService(
      local: _repository,
      remote: SupabaseRepository(client),
    );
    _syncService!.startPeriodicSync();
  }

  @override
  void dispose() {
    _authService?.removeListener(_onAuthStateChanged);
    _authService?.dispose();
    _syncService?.dispose();
    _router.dispose();
    _repository.dispose();
    widget.database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.localeController,
      builder: (context, _) => MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        locale: widget.localeController.locale,
        supportedLocales: LocaleController.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.dark,
          ),
        ),
        routerConfig: _router.router,
      ),
    );
  }
}
```

- [ ] **Step 3: Update `AppRouter` constructor to accept `LocaleController`**

In `movile_app/lib/src/routing/app_router.dart`, change the constructor and field declaration:

Replace lines 17–29 (the class header through the initialiser list) with:

```dart
class AppRouter {
  AppRouter({
    required this.repository,
    required this.config,
    required this.localeController,
    this.authService,
    this.syncService,
  })  : _editorController = RouteEditorController(
          repository,
          routingService: config.hasMapbox
              ? RoutingService(mapboxToken: config.mapboxToken!)
              : null,
        ),
        _sessionController = LiveSessionController(repository);

  final LocalDraftRepository repository;
  final AppConfig config;
  final LocaleController localeController;
  final AuthService? authService;
```

Add the import at the top of the file:

```dart
import '../services/locale/locale_controller.dart';
```

- [ ] **Step 4: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: no errors. (Warnings about unused imports etc. are OK at this stage.)

- [ ] **Step 5: Run the existing test suite**

```bash
flutter test
```

Expected: all existing tests still pass except possibly `widget_test.dart` (Spanish assertions still hold because device locale fallback chooses `es` when undetermined; the in-test default locale is the system locale). If any test fails because the test environment doesn't satisfy localization delegates, see Task 14 — for now we will not break this; the existing tests mount inner widgets in plain `MaterialApp` without delegates.

- [ ] **Step 6: Commit**

```bash
git add movile_app/lib/main.dart movile_app/lib/src/app.dart movile_app/lib/src/routing/app_router.dart
git commit -m "feat(i18n): wire MaterialApp with localizations delegates and LocaleController"
```

---

### Task 5: Build `SettingsScreen` with the language picker

**Files:**
- Create: `movile_app/lib/src/features/settings/settings_screen.dart`
- Create: `movile_app/test/features/settings/settings_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `movile_app/test/features/settings/settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitway_mobile/src/features/settings/settings_screen.dart';
import 'package:splitway_mobile/src/services/locale/locale_controller.dart';

Widget _harness(LocaleController controller) {
  return ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      locale: controller.locale,
      supportedLocales: LocaleController.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SettingsScreen(localeController: controller),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows both language options and marks current', (tester) async {
    final ctrl = await LocaleController.load(deviceLocale: const Locale('es'));
    await tester.pumpWidget(_harness(ctrl));
    await tester.pumpAndSettle();

    expect(find.text('Español'), findsOneWidget);
    expect(find.text('Inglés'), findsOneWidget);

    final spanishTile = tester.widget<RadioListTile<Locale>>(
      find.byWidgetPredicate(
        (w) => w is RadioListTile<Locale> && w.value == const Locale('es'),
      ),
    );
    expect(spanishTile.groupValue, const Locale('es'));
  });

  testWidgets('tapping English switches locale and updates UI', (tester) async {
    final ctrl = await LocaleController.load(deviceLocale: const Locale('es'));
    await tester.pumpWidget(_harness(ctrl));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inglés'));
    await tester.pumpAndSettle();

    expect(ctrl.locale, const Locale('en'));
    // After switching, the screen title is now in English ("Settings").
    expect(find.text('Settings'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test — expect failure**

```bash
flutter test test/features/settings/settings_screen_test.dart
```

Expected: FAIL — `settings_screen.dart` does not exist.

- [ ] **Step 3: Implement `SettingsScreen`**

Create `movile_app/lib/src/features/settings/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';

import '../../services/locale/locale_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListenableBuilder(
        listenable: localeController,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l.settingsLanguageSection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l.settingsLanguageDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            RadioListTile<Locale>(
              title: Text(l.languageSpanish),
              value: const Locale('es'),
              groupValue: localeController.locale,
              onChanged: (value) {
                if (value != null) localeController.setLocale(value);
              },
            ),
            RadioListTile<Locale>(
              title: Text(l.languageEnglish),
              value: const Locale('en'),
              groupValue: localeController.locale,
              onChanged: (value) {
                if (value != null) localeController.setLocale(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/settings/settings_screen_test.dart
```

Expected: PASS, both tests.

- [ ] **Step 5: Commit**

```bash
git add movile_app/lib/src/features/settings/ movile_app/test/features/settings/
git commit -m "feat(settings): add Settings screen with language picker"
```

---

### Task 6: Add `/settings` route and wire from drawer

**Files:**
- Modify: `movile_app/lib/src/routing/app_router.dart`
- Modify: `movile_app/lib/src/shared/widgets/app_drawer.dart`

- [ ] **Step 1: Add the `/settings` route**

In `movile_app/lib/src/routing/app_router.dart`, add this import at the top:

```dart
import '../features/settings/settings_screen.dart';
```

Inside the `routes:` list of the `GoRouter` (sibling to the existing `GoRoute(path: '/login', ...)`), add a new top-level route. Place it just *after* the `/login` route and *before* the `StatefulShellRoute.indexedStack`:

```dart
      GoRoute(
        path: '/settings',
        builder: (_, __) => SettingsScreen(localeController: localeController),
      ),
```

- [ ] **Step 2: Wire the drawer "Configuración" tap**

In `movile_app/lib/src/shared/widgets/app_drawer.dart`:

- Add at the top of the file:

```dart
import 'package:go_router/go_router.dart';
```

- Replace the `_MenuItem(... label: 'Configuración' ...)` block (around line 143–150) with:

```dart
              _MenuItem(
                icon: Icons.settings_outlined,
                label: 'Configuración',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/settings');
                },
              ),
```

(We leave the literal string here for now — Task 9 localizes the drawer.)

- [ ] **Step 3: Manual smoke check (run the app)**

Run from `movile_app/`:

```bash
flutter run -d <device>
```

Open the drawer → tap "Configuración" → confirm the Settings screen opens, the picker shows both languages, and tapping "Inglés" switches the AppBar title to "Settings" instantly. Pull-to-restart and verify the choice is persisted.

If you cannot test on a device, run `flutter analyze` and confirm no errors:

```bash
flutter analyze
```

- [ ] **Step 4: Commit**

```bash
git add movile_app/lib/src/routing/app_router.dart movile_app/lib/src/shared/widgets/app_drawer.dart
git commit -m "feat(settings): route /settings and link from drawer"
```

---

## Phase B — String migration (one screen per task)

For every task in this phase the pattern is the same: import `AppLocalizations`, fetch it once at the top of `build` (`final l = AppLocalizations.of(context);`), and replace every literal with `l.<key>`. Each migration ends with a smoke test that pumps the screen under both `Locale('es')` and `Locale('en')` and asserts a distinct visible string from each.

> **Reusable test harness** — every screen migration test uses this helper. Put it inline in each test file (don't extract a shared helper before all migrations are done; we'll consolidate in Task 14):
>
> ```dart
> Widget _harness({
>   required Locale locale,
>   required Widget child,
> }) {
>   return MaterialApp(
>     locale: locale,
>     supportedLocales: LocaleController.supported,
>     localizationsDelegates: const [
>       AppLocalizations.delegate,
>       GlobalMaterialLocalizations.delegate,
>       GlobalWidgetsLocalizations.delegate,
>       GlobalCupertinoLocalizations.delegate,
>     ],
>     home: child,
>   );
> }
> ```

---

### Task 7: Migrate `home_shell.dart` (nav labels + drawer tooltip)

**Files:**
- Modify: `movile_app/lib/src/features/home/home_shell.dart`

- [ ] **Step 1: Add import**

At the top of `home_shell.dart`, add:

```dart
import 'package:splitway_mobile/l10n/app_localizations.dart';
```

- [ ] **Step 2: Replace literals**

In `_buildScaffold`, the `destinations:` list is `const`, which prevents using `AppLocalizations.of(context)`. Remove `const` from the list:

```dart
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.edit_location_alt_outlined),
            selectedIcon: const Icon(Icons.edit_location_alt),
            label: AppLocalizations.of(context).navEditor,
          ),
          NavigationDestination(
            icon: const Icon(Icons.play_circle_outline),
            selectedIcon: const Icon(Icons.play_circle),
            label: AppLocalizations.of(context).navSession,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            selectedIcon: const Icon(Icons.history_toggle_off),
            label: AppLocalizations.of(context).navHistory,
          ),
        ],
```

In `buildDrawerLeading`, replace:

```dart
    tooltip: isLoggedIn ? 'Menú' : 'Menú',
```

with:

```dart
    tooltip: AppLocalizations.of(context).drawerMenu,
```

- [ ] **Step 3: Run `flutter analyze`**

```bash
flutter analyze lib/src/features/home/home_shell.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add movile_app/lib/src/features/home/home_shell.dart
git commit -m "i18n: localize home_shell nav labels and drawer tooltip"
```

---

### Task 8: Migrate `app_drawer.dart`

**Files:**
- Modify: `movile_app/lib/src/shared/widgets/app_drawer.dart`

- [ ] **Step 1: Add import**

```dart
import 'package:splitway_mobile/l10n/app_localizations.dart';
```

- [ ] **Step 2: Replace literals in `_LoggedInContent.build`**

Inside `build`, after `final email = ...`, add:

```dart
    final l = AppLocalizations.of(context);
```

Replace:
- `'Usuario'` → `l.drawerDefaultUser`
- `_MenuItem(... label: 'Configuración', ...)` → `_MenuItem(... label: l.drawerSettings, ...)`
- `_MenuItem(... label: 'Estadísticas', ...)` → `_MenuItem(... label: l.drawerStats, ...)`
- `_MenuItem(... label: 'Ayuda', ...)` → `_MenuItem(... label: l.drawerHelp, ...)`
- The `Text('v0.4.0', ...)` in the footer → `Text(l.drawerAppVersion('0.4.0'), ...)`
- `'Cerrar sesión'` (inside the footer `GestureDetector`) → `l.drawerSignOut`

- [ ] **Step 3: Replace literals in `_SyncSection.build`**

Add at the top of `build`:

```dart
    final l = AppLocalizations.of(context);
```

Replace the `switch (status)` block with:

```dart
    final (dotColor, label) = switch (status) {
      SyncStatus.idle => (const Color(0xFF4CAF50), _idleLabel(l)),
      SyncStatus.syncing => (const Color(0xFF42A5F5), l.drawerSyncSyncing),
      SyncStatus.error => (const Color(0xFFEF5350), l.drawerSyncError),
      SyncStatus.success => (const Color(0xFF4CAF50), _idleLabel(l)),
      SyncStatus.offline => (const Color(0xFFFF9800), l.drawerSyncOffline),
    };
```

Replace the `Text('Sincronizar ahora', ...)` inside the sync button with `Text(l.drawerSyncNow, ...)`.

- [ ] **Step 4: Update `_idleLabel` signature**

Replace the existing `_idleLabel()` method with:

```dart
  String _idleLabel(AppLocalizations l) {
    final last = syncService.lastSyncedAt;
    if (last == null) return l.drawerSyncSynced;
    final diff = DateTime.now().difference(last);
    if (diff.inMinutes < 1) return l.drawerSyncSyncedNow;
    if (diff.inMinutes < 60) return l.drawerSyncSyncedMinutes(diff.inMinutes);
    final time =
        '${last.hour}:${last.minute.toString().padLeft(2, '0')}';
    return l.drawerSyncSyncedAt(time);
  }
```

- [ ] **Step 5: Replace literals in `_LoggedOutContent.build`**

Add at top of `build`:

```dart
    final l = AppLocalizations.of(context);
```

Replace:
- `Text('Iniciar sesión', ...)` → `Text(l.drawerSignIn, ...)`
- `_MenuItem(... label: 'Ayuda', ...)` → `_MenuItem(... label: l.drawerHelp, ...)`
- `Text('v0.4.0', ...)` → `Text(l.drawerAppVersion('0.4.0'), ...)`

- [ ] **Step 6: Run `flutter analyze`**

```bash
flutter analyze lib/src/shared/widgets/app_drawer.dart
```

Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add movile_app/lib/src/shared/widgets/app_drawer.dart
git commit -m "i18n: localize app_drawer (menu, sync section, sign-in prompt)"
```

---

### Task 9: Migrate `login_screen.dart` and refactor auth error codes

This task is bigger than the others because we also refactor `AuthService` to expose stable `AuthErrorCode` values instead of localized strings — `AuthService` runs with no `BuildContext`, so it cannot translate.

**Files:**
- Create: `movile_app/lib/src/services/auth/auth_error_code.dart`
- Modify: `movile_app/lib/src/services/auth/auth_service.dart`
- Modify: `movile_app/lib/src/features/auth/login_screen.dart`
- Modify: `movile_app/lib/src/routing/app_router.dart` (the `requireAuth` helper's default banner)

- [ ] **Step 1: Create the `AuthErrorCode` enum**

Create `movile_app/lib/src/services/auth/auth_error_code.dart`:

```dart
enum AuthErrorCode {
  googleTokenUnavailable,
  emailAlreadyRegistered,
  invalidCredentials,
  emailNotConfirmed,
  passwordTooShort,
  noConnection,
  unexpected,
}
```

- [ ] **Step 2: Modify `AuthService` to expose `errorCode`**

In `movile_app/lib/src/services/auth/auth_service.dart`:

Add at top:

```dart
import 'auth_error_code.dart';
```

Replace the `String? _error;` field and getter (lines 25–26) with:

```dart
  AuthErrorCode? _errorCode;
  AuthErrorCode? get errorCode => _errorCode;
```

Add a setter helper underneath the `clearPendingConfirmation` method:

```dart
  void clearError() {
    _errorCode = null;
    notifyListeners();
  }
```

(Remove the existing `clearError` if it already exists, to avoid duplicates.)

Replace every `_error = '...';` assignment inside `signInWithGoogle`, `signInWithEmail`, `signUpWithEmail`:

| Old | New |
|---|---|
| `_error = 'No se pudo obtener el token de Google.';` | `_errorCode = AuthErrorCode.googleTokenUnavailable;` |
| `_error = 'Este email ya está registrado. Inicia sesión.';` | `_errorCode = AuthErrorCode.emailAlreadyRegistered;` |
| `_error = _friendlyAuthError(e);` | `_errorCode = _mapAuthError(e);` |
| `_error = _friendlyError(e);` | `_errorCode = _mapGenericError(e);` |
| `_error = null;` (the resets) | `_errorCode = null;` |

Replace the `_friendlyAuthError` and `_friendlyError` methods with:

```dart
  AuthErrorCode _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return AuthErrorCode.invalidCredentials;
    }
    if (msg.contains('email not confirmed')) {
      return AuthErrorCode.emailNotConfirmed;
    }
    if (msg.contains('user already registered')) {
      return AuthErrorCode.emailAlreadyRegistered;
    }
    if (msg.contains('password') && msg.contains('at least')) {
      return AuthErrorCode.passwordTooShort;
    }
    return AuthErrorCode.unexpected;
  }

  AuthErrorCode _mapGenericError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('connection')) {
      return AuthErrorCode.noConnection;
    }
    return AuthErrorCode.unexpected;
  }
```

Update `_onAuthEvent`:

```dart
  void _onAuthEvent(AuthState state) {
    debugPrint('AuthService: ${state.event}');
    _errorCode = null;
    notifyListeners();
  }
```

- [ ] **Step 3: Migrate `login_screen.dart`**

In `movile_app/lib/src/features/auth/login_screen.dart`, add the import:

```dart
import 'package:splitway_mobile/l10n/app_localizations.dart';

import '../../services/auth/auth_error_code.dart';
```

At the top of `_LoginScreenState.build`, after `final auth = widget.authService;`:

```dart
    final l = AppLocalizations.of(context);
```

Helper to translate an error code — add it as a private top-level function in the same file:

```dart
String _localizedAuthError(AppLocalizations l, AuthErrorCode code) {
  switch (code) {
    case AuthErrorCode.googleTokenUnavailable:
      return l.authErrorGoogleToken;
    case AuthErrorCode.emailAlreadyRegistered:
      return l.authErrorEmailAlreadyRegistered;
    case AuthErrorCode.invalidCredentials:
      return l.authErrorInvalidCredentials;
    case AuthErrorCode.emailNotConfirmed:
      return l.authErrorEmailNotConfirmed;
    case AuthErrorCode.passwordTooShort:
      return l.authErrorPasswordTooShort;
    case AuthErrorCode.noConnection:
      return l.authErrorNoConnection;
    case AuthErrorCode.unexpected:
      return l.authErrorUnexpected;
  }
}
```

Replace strings throughout:

| Literal | Replacement |
|---|---|
| `'Splitway'` (line 210) | `l.appTitle` |
| `'Cronómetro inteligente para rutas'` | `l.appTagline` |
| `'— o —'` | `l.loginOrSeparator` |
| `'Email'` (hint in `_inputDecoration('Email')`) | `l.loginEmailHint` |
| `'Contraseña'` (hint) | `l.loginPasswordHint` |
| Validator `'Introduce un email'` | `l.loginEmailRequired` |
| Validator `'Email no válido'` | `l.loginEmailInvalid` |
| Validator `'Introduce una contraseña'` | `l.loginPasswordRequired` |
| Validator `'Mínimo 6 caracteres'` | `l.loginPasswordMinLength` |
| `_isSignUp ? 'Crear cuenta' : 'Iniciar sesión'` | `_isSignUp ? l.loginSignUpButton : l.loginSignInButton` |
| `'¿Ya tienes cuenta? '` / `'¿No tienes cuenta? '` | `l.loginToggleToSignIn` / `l.loginToggleToSignUp` |
| `'Inicia sesión'` / `'Regístrate'` | `l.loginToggleSignInAction` / `l.loginToggleSignUpAction` |
| `'Continuar sin cuenta'` | `l.loginSkipButton` |
| Error banner `auth.error!` | `_localizedAuthError(l, auth.errorCode!)` (guarded by `if (auth.errorCode != null)`) |
| `'Continuar con Google'` in `_GoogleSignInButton` | needs access to `l`; convert that widget to also read `AppLocalizations.of(context)` in its `build` |
| `'¡Revisa tu correo!'` (dialog title) | `l.loginConfirmationTitle` |
| `'Te hemos enviado un enlace de confirmación a\n$email\n\nHaz clic en el enlace para activar tu cuenta y poder iniciar sesión.'` | `l.loginConfirmationBody(email)` |
| `'Entendido'` (dialog action) | `l.commonClose` |

Update `_GoogleSignInButton.build` to:

```dart
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        // ... unchanged
        label: Text(
          l.loginContinueWithGoogle,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
```

Update the conditional banner check (around line 321):

```dart
                          if (auth.errorCode != null) ...[
                            Container(
                              // ... unchanged styling
                              child: Text(
                                _localizedAuthError(l, auth.errorCode!),
                                // ... unchanged
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
```

- [ ] **Step 4: Update `requireAuth` default banner**

In `movile_app/lib/src/routing/app_router.dart`, replace the body of `requireAuth` so callers must pass an *already-localized* message (the helper no longer hard-codes Spanish):

```dart
Future<bool> requireAuth(
  BuildContext context,
  AuthService? authService, {
  required String message,
}) async {
  if (authService == null || authService.isLoggedIn) return true;

  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => LoginScreen(
        authService: authService,
        bannerMessage: message,
      ),
    ),
  );
  return result == true;
}
```

Every existing call site of `requireAuth(context, authService, message: '…')` now requires the caller to pass a localized message. Update the call sites:

```bash
grep -rn "requireAuth(" movile_app/lib
```

For each result, replace any literal Spanish string with `AppLocalizations.of(context).loginBannerDefault` (or a more specific key if appropriate — add a new ARB key in Task 2 first if you discover one). If you find no remaining call sites that pass a custom message, this is a no-op.

- [ ] **Step 5: Run `flutter analyze`**

```bash
flutter analyze
```

Expected: no errors. Fix any unresolved references.

- [ ] **Step 6: Run tests**

```bash
flutter test
```

Expected: existing tests still pass (we haven't changed `widget_test.dart` yet — those screens don't render the login screen, so they should be unaffected).

- [ ] **Step 7: Commit**

```bash
git add movile_app/lib/src/services/auth/ movile_app/lib/src/features/auth/login_screen.dart movile_app/lib/src/routing/app_router.dart
git commit -m "i18n: localize login screen and refactor AuthService to error codes"
```

---

### Task 10: Migrate `route_editor_screen.dart`

**Files:**
- Modify: `movile_app/lib/src/features/editor/route_editor_screen.dart`

- [ ] **Step 1: Add import**

```dart
import 'package:splitway_mobile/l10n/app_localizations.dart';
```

- [ ] **Step 2: Replace every literal**

At the top of every `build`/builder method that holds Spanish text, add:

```dart
    final l = AppLocalizations.of(context);
```

Use the mapping below (line numbers reference the pre-migration file). For `const` widgets containing localized text, drop `const` from the outermost wrapping `Text` or `Widget`.

| Literal | Replacement |
|---|---|
| `'Eliminar ruta'` (dialog title) | `l.editorDeleteRouteTitle` |
| `'¿Borrar "${route.name}" y todas sus sesiones?'` | `l.editorDeleteRouteConfirm(route.name)` |
| `'Cancelar'` (any in this file) | `l.commonCancel` |
| `'Eliminar'` (button) | `l.commonDelete` |
| `'Editor de rutas'` | `l.editorTitle` |
| `'Nueva ruta'` (tooltip + button + dialog) | `l.editorNewRouteTooltip` / `l.editorNewRouteButton` / `l.editorNewRouteDialogTitle` (use the right key for the context) |
| `'Aún no tienes rutas'` | `l.editorNoRoutesTitle` |
| `'Crea tu primera ruta para empezar a cronometrar.'` | `l.editorNoRoutesMessage` |
| `'Sectores'` | `l.editorSectorsLabel` |
| `'Centro: ${...}, ${...}'` | `l.editorSectorCenter(lat, lng)` |
| `'Inicio / meta'` (label + segment) | `l.editorStartFinishLabel` / `l.editorSegmentStartFinish` |
| `'Creada el $date'` | `l.editorCreatedAt(formattedDate)` |
| `'Eliminar ruta'` (action button) | `l.editorDeleteRouteButton` |
| Mode labels at lines 230–232 | `l.editorModeAppendPath`, `l.editorModeStartGate`, `l.editorModeSectorGate` |
| `'Dibujando: ${draftName}'` | `l.editorDrawingTitle(draftName)` |
| `'Cancelar'` (tooltip) | `l.editorCancelTooltip` |
| `'Cancelar dibujo'` | `l.editorCancelDrawingTitle` |
| `'Se descartarán los puntos sin guardar.'` | `l.editorCancelDrawingWarning` |
| `'Volver'` | `l.commonBack` |
| `'Descartar'` | `l.commonDiscard` |
| `'Guardar'` | `l.commonSave` |
| `'Sin Mapbox token...'` | `l.editorNoMapboxToken` |
| `'Trazado'` (segment) | `l.editorSegmentPath` |
| `'Añadir sector'` (segment) | `l.editorSegmentAddSector` |
| `'Deshacer punto'` | `l.editorUndoPoint` |
| `'$count puntos'` | `l.editorPathPoints(count)` |
| `'Sin inicio'` / `'Inicio definido'` | `l.editorStartGateUndefined` / `l.editorStartGateDefined` |
| `'$count sectores'` | `l.editorSectorsCount(count)` |
| `'Falta el 2º punto…'` | `l.editorWaitingSecondPoint` |
| Difficulty labels (`Fácil`, `Media`, `Difícil`) — both the dropdown items at lines 431–433 and the explicit Spanish options at lines 507/509/511 | `l.editorDifficultyEasy`, `l.editorDifficultyMedium`, `l.editorDifficultyHard` |
| `'Nombre'` | `l.editorNameLabel` |
| `'Descripción (opcional)'` | `l.editorDescriptionLabel` |
| `'Dificultad'` | `l.editorDifficultyLabel` |
| `'Empezar a dibujar'` | `l.editorStartDrawingButton` |

- [ ] **Step 3: Run `flutter analyze`**

```bash
flutter analyze lib/src/features/editor/route_editor_screen.dart
```

Expected: no errors. Pay attention to `const` constructors — wherever a child uses a localized string, the parent cannot be `const`.

- [ ] **Step 4: Smoke widget test**

Create `movile_app/test/features/editor/route_editor_screen_l10n_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:splitway_mobile/src/config/app_config.dart';
import 'package:splitway_mobile/src/data/local/splitway_local_database.dart';
import 'package:splitway_mobile/src/data/repositories/local_draft_repository.dart';
import 'package:splitway_mobile/src/features/editor/route_editor_controller.dart';
import 'package:splitway_mobile/src/features/editor/route_editor_screen.dart';
import 'package:splitway_mobile/src/services/locale/locale_controller.dart';

Widget _harness({required Locale locale, required Widget child}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: LocaleController.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('route_editor renders Spanish title under es locale',
      (tester) async {
    late SplitwayLocalDatabase db;
    late RouteEditorController controller;
    await tester.runAsync(() async {
      db = await SplitwayLocalDatabase.open(
        overridePath: 'file:editor_test_es?mode=memory&cache=shared',
      );
      controller = RouteEditorController(LocalDraftRepository(db));
    });
    await tester.pumpWidget(_harness(
      locale: const Locale('es'),
      child: RouteEditorScreen(
        controller: controller,
        config: const AppConfig(),
      ),
    ));
    await tester.pump();
    expect(find.text('Editor de rutas'), findsOneWidget);
    controller.dispose();
    await db.close();
  });

  testWidgets('route_editor renders English title under en locale',
      (tester) async {
    late SplitwayLocalDatabase db;
    late RouteEditorController controller;
    await tester.runAsync(() async {
      db = await SplitwayLocalDatabase.open(
        overridePath: 'file:editor_test_en?mode=memory&cache=shared',
      );
      controller = RouteEditorController(LocalDraftRepository(db));
    });
    await tester.pumpWidget(_harness(
      locale: const Locale('en'),
      child: RouteEditorScreen(
        controller: controller,
        config: const AppConfig(),
      ),
    ));
    await tester.pump();
    expect(find.text('Route editor'), findsOneWidget);
    controller.dispose();
    await db.close();
  });
}
```

Run:

```bash
flutter test test/features/editor/route_editor_screen_l10n_test.dart
```

Expected: PASS, both tests.

- [ ] **Step 5: Commit**

```bash
git add movile_app/lib/src/features/editor/route_editor_screen.dart movile_app/test/features/editor/route_editor_screen_l10n_test.dart
git commit -m "i18n: localize route_editor_screen"
```

---

### Task 11: Migrate `history_screen.dart`

**Files:**
- Modify: `movile_app/lib/src/features/history/history_screen.dart`

- [ ] **Step 1: Add import and replace literals**

Add:

```dart
import 'package:splitway_mobile/l10n/app_localizations.dart';
```

Add `final l = AppLocalizations.of(context);` at the top of every `build`/builder that contains Spanish strings.

Replacement table:

| Literal | Replacement |
|---|---|
| `'Historial'` | `l.historyTitle` |
| `'Recargar'` | `l.commonRefresh` |
| `'Aún no has grabado ninguna sesión'` | `l.historyNoSessionsTitle` |
| `'Ve a la pestaña Sesión, elige una ruta y pulsa "Comenzar".'` | `l.historyNoSessionsMessage` |
| `'Ruta eliminada'` | `l.historyDeletedRoute` |
| Subtitle building `'$date · $lapCount vuelta(s)$bestLap'` | `l.historySessionSubtitle(date: formattedDate, lapCount: lapCount, bestLap: bestLapSuffix)` — note that `bestLap` becomes part of the placeholder so callers pre-compute the suffix (e.g. `' · ${formatted}'` or empty string) |
| `'Sesión'` | `l.historySessionTitle` |
| `'Eliminar sesión'` | `l.historyDeleteSessionTitle` |
| `'Esta acción no se puede deshacer.'` | `l.historyIrreversibleWarning` |
| `'Cancelar'` | `l.commonCancel` |
| `'Eliminar'` | `l.commonDelete` |
| `'Sesión no encontrada'` | `l.historySessionNotFound` |
| `'Vueltas'` | `l.historyLapsLabel` |
| `'Sectores'` | `l.historySectorsLabel` |
| `'Vuelta $lapNum · $speed'` | `l.historySectorSubtitle(lapNum, speed)` |
| `'Distancia'` | `l.historyDistanceLabel` |
| `'Vel. máx'` | `l.historyMaxSpeedLabel` |
| `'Vel. media'` | `l.historyAvgSpeedLabel` |

- [ ] **Step 2: Run `flutter analyze`**

```bash
flutter analyze lib/src/features/history/history_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Smoke test**

Create `movile_app/test/features/history/history_screen_l10n_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:splitway_mobile/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:splitway_mobile/src/data/local/splitway_local_database.dart';
import 'package:splitway_mobile/src/data/repositories/local_draft_repository.dart';
import 'package:splitway_mobile/src/features/history/history_screen.dart';
import 'package:splitway_mobile/src/services/locale/locale_controller.dart';

Widget _harness({required Locale locale, required Widget child}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: LocaleController.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('history empty state in Spanish', (tester) async {
    late SplitwayLocalDatabase db;
    late LocalDraftRepository repo;
    await tester.runAsync(() async {
      db = await SplitwayLocalDatabase.open(
        overridePath: 'file:history_test_es?mode=memory&cache=shared',
      );
      repo = LocalDraftRepository(db);
    });
    await tester.pumpWidget(_harness(
      locale: const Locale('es'),
      child: HistoryScreen(repository: repo),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
    }
    expect(find.text('Aún no has grabado ninguna sesión'), findsOneWidget);
    await repo.dispose();
    await db.close();
  });

  testWidgets('history empty state in English', (tester) async {
    late SplitwayLocalDatabase db;
    late LocalDraftRepository repo;
    await tester.runAsync(() async {
      db = await SplitwayLocalDatabase.open(
        overridePath: 'file:history_test_en?mode=memory&cache=shared',
      );
      repo = LocalDraftRepository(db);
    });
    await tester.pumpWidget(_harness(
      locale: const Locale('en'),
      child: HistoryScreen(repository: repo),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
    }
    expect(find.text('No sessions recorded yet'), findsOneWidget);
    await repo.dispose();
    await db.close();
  });
}
```

Run:

```bash
flutter test test/features/history/history_screen_l10n_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add movile_app/lib/src/features/history/history_screen.dart movile_app/test/features/history/
git commit -m "i18n: localize history_screen"
```

---

### Task 12: Migrate `live_session_screen.dart`

**Files:**
- Modify: `movile_app/lib/src/features/session/live_session_screen.dart`

- [ ] **Step 1: Add import and replace literals**

Add:

```dart
import 'package:splitway_mobile/l10n/app_localizations.dart';
```

Add `final l = AppLocalizations.of(context);` at the top of each `build`/builder. Replacements:

| Literal | Replacement |
|---|---|
| `'Sesión en vivo'` | `l.sessionTitle` |
| `'No hay rutas para correr'` | `l.sessionNoRoutesTitle` |
| `'Crea una ruta primero...'` | `l.sessionNoRoutesMessage` |
| `'Selecciona una ruta'` | `l.sessionSelectRoute` |
| `'Fuente de telemetría'` | `l.sessionTelemetrySource` |
| `'Simulada'` | `l.sessionSourceSimulated` |
| `'GPS real'` | `l.sessionSourceRealGps` |
| `'Comenzar grabación'` | `l.sessionStartButton` |
| Hint for simulated mode | `l.sessionSimulatedHint` |
| Hint for real-GPS mode | `l.sessionRealGpsHint` |
| `'Sesión guardada'` | `l.sessionSavedSnackBar` |
| `'Finalizar y guardar'` | `l.sessionFinishButton` |
| `'Sesión completa'` | `l.sessionCompleteTitle` |
| `'Ruta: $routeName'` | `l.sessionRouteLabel(routeName)` |
| `'Vueltas'` (laps label + count label) | `l.sessionLapsLabel` / `l.sessionLapsCountLabel` (use the right one) |
| `'Nueva sesión'` | `l.sessionNewSessionButton` |
| `'Vuelta actual'` | `l.sessionCurrentLapLabel` |
| `'#$n'` (current lap number) | `l.sessionLapNumber(n)` |
| `'–'` (no lap placeholder) | `l.sessionNoLapYet` |
| `'Tiempo en vuelta'` | `l.sessionLapTimeLabel` |
| `'Mejor vuelta'` | `l.sessionBestLapLabel` |
| `'Esperando primer cruce de meta…'` | `l.sessionAwaitingStart` |
| `'Cruzando sectores…'` | `l.sessionCrossingSectors` |
| `'Último sector: $id'` | `l.sessionLastSector(id)` |
| `'Distancia'` | `l.sessionDistanceLabel` |
| `'Vel. máx.'` | `l.sessionMaxSpeedLabel` |
| `'Vel. media'` | `l.sessionAvgSpeedLabel` |
| `'Permiso de ubicación concedido.'` | `l.sessionPermissionGranted` |
| `'Permiso de ubicación denegado...'` | `l.sessionPermissionDenied` |
| `'Permiso bloqueado permanentemente...'` | `l.sessionPermissionPermanentlyDenied` |
| `'Servicios de ubicación desactivados...'` | `l.sessionServicesDisabled` |
| `'GPS real · $count muestras'` | `l.sessionGpsStatus(count)` |
| `'Precisión: $accuracy m · $lat, $lng'` | `l.sessionGpsAccuracy(accuracy, lat, lng)` |
| `'Esperando primer fix…'` | `l.sessionAwaitingFirstFix` |
| `'Simular punto'` | `l.sessionSimulatePoint` |
| `'Parar auto'` | `l.sessionPauseAuto` |
| `'Auto vuelta'` | `l.sessionAutoLap` |

- [ ] **Step 2: Run `flutter analyze`**

```bash
flutter analyze lib/src/features/session/live_session_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Smoke test**

Create `movile_app/test/features/session/live_session_screen_l10n_test.dart` modelled on the editor/history smoke tests; assert `find.text('Sesión en vivo')` under `es` and `find.text('Live session')` under `en`. (Use `LiveSessionController(LocalDraftRepository(db))` with an in-memory db.)

Run:

```bash
flutter test test/features/session/live_session_screen_l10n_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add movile_app/lib/src/features/session/live_session_screen.dart movile_app/test/features/session/
git commit -m "i18n: localize live_session_screen"
```

---

### Task 13: Make `Formatters` locale-aware

**Files:**
- Modify: `movile_app/lib/src/shared/formatters.dart`

- [ ] **Step 1: Replace `Formatters` to drop hard-coded `'es_ES'`**

Open `movile_app/lib/src/shared/formatters.dart` and replace its contents with:

```dart
import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String duration(Duration d) {
    final ms = d.inMilliseconds;
    if (ms < 0) return '--:--.---';
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final millis = ms % 1000;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }

  /// Returns just the numeric portion. The caller wraps it with the localized
  /// unit using `AppLocalizations.unitMeters` / `unitKilometers`.
  static (double value, bool isKilometers) distanceMeters(double meters) {
    if (meters < 1000) return (meters, false);
    return (meters / 1000, true);
  }

  /// Returns just the numeric portion in km/h. The caller wraps it with
  /// `AppLocalizations.unitKmh`.
  static double speedMps(double mps) => mps * 3.6;

  /// Uses `Intl.defaultLocale` set by `LocaleController`.
  static String dateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy · HH:mm').format(dt);
  }
}
```

- [ ] **Step 2: Update every call site of `Formatters.distanceMeters` and `Formatters.speedMps`**

Find them:

```bash
grep -rn "Formatters.distanceMeters\|Formatters.speedMps" movile_app/lib movile_app/test
```

For each call, replace the bare string with a localized wrapper. Example pattern:

Before:

```dart
Text(Formatters.distanceMeters(meters))
```

After:

```dart
final (value, isKm) = Formatters.distanceMeters(meters);
final formatted = (isKm
    ? AppLocalizations.of(context).unitKilometers(value.toStringAsFixed(2))
    : AppLocalizations.of(context).unitMeters(value.toStringAsFixed(0)));
Text(formatted);
```

Speed:

```dart
final kmh = Formatters.speedMps(mps);
final formatted = AppLocalizations.of(context).unitKmh(kmh.toStringAsFixed(1));
```

Apply this transformation everywhere `Formatters.distanceMeters` or `Formatters.speedMps` is called inside a widget. In tests or non-widget code, fall back to building the string with `' m'` / `' km'` / `' km/h'` literals — these are not user-visible in tests.

- [ ] **Step 3: Run `flutter analyze`**

```bash
flutter analyze
```

Fix any errors. Common gotcha: `formatters.dart` no longer accepts a `String`; you must read the tuple. Any test that compared against `'500 m'` may need updating — keep test assertions tolerant by checking for `find.textContaining('500')` instead, or set the test locale and assert the full localized string.

- [ ] **Step 4: Run tests**

```bash
flutter test
```

Expected: PASS. Fix any breakages now.

- [ ] **Step 5: Commit**

```bash
git add movile_app/lib/src/shared/formatters.dart movile_app/lib/src/features/ movile_app/lib/src/shared/widgets/ movile_app/test
git commit -m "i18n: drop hard-coded es_ES locale from Formatters; route unit labels through ARB"
```

---

## Phase C — Test alignment and cleanup

### Task 14: Update existing tests to set an explicit locale

**Files:**
- Modify: `movile_app/test/widget_test.dart`
- Modify: `movile_app/integration_test/app_test.dart`

The existing tests use plain `MaterialApp` (no localization delegates) and assert hard-coded Spanish. With Task 7+, widgets call `AppLocalizations.of(context)` which requires delegates. We add delegates and pin the test locale to `'es'` so the existing Spanish assertions still hold.

- [ ] **Step 1: Update `widget_test.dart`**

Add imports:

```dart
import 'package:splitway_mobile/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
```

Replace every `MaterialApp(home: ...)` in the file with:

```dart
MaterialApp(
  locale: const Locale('es'),
  supportedLocales: const [Locale('es'), Locale('en')],
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: <the existing home>,
)
```

The existing Spanish assertions (`'Aún no has grabado ninguna sesión'`, `'Pista demo (Madrid)'`) keep working because the test locale is `'es'` and that Spanish string exists in `app_es.arb`.

- [ ] **Step 2: Update `integration_test/app_test.dart`**

The integration test pumps the full `SplitwayApp`, which now requires a `LocaleController`. Wherever the test bootstraps the app, construct one explicitly:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:splitway_mobile/src/services/locale/locale_controller.dart';

// inside setUp / inside the test bootstrap:
SharedPreferences.setMockInitialValues({'locale': 'es'});
final localeController = await LocaleController.load(
  deviceLocale: const Locale('es'),
);
// Pass localeController to SplitwayApp(...) when constructing it.
```

Update the `SplitwayApp(...)` constructor call in the test to pass `localeController: localeController`. The existing Spanish assertions (`'Editor'`, `'Sesión'`, `'Historial'`, `'Aún no has grabado ninguna sesión'`, `'Comenzar grabación'`, `'Simular punto'`, `'Finalizar y guardar'`, `'Sesión completa'`, `'Sesión guardada'`) all map to existing keys in `app_es.arb` and will keep passing under `Locale('es')`.

- [ ] **Step 3: Run all tests**

```bash
flutter test
flutter test integration_test/app_test.dart
```

Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add movile_app/test/widget_test.dart movile_app/integration_test/app_test.dart
git commit -m "test(i18n): pin existing tests to Locale('es') and wire localizations delegates"
```

---

### Task 15: Manual end-to-end smoke + final verification

**Files:** none (manual)

- [ ] **Step 1: Run `flutter analyze` for the full project**

```bash
flutter analyze
```

Expected: zero errors. Address any leftover unused imports, `const` issues, or unresolved references.

- [ ] **Step 2: Run the full automated test suite**

```bash
flutter test
flutter test integration_test/app_test.dart
```

Expected: all PASS.

- [ ] **Step 3: Manual device test**

Launch:

```bash
flutter run -d <device>
```

Verify:
1. App opens in Spanish by default (device locale is `es-ES` or stored preference).
2. Open the drawer → tap "Configuración" → Settings screen opens.
3. Tap "Inglés" — the entire UI updates immediately to English:
   - Bottom nav: "Editor / Session / History"
   - Drawer "Sign out", menu items in English
   - Route editor, history, live session titles all in English
   - Date formatting on the history screen switches to English month abbreviations
4. Kill and relaunch the app — language stays English.
5. Switch back to Spanish — confirm same behaviour.
6. (If logged out) sign-in flow shows English login screen including validator messages and Google button label.
7. Force an auth error (wrong password) → confirm the localized error string appears in the active language.

- [ ] **Step 4: Final commit (if any small fixes)**

If steps 1–3 surfaced fixes:

```bash
git add -A
git commit -m "fix(i18n): post-smoke-test corrections"
```

If no fixes needed, no commit.

---

## Self-Review (already performed by plan author)

- **Spec coverage:** infrastructure ✓, all listed screens migrated ✓, language picker ✓, persistence in `shared_preferences` ✓, Spanish + English support ✓.
- **Placeholder scan:** none — every key has its Spanish *and* English value spelled out in Task 2; every replacement in Tasks 7–12 names the exact key.
- **Type consistency:** `AppLocalizations` is the generated class; `LocaleController` constructor / `setLocale` / `load` named identically everywhere; `AuthErrorCode` enum reused in both `auth_service.dart` and `login_screen.dart`.
- **Known follow-ups (out of scope):** the drawer "Estadísticas" and "Ayuda" items are still navigation TODOs (no destinations); the "v0.4.0" version literal is hard-coded — fine for now since it's the actual app version. These exist in the current codebase and are not regressions.
