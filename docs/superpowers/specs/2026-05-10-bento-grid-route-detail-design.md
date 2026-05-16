# Bento Grid Route Detail — Design Spec

## Goal

Rediseñar la sección de detalle de ruta en la pantalla "Editar rutas" usando un layout tipo bento grid con tarjetas informativas visualmente atractivas.

## Architecture

La sección `_RouteDetail` se convierte en un grid de 2 columnas con tarjetas de diferentes tamaños. Se añade un campo `locationLabel` al modelo de ruta para almacenar la localización textual (obtenida via Mapbox Reverse Geocoding al guardar la ruta). Las sesiones asociadas se cargan desde el repositorio existente (`getSessionsByRoute`).

## Data Changes

### Nuevo campo: `locationLabel`

- **Modelo `RouteTemplate`**: añadir `locationLabel: String?`
- **Base de datos**: nueva columna `location_label TEXT` en tabla `route_templates`
- **Serialización**: incluir en `toJson`/`fromJson`
- **Población**: al guardar una ruta nueva (`saveDraft`), llamar a Mapbox Reverse Geocoding API con el primer punto del path. Almacenar el resultado (ej: "Madrid, España"). Si falla, guardar `null`.

### Cálculo de distancia

No se almacena — se calcula al vuelo sumando `distanceTo` entre puntos consecutivos del `route.path`. Se añade un getter `totalDistanceMeters` a `RouteTemplate` (o se calcula en la UI).

## Mapbox Reverse Geocoding

- Endpoint: `https://api.mapbox.com/search/geocode/v6/reverse?longitude={lng}&latitude={lat}&access_token={token}`
- Se llama una sola vez al guardar la ruta
- Se extrae el `place_name` del primer resultado (o componentes `locality` + `country`)
- Se almacena como `locationLabel` en el modelo
- Si falla (sin red, error API): se guarda `null`, la UI muestra "—"

## UI Layout

### Estructura general

```
ListView(
  children: [
    // 1. Mapa (full width, aspect 16:10)
    Card > AspectRatio > SplitwayMap

    // 2. Grid de info (2 columnas via Wrap o GridView)
    _BentoGrid(
      children: [
        _BentoTile(icon, label, value)  // Distancia
        _BentoTile(icon, label, value)  // Localización
        _BentoTile(icon, label, value)  // Tipo circuito
        _BentoTile(icon, label, value)  // Sectores (tappable → toggle colores)
        _BentoTile(icon, label, value)  // Dificultad
        _BentoTile(icon, label, value)  // Fecha creación
        _BentoTileWide(...)             // Sesiones (full width, tappable → historial)
        _BentoActionTile(...)           // Editar ruta (half width)
        _BentoActionTile(...)           // Eliminar ruta (half width)
      ]
    )
  ]
)
```

### Widget `_BentoTile`

Tarjeta individual (ocupa 1 columna = half width):

```
┌─────────────────┐
│ 📏              │  ← icono (top-left, color accent)
│ Distancia       │  ← label (bodySmall, gris)
│ 3.2 km          │  ← value (titleMedium, bold)
└─────────────────┘
```

- Background: `theme.colorScheme.surfaceContainerLow`
- Border radius: 12
- Padding: 12
- Height: ~80-90 (no fija, flexible)

### Widget `_BentoTileWide`

Tarjeta ancho completo (2 columnas):

```
┌─────────────────────────────────┐
│ 🏆  Sesiones              [→]   │
│ 5 sesiones · Mejor: 1:23.456   │
└─────────────────────────────────┘
```

- Mismos estilos que `_BentoTile` pero span full width
- Trailing icon `Icons.chevron_right` para indicar navegación
- `onTap` navega al historial filtrado por esta ruta

### Widget `_BentoActionTile`

Tarjeta de acción (half width, estilo más sutil):

```
┌─────────────────┐
│   ✏️ Editar     │  ← icono + texto centrados
└─────────────────┘
```

- Para "Editar": color de fondo `primaryContainer`
- Para "Eliminar": color de fondo `errorContainer`
- `onTap` ejecuta la acción correspondiente

## Comportamiento interactivo

| Celda | Al tocar |
|-------|----------|
| Sectores | Toggle visualización de colores en el mapa |
| Sesiones | Navegar a pantalla historial filtrada por ruta |
| Editar | Entrar en modo dibujo con la ruta (edición) |
| Eliminar | Mostrar diálogo de confirmación actual |

## Navegación a historial

Cuando el usuario toca "Sesiones", se navega al tab de historial pasando un filtro por `routeId`. Esto requiere:

- Añadir un parámetro opcional `filterRouteId` al `HistoryScreen`
- O usar navegación directa con `Navigator.push` a una vista de sesiones filtrada

Decisión: usar `Navigator.push` con una instancia de `HistoryScreen` filtrada (misma pantalla, solo mostrando sesiones de esa ruta). Esto evita modificar el router global.

## Editar ruta

"Editar ruta" por ahora redirige al modo dibujo (`startDrawing`) precargando nombre, descripción y dificultad de la ruta existente. En una primera versión puede limitarse a abrir un diálogo para editar los metadatos (nombre, descripción, dificultad) sin redibujar el trazado.

Decisión: primera versión = diálogo de edición de metadatos (nombre, descripción, dificultad). Redibujar el trazado queda fuera de scope.

## Archivos afectados

- `packages/splitway_core/lib/src/models/route_template.dart` — añadir `locationLabel`, getter `totalDistanceMeters`
- `movile_app/lib/src/data/repositories/local_draft_repository.dart` — nuevo campo en tabla, actualizar save/read
- `movile_app/lib/src/features/editor/route_editor_controller.dart` — llamar geocoding al guardar
- `movile_app/lib/src/features/editor/route_editor_screen.dart` — reemplazar `_RouteDetail` con bento grid
- `movile_app/lib/src/services/geocoding/reverse_geocoding_service.dart` (nuevo) — wrapper Mapbox API
- `movile_app/lib/src/features/history/history_screen.dart` — aceptar filtro por ruta (opcional)

## Fuera de scope

- Editar el trazado de una ruta existente (solo metadatos)
- Estadísticas avanzadas (velocidad media, evolución temporal)
- Fotos o media asociada a la ruta
