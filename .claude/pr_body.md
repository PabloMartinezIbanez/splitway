## Resumen

Replica la app Splitway descrita en `PROYECTO_COMPLETO_CONCEPTUAL.md` partiendo del Flutter init mínimo. Tres iteraciones encadenadas, escritas desde cero (sin mirar el repo de referencia):

- **iter 1** (`c1b5eda`): monorepo + paquete Dart puro `splitway_core` (modelos + motor de tracking) + SQLite + 3 pantallas con datos demo.
- **iter 2** (`5de9aad`): Mapbox real con `mapbox_maps_flutter` + dibujo de rutas a tap (chips de modo "Trazado / Inicio-meta / Sector"). Fallback automático a `CustomPainter` cuando no hay token.
- **iter 2.5** (`f0caf5f`): GPS real con `geolocator` y `LocationService`. `SegmentedButton` "Simulada / GPS real" en la sesión, banner de estado de permisos y tile de muestras + precisión durante la grabación.

## Verificación

- `dart test` (`packages/splitway_core`): **13/13** verde.
- `flutter analyze` (`movile_app`): **0 issues**.
- `flutter test` (`movile_app`): **4/4** verde — DB+seed, repo round-trip, render del editor, empty state del historial.

## Estructura tras los 3 commits

```
.
├── movile_app/                          (Flutter app)
│   └── lib/src/
│       ├── app.dart, config/, routing/
│       ├── data/local/, data/repositories/, data/demo/
│       ├── features/{home,editor,session,history}/
│       ├── services/tracking/{live_tracking,location_service}.dart
│       └── shared/widgets/{splitway_map,route_map_painter,empty_state}.dart
├── packages/splitway_core/              (Dart puro: 10 modelos + motor + tests)
├── supabase/                            (placeholder iter 3: config.toml + migración SQL + README)
└── docs/architecture.md
```

## Notas para el revisor

- **Dos tokens Mapbox son necesarios** para correr la app con mapa real:
  - `MAPBOX_ACCESS_TOKEN` (público, runtime) en `movile_app/env/local.json`.
  - `MAPBOX_DOWNLOADS_TOKEN` (Downloads:Read, build-time Android) en `~/.gradle/gradle.properties`.

  Sin ninguno: la app sigue funcionando con el `CustomPainter` placeholder y el modo simulación, así los tests no necesitan secretos.

- **Test estrategia**: el smoke test monta cada pantalla por separado con `MaterialApp` simple. Bootear el `SplitwayApp` completo con `MaterialApp.router` + `StatefulShellRoute.indexedStack` cuelga `pumpWidget` en flutter_test 3.41.8. Iter 3 debería migrar a `integration_test` para cobertura end-to-end.

- **`movile_app/`** mantiene la `i` que falta (no es typo a corregir aquí — se mantiene como pediste). Los imports de paquete usan `splitway_mobile` (definido en pubspec).

- **APIs deprecadas de Mapbox** (`cameraOptions`, `onTapListener`, `onLongTapListener`) marcadas con `// ignore: deprecated_member_use`. Migración a `viewport` + `MapboxMap.addInteraction` queda para un futuro iter 2.6 — requiere recablear las interacciones a través del `MapboxMap` controller.

- **Supabase** queda como placeholder. La migración SQL está lista en `supabase/migrations/20260429000000_initial_schema.sql` (sin RLS — pendiente para cuando exista cuenta Supabase + `auth.uid()` cableado).

## Plan de iteración 3 (sugerido, fuera de scope)

1. Migrar APIs deprecadas de Mapbox.
2. Cuenta Supabase + RLS + `LocalDraftRepository.syncWithCloud()`.
3. Edge Function `mapbox-routing` con Map-Matching.
4. Test end-to-end con `integration_test`.

## Test plan

- [ ] `cd packages/splitway_core && dart test` → 13 tests verde
- [ ] `cd movile_app && flutter analyze` → 0 issues
- [ ] `cd movile_app && flutter test` → 4 tests verde
- [ ] Configurar tokens Mapbox y `flutter run` en un dispositivo Android
- [ ] Crear ruta desde el editor (tap-to-draw → start gate → sector → guardar)
- [ ] Lanzar sesión en modo "Simulada" con auto-vuelta y verificar tiempos de vuelta
- [ ] Cambiar a "GPS real" en la sesión y verificar el banner de permisos
- [ ] Comprobar que el historial muestra la sesión guardada con su mapa de telemetría
- [ ] Reiniciar la app: la ruta y la sesión persisten (SQLite OK)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
