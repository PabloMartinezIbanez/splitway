# Supabase backend

> **Estado (iter 1):** placeholder. La app móvil aún no se conecta a Supabase.
> Esto se rellenará en la siguiente iteración con migraciones reales,
> políticas RLS, Edge Functions de Mapbox routing y un script
> `start-local-secure.ps1`.

## Estructura prevista

- `config.toml` — configuración del proyecto Supabase local (esqueleto en este iter).
- `migrations/` — definiciones SQL versionadas con timestamp.
  - `20260429_initial_schema.sql` — esquema base equivalente al SQLite local.
- `functions/` — Edge Functions Deno/TypeScript.
  - Pendiente: `mapbox-routing/` (Map-Matching + Directions).

## Cómo se rellenará en iter 2

1. Crear proyecto Supabase: `supabase init` (si no se hizo ya) y vincularlo al proyecto cloud.
2. Levantar el stack local: `supabase start`.
3. Aplicar migraciones: `supabase db push`.
4. Activar políticas RLS — ahora mismo el SQL viene **sin** RLS para iterar rápido,
   pero antes de exponer el proyecto debe activarse y restringir lectura/escritura
   por `auth.uid() = owner_id`.
5. Subir Edge Function de Mapbox: `supabase functions deploy mapbox-routing`.
6. En la app móvil, copiar `movile_app/env/local.example.json` a `movile_app/env/local.json`
   con `SUPABASE_URL` y `SUPABASE_ANON_KEY` reales.

Hasta entonces, `LocalDraftRepository.syncWithCloud()` lanza
`UnimplementedError('Sync con Supabase pendiente para iteración 2')`.
