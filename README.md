# Splitway

Cronómetro inteligente para rutas — dibujas una ruta con sectores, mientras
te desplazas la app detecta cada cruce de gate por GPS y registra los
tiempos. Funciona offline; sincronización a la nube es opcional.

> **Estado:** iteración 2 en marcha. La estructura del monorepo, el motor de
> tracking, SQLite, las 3 pantallas y el mapa **Mapbox** real con dibujo de
> rutas a tap están funcionando. Pendiente: GPS real (Geolocator) + Supabase
> sync (iter 2.5 / 3).

## Estructura del repo

```
.
├── movile_app/                Flutter app (Android-first)
├── packages/
│   └── splitway_core/         Paquete Dart puro: modelos + motor de tracking
├── supabase/                  Backend (placeholder, iter 3)
└── docs/
    └── architecture.md        Resumen de arquitectura
```

## Empezar

### 1. Requisitos

- Flutter 3.27+ (probado con 3.41.8).
- Dart 3.5+ (incluido con Flutter).
- Android Studio o un emulador / dispositivo Android.
- Cuenta en [Mapbox](https://account.mapbox.com/) con dos tokens:
  - **Public access token** (runtime, va en `env/local.json`).
  - **Downloads token** con scope `Downloads:Read` (build-time, va en
    `~/.gradle/gradle.properties` como `MAPBOX_DOWNLOADS_TOKEN`).

### 2. Instalar dependencias

```bash
# Paquete core (Dart puro)
cd packages/splitway_core && dart pub get

# App móvil
cd ../../movile_app && flutter pub get
```

### 3. Configurar credenciales

Copia `movile_app/env/local.example.json` a `movile_app/env/local.json` y
rellena `MAPBOX_ACCESS_TOKEN`. Sin él, la app arranca igualmente: cada
pantalla usa un placeholder pintado con `CustomPainter` en vez del mapa
real.

Para que el SDK nativo de Mapbox compile en Android necesitas además
añadir tu token de descargas a `~/.gradle/gradle.properties`:

```
MAPBOX_DOWNLOADS_TOKEN=sk.eyJ1...
```

(o exportarlo como variable de entorno con el mismo nombre antes de
`flutter run`).

### 4. Ejecutar tests

```bash
# Tests del motor (sin Flutter)
cd packages/splitway_core && dart test

# Tests de la app móvil
cd ../../movile_app && flutter test
```

### 5. Análisis estático

```bash
cd movile_app && flutter analyze
```

### 6. Lanzar la app

```bash
cd movile_app && flutter run
```

Al primer arranque se siembra una ruta demo (Pista demo Madrid). Puedes:

- **Editor**: ver el mapa Mapbox real con la ruta demo. Pulsa el botón
  `+` para dibujar una nueva: introduce nombre y dificultad y entra en
  modo dibujo. Toca el mapa para añadir puntos al trazado, cambia a
  "Inicio / meta" y haz 2 toques para definir la línea de meta, y a
  "Añadir sector" para puertas intermedias. Pulsa "Guardar" cuando
  estén el trazado (≥2 puntos) y la línea de meta.
- **Sesión**: elige una ruta, pulsa "Comenzar". Usa "Simular punto" o
  "Auto vuelta" para ejercitar el motor con un script sintético; en
  iter 2.5 esto se conectará al GPS real (Geolocator).
- **Historial**: revisa las sesiones guardadas con sus vueltas y
  sectores. Cada sesión muestra la traza GPS en el mapa Mapbox.

## Iteraciones siguientes

- **Iter 2.5**: GPS real con `Geolocator.getPositionStream()`, permisos
  Android, flag `AppConfig.realGpsEnabled`.
- **Iter 3**: Supabase auth + sync, Edge Function `mapbox-routing` para
  Map-Matching que ajuste la ruta dibujada a calles reales.
- Más ideas (perfiles, compartir rutas, climatología) en
  [`Future_Ideas.md`](Future_Ideas.md).

## Documentación

- [`docs/architecture.md`](docs/architecture.md) — capas, flujos de datos,
  decisiones clave.
- [`supabase/README.md`](supabase/README.md) — estado del backend.
