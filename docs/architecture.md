# Arquitectura — Splitway (Iteración 1)

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
│  • LiveSessionController                                   │
│  • LiveTrackingController  (envuelve el motor)             │
└─────────────┬──────────────────────────────────────────────┘
              │ async repository API
┌─────────────▼──────────────────────────────────────────────┐
│ Datos                                                      │
│  • LocalDraftRepository (CRUD + sync stub)                 │
│  • SplitwayLocalDatabase (sqflite)                         │
└─────────────┬──────────────────────────────────────────────┘
              │
┌─────────────▼──────────────────────────────────────────────┐
│ Integraciones                                              │
│  • SQLite local (sqflite)            ← fuente de verdad    │
│  • Mapbox / Geolocator / Supabase   ← stub en iter 1       │
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

## Detección de cruces (gates)

Una "gate" es un segmento perpendicular a la ruta definido por dos `GeoPoint`
(`left` y `right`). Para decidir si la trayectoria del jugador entre dos
puntos GPS consecutivos cruzó esa gate se usa el algoritmo CCW de orientación
(producto cruz). Se rechazan los casos colineales y los toques tangenciales
para evitar disparos espurios bajo ruido GPS — sólo cuenta el cruce estricto.

## Decisiones clave

1. **Offline-first**: SQLite es la fuente de verdad. Supabase será una copia
   de seguridad opcional (iter 2).
2. **Core separado**: `splitway_core` no depende de Flutter. Esto permite
   testear el motor en CI puro y reutilizarlo en otros contextos.
3. **State management ligero**: `ChangeNotifier` + listeners nativos. No se
   añade `provider`, `riverpod` ni `bloc` para iter 1 — la app es pequeña.
4. **Mapa placeholder**: en iter 1 las pantallas usan `CustomPainter` para
   pintar la ruta. En iter 2 se reemplaza por `mapbox_maps_flutter`.
5. **Simulación de GPS**: `LiveSessionController` incluye un modo
   simulación que avanza por puntos sintéticos, así el motor se valida
   end-to-end sin necesidad de moverse físicamente. En iter 2 se conectará
   `Geolocator.getPositionStream()` detrás del flag
   `AppConfig.realGpsEnabled`.

## Tablas SQLite

| Tabla              | Función                                                  |
| ------------------ | -------------------------------------------------------- |
| `route_templates`  | Cada ruta dibujada con su geometría base y dificultad.   |
| `sectors`          | Sectores intermedios de cada ruta (gates ordenadas).     |
| `session_runs`     | Cada grabación: estado, vueltas, sectores, métricas.     |
| `telemetry_points` | Puntos GPS individuales asociados a una sesión.          |

La estructura es paralela al `supabase/migrations/20260429000000_initial_schema.sql`
para que la sincronización iter 2 sea un mapeo casi 1-a-1.
