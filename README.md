# Splitway

Cronómetro inteligente para rutas — dibujas una ruta con sectores, mientras
te desplazas la app detecta cada cruce de gate por GPS y registra los
tiempos. Funciona offline; sincronización a la nube es opcional.

> **Estado:** iteración 1. La estructura del monorepo, el motor de tracking,
> la base de datos local y las 3 pantallas están funcionando con datos de
> demostración. Mapbox real, GPS real y sincronización Supabase llegan en la
> iteración 2.

## Estructura del repo

```
.
├── movile_app/                Flutter app (Android-first)
├── packages/
│   └── splitway_core/         Paquete Dart puro: modelos + motor de tracking
├── supabase/                  Backend (placeholder, iter 2)
└── docs/
    └── architecture.md        Resumen de arquitectura
```

## Empezar

### 1. Requisitos

- Flutter 3.27+ (probado con 3.41.8).
- Dart 3.5+ (incluido con Flutter).
- Android Studio o un emulador / dispositivo Android.

### 2. Instalar dependencias

```bash
# Paquete core (Dart puro)
cd packages/splitway_core && dart pub get

# App móvil
cd ../../movile_app && flutter pub get
```

### 3. Configurar credenciales (opcional, iter 2)

Copia `movile_app/env/local.example.json` a `movile_app/env/local.json` y
rellena tu Mapbox token. En iter 1 la app no las usa — son sólo placeholders
para iter 2.

### 4. Ejecutar tests

```bash
# Tests del motor (sin Flutter)
cd packages/splitway_core && dart test

# Tests de la app móvil (smoke test)
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

- **Editor**: ver la ruta demo y crear nuevas rutas placeholder con dificultad.
- **Sesión**: elegir una ruta, pulsar "Comenzar", usar "Simular punto" o "Auto vuelta" para ejercitar el motor sin GPS, y "Finalizar" para guardar.
- **Historial**: revisar las sesiones guardadas con sus vueltas y sectores.

## Iteraciones siguientes (resumen)

- Iter 2: Mapbox real, GPS real (Geolocator), Supabase auth + sync, Edge
  Function `mapbox-routing` para Map-Matching.
- Iter 3: ideas en [`Future_Ideas.md`](Future_Ideas.md) — perfiles, compartir
  rutas, condiciones meteorológicas, etc.

## Documentación

- [`docs/architecture.md`](docs/architecture.md) — capas, flujos de datos,
  decisiones clave.
- [`supabase/README.md`](supabase/README.md) — estado del backend.
