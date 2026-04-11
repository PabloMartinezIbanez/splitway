# Carnometer PoC Architecture

## Core decisions

- The stopwatch and sector detection run on the mobile device so a session survives temporary network loss.
- The backend only persists route templates and completed sessions.
- Maps use the official Mapbox Flutter SDK on the device.
- Anonymous Supabase auth is used as a technical identity, without a visible login flow.
- Routes can be stored raw and optionally enriched with Mapbox Directions or Map Matching afterward.

## Main building blocks

- `carnometer_core`
  - Owns route/session models and tracking rules.
  - Can be tested without Flutter.
- `apps/mobile`
  - Owns the Android-first product shell, local persistence, session playback, and GPS integration.
- `supabase`
  - Owns relational storage, PostGIS projections, and the edge function proxying Mapbox routing APIs.

## MVP behaviour

- Closed routes produce laps and sectors.
- Open routes produce sectors only.
- Telemetry is stored locally first, then synced later.
- Speed shown to the user is the speed measured by the device, not road speed limits.
