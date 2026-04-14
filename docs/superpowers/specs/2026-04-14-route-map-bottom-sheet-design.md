# Route Map Bottom Sheet Design

Date: 2026-04-14

## Goal

Redesign the route detail and route editor screens so the map occupies most of the mobile viewport and route information moves into a bottom-anchored sheet. The sheet must start in a compact fixed-height state and expand upward to reveal additional information.

## Scope

This design applies to:

- `apps/mobile/lib/src/features/routes/route_detail_screen.dart`
- `apps/mobile/lib/src/features/editor/route_editor_screen.dart`

It does not change route persistence or editing rules. The primary change is layout and presentation, with small UI helpers for derived metrics where needed.

## User Experience

### Shared Interaction Pattern

Both screens will adopt the same structure:

- A map layer rendered as the visual base of the screen.
- A `DraggableScrollableSheet` anchored to the bottom edge.
- A compact initial state with a fixed visible height.
- An expanded state that reveals additional route information.

The compact state must be tall enough to expose:

- A drag handle.
- The screen's primary quick actions.
- Minimal identifying context for the current route or editor state.

The expanded state must feel like a natural continuation of the same panel rather than a separate page. The map remains visible behind the sheet while compact, reducing wasted space compared with the current stacked layout.

## Screen Designs

### Route Detail Screen

#### Compact State

The compact sheet shows:

- Drag handle.
- Route name.
- Primary action: `Iniciar Cronómetro`.
- Secondary action: `Editar`.

The map remains the dominant element behind the sheet.

#### Expanded State

The expanded sheet shows:

- Total distance in kilometers.
- Total number of route points.
- Total number of sectors.
- Elevation difference between highest and lowest point, only when altitude data is available.
- Route state: closed circuit or open route.
- Route creation date.
- Optional notes.
- Session history list.

### Route Editor Screen

#### Compact State

The compact sheet shows:

- Drag handle.
- Quick editing controls.
- Mode selector for waypoint vs sector.
- Button to add a point manually.

The map remains large enough to support interactive placement without feeling constrained by the control panel.

#### Expanded State

The expanded sheet shows:

- Total distance in kilometers.
- Total number of placed points.
- Total number of created sectors.
- Elevation difference between highest and lowest point, only when altitude data is available.
- Route state chips such as closed/open.
- Preview status chips such as routing in progress or fallback geometry when applicable.
- Optional horizontal point list if it still helps editing without overloading the panel.

## Data and Derived Metrics

### Distance

Distance uses the existing route/editor geometry data already available in the current implementation.

### Points and Sectors

Point and sector counts use existing route and editor state.

### Elevation Difference

Elevation difference is optional. It must only be shown when altitude data is available for the displayed route geometry.

If no altitude data exists:

- The elevation metric is omitted entirely.
- No placeholder, warning, or zero-value fallback is shown.

This keeps the UI clean and avoids implying a calculated value where none exists.

## Implementation Direction

### Shared Layout Primitive

Create a reusable bottom-sheet layout component for route screens so the detail screen and editor screen share the same structural behavior while providing different content.

The reusable component should own:

- The `Stack` structure.
- The map/background slot.
- The `DraggableScrollableSheet`.
- Compact and expanded content slots.
- Shared padding, rounded corners, and drag-handle styling.

This avoids duplicating the same layout logic in two screens and keeps future spacing or gesture changes centralized.

### Detail Screen Refactor

Replace the current `Column` layout with:

- Base map filling the available body space.
- Reusable bottom-sheet scaffold hosting detail-specific compact and expanded content.

Existing actions such as edit, delete, and start stopwatch remain available. The redesign changes where they live, not their behavior.

### Editor Screen Refactor

Replace the current map-plus-bottom-panel `Column` with:

- Base interactive editor map filling the available body space.
- Reusable bottom-sheet scaffold hosting editor-specific compact and expanded content.

Existing editing flows such as toggling sector mode, adding points manually, undoing, and saving remain unchanged.

## Error Handling and Fallbacks

- If map rendering falls back to the non-Mapbox placeholder, the bottom-sheet layout still applies.
- If route preview generation is loading or fails in the editor, the existing status indicators remain visible in the expanded content.
- If altitude data is unavailable, elevation difference is hidden without leaving visual gaps that suggest missing content.

## Testing Strategy

Manual verification is required for:

- Route detail screen on a saved route.
- Route editor while creating a route.
- Route editor while editing an existing route.
- Compact and expanded sheet behavior on small screens.
- Routes with notes and without notes.
- Routes with altitude data and without altitude data.
- Editor states with no points, some points, and sectors.
- Editor preview loading and preview fallback states.

Widget tests should focus on:

- Presence of compact quick actions.
- Presence of expanded metrics.
- Conditional omission of elevation metric when altitude data is absent.
- Rendering of detail and editor content inside the shared sheet pattern.

## Non-Goals

- Changing route save semantics.
- Changing route preview generation logic.
- Introducing fabricated elevation values.
- Reworking navigation structure between route list, detail, and editor.

## Open Decisions Resolved

- Both route detail and route editor will use the same map-first bottom-sheet pattern.
- The sheet starts compact with a fixed visible height.
- The sheet expands upward to reveal additional information.
- Elevation difference is shown only when altitude data exists; otherwise it is hidden.
