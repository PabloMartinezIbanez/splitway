# Supabase backend

> **Estado (iter 3):** Migración con `owner_id` + RLS activo. Edge Function
> `mapbox-routing` lista para deploy. La app móvil inicializa Supabase
> automáticamente si `env/local.json` contiene las credenciales.

## Estructura

- `config.toml` — configuración del proyecto Supabase local.
- `migrations/`
  - `20260429000000_initial_schema.sql` — esquema base (4 tablas).
  - `20260504000000_add_owner_rls.sql` — añade `owner_id`, `updated_at`, RLS policies.
- `functions/`
  - `mapbox-routing/index.ts` — Edge Function que proxea Map Matching de Mapbox.

## Setup

### 1. Vincular proyecto

```bash
supabase link --project-ref <tu-project-ref>
```

### 2. Aplicar migraciones

```bash
supabase db push
```

### 3. Configurar secretos para la Edge Function

```bash
supabase secrets set MAPBOX_SERVER_TOKEN=sk.ey...
```

### 4. Desplegar la Edge Function

```bash
supabase functions deploy mapbox-routing
```

### 5. Configurar la app móvil

Copiar `movile_app/env/local.example.json` a `movile_app/env/local.json` y rellenar:

```json
{
  "SUPABASE_URL": "https://xxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJ...",
  "MAPBOX_ACCESS_TOKEN": "pk.ey..."
}
```

Descomentar la sección `assets` en `movile_app/pubspec.yaml` para que Flutter
incluya el archivo en el bundle:

```yaml
flutter:
  assets:
    - env/local.json
```

## RLS (Row-Level Security)

Todas las tablas tienen RLS activado. Cada fila pertenece a un usuario
(`owner_id = auth.uid()`). Las políticas permiten SELECT/INSERT/UPDATE/DELETE
solo sobre filas propias. Los sectores heredan ownership a través de su
`route_id` FK.

## Edge Function: mapbox-routing

Proxea llamadas al [Mapbox Map Matching API](https://docs.mapbox.com/api/navigation/map-matching/)
para que el token secreto de Mapbox nunca salga del servidor.

**POST** `/functions/v1/mapbox-routing`

```json
{
  "coordinates": [[lng, lat], [lng, lat], ...],
  "profile": "driving",
  "radiuses": [25, 25, ...],
  "timestamps": [1234567890, ...]
}
```

Requiere header `Authorization: Bearer <supabase-jwt>`.
