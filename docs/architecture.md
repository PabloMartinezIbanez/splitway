# Arquitectura — Splitway (Iteración 3)

Este documento es un resumen breve. La especificación completa de
funcionamiento está en
[`PROYECTO_COMPLETO_CONCEPTUAL.md`](../../../splitway_prueba/PROYECTO_COMPLETO_CONCEPTUAL.md)
(ruta del proyecto fuente del que se replica).

## Capas

```
┌────────────────────────────────────────────────────────────┐
│ Presentación (Flutter)                                     │
│  • RouteEditorScreen   • LiveSessionScreen   • HistoryScreen│
│  • HomeShell con bottom navigation (go_router)             │
└─────────────┬──────────────────────────────────────────────┘
              │ ChangeNotifier listeners
┌─────────────▼──────────────────────────────────────────────┐
│ Lógica (Controllers + Servicios)                           │
│  • RouteEditorController                                   │
│  • LiveSessionController  (simulated + real GPS)           │
│  • LiveTrackingController  (envuelve el motor)             │
│  • SyncService  (bidirectional SQLite ↔ Supabase)          │
└─────────────┬──────────────────────────────────────────────┘
              │ async repository API
┌─────────────▼──────────────────────────────────────────────┐
│ Datos                                                      │
│  • LocalDraftRepository (CRUD local, SQLite)               │
│  • SupabaseRepository (CRUD remoto, Postgres + RLS)        │
│  • SplitwayLocalDatabase (sqflite)                         │
└─────────────┬──────────────────────────────────────────────┘
              │
┌─────────────▼──────────────────────────────────────────────┐
│ Integraciones                                              │
│  • SQLite local (sqflite)            ← fuente de verdad    │
│  • Supabase (supabase_flutter)       ← backup + multi-device│
│  • Mapbox (mapbox_maps_flutter)      ← mapa + routing      │
│  • Geolocator                        ← GPS real            │
└────────────────────────────────────────────────────────────┘
```

El paquete `packages/splitway_core` es **Dart puro** y vive fuera de Flutter.
Contiene los modelos del dominio (rutas, sesiones, sectores, telemetría) y el
motor de tracking — todo testeable con `dart test`.

## Flujo de un punto GPS

```
GPS / simulador
      │  (TelemetryPoint)
      ▼
LiveTrackingController.ingestSimulatedPoint()
      │
      ▼
TrackingEngine.ingest()
      │  ├─ acumula distancia (haversine)
      │  ├─ comprueba cruce con startFinishGate
      │  ├─ comprueba cruce con el siguiente sector
      │  └─ emite eventos: TrackingStarted | SectorCrossed | LapClosed
      ▼
ChangeNotifier.notifyListeners()  →  UI se reconstruye
```

Cuando se finaliza, el motor emite `TrackingFinished`, devuelve un
`SessionRun` y el `LiveSessionController` lo persiste vía
`LocalDraftRepository.saveSessionRun(...)`.

## Sincronización con Supabase

```
SQLite (local)                    Supabase (cloud)
     │                                  │
     └───── SyncService.sync() ─────────┘
              ├─ Push: rutas/sesiones locales nuevas o más recientes
              └─ Pull: rutas/sesiones remotas nuevas o más recientes
```

Estrategia **last-write-wins** basada en `updated_at`. La sincronización
es manual (el usuario la lanza desde la UI). La app funciona completamente
offline; Supabase es opcional para backup y multi-dispositivo.

RLS protege todas las tablas: cada fila tiene `owner_id = auth.uid()` y
sólo el propietario puede leer/escribir sus datos.

## Edge Function: mapbox-routing

La Edge Function `mapbox-routing` proxea llamadas al Mapbox Map Matching API
para que el token secreto de Mapbox nunca se exponga en el cliente. El
cliente envía coordenadas GPS crudas y recibe la geometría snapped a
carreteras reales.

## Detección de cruces (gates)

Una "gate" es un segmento perpendicular a la ruta definido por dos `GeoPoint`
(`left` y `right`). Para decidir si la trayectoria del jugador entre dos
puntos GPS consecutivos cruzó esa gate se usa el algoritmo CCW de orientación
(producto cruz). Se rechazan los casos colineales y los toques tangenciales
para evitar disparos espurios bajo ruido GPS — sólo cuenta el cruce estricto.

## Decisiones clave

1. **Offline-first**: SQLite es la fuente de verdad. Supabase es una copia
   de seguridad opcional y canal de sincronización multi-dispositivo.
2. **Core separado**: `splitway_core` no depende de Flutter. Esto permite
   testear el motor en CI puro y reutilizarlo en otros contextos.
3. **State management ligero**: `ChangeNotifier` + listeners nativos. No se
   añade `provider`, `riverpod` ni `bloc` — la app es pequeña.
4. **Mapa condicional**: `SplitwayMap` usa Mapbox real si hay token, o
   `CustomPainter` como fallback (permite tests sin SDK nativo).
5. **Dual-source tracking**: `LiveSessionController` soporta modo simulación
   (puntos sintéticos) y GPS real (`Geolocator.getPositionStream()`) con
   fallback automático si se deniegan permisos.
6. **Mapbox APIs modernas**: `CameraViewportState` para la cámara inicial,
   `TapInteraction.onMap` / `LongTapInteraction.onMap` para gestos
   (migrado desde las APIs deprecadas en iter 3).

## Tablas (SQLite local + Supabase Postgres)

| Tabla              | Función                                                  |
| ------------------ | -------------------------------------------------------- |
| `route_templates`  | Cada ruta dibujada con su geometría base y dificultad.   |
| `sectors`          | Sectores intermedios de cada ruta (gates ordenadas).     |
| `session_runs`     | Cada grabación: estado, vueltas, sectores, métricas.     |
| `telemetry_points` | Puntos GPS individuales asociados a una sesión.          |

La estructura local y la remota son paralelas. La migración SQL
`20260504000000_add_owner_rls.sql` añade `owner_id`, `updated_at` y
políticas RLS sobre el esquema base.

## Tests

- **Unit tests** (`packages/splitway_core`): geometría + motor → 13 tests.
- **Widget tests** (`movile_app/test/`): DB + seed, repo round-trip, render
  de pantallas individuales → 4 tests.
- **Integration tests** (`movile_app/integration_test/`): flujos end-to-end
  en dispositivo real (navegar tabs, simular sesión, verificar historial).
