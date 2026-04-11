# Supabase Setup

## Local workflow

1. Install the Supabase CLI.
2. Link or start a local project.
3. Apply the migration in `migrations/20260410_initial_schema.sql`.
4. Deploy the `mapbox-routing` edge function and configure:

- `MAPBOX_SECRET_TOKEN`
- `MAPBOX_BASE_URL` (optional, defaults to `https://api.mapbox.com`)

## Expected client behaviour

- The mobile client authenticates anonymously.
- Route templates sync first.
- Completed sessions sync afterward with telemetry rows batched separately.
- Directions and map matching are requested only on demand while editing/preparing a route.
- If the edge function or Mapbox fails, the client keeps the raw geometry.
