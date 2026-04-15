# Route Map Bottom Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply a shared map-first bottom-sheet layout to route detail and route editor screens while preserving current route behavior.

**Architecture:** Introduce a reusable draggable sheet scaffold for route screens, plus a small route metrics helper to keep UI logic focused. Refactor both screens to render the map as the background layer and move compact/expanded content into the sheet.

**Tech Stack:** Flutter, Material 3, widget tests, `DraggableScrollableSheet`

---

### Task 1: Add shared layout and metrics helpers

**Files:**
- Create: `apps/mobile/lib/src/shared/widgets/map_bottom_sheet_scaffold.dart`
- Create: `apps/mobile/lib/src/features/routes/route_metrics.dart`
- Test: `apps/mobile/test/route_map_bottom_sheet_test.dart`

- [ ] Add a widget test that renders a minimal bottom-sheet scaffold and verifies compact content is visible before expansion.
- [ ] Run `flutter test test/route_map_bottom_sheet_test.dart` from `apps/mobile` and confirm the new test fails because the scaffold does not exist yet.
- [ ] Implement the shared scaffold with a map slot, drag handle, compact header slot, and scrollable expanded body.
- [ ] Implement route metrics helpers for distance and optional elevation range.
- [ ] Re-run `flutter test test/route_map_bottom_sheet_test.dart`.

### Task 2: Refactor route detail screen to use the shared sheet

**Files:**
- Modify: `apps/mobile/lib/src/features/routes/route_detail_screen.dart`
- Modify: `apps/mobile/lib/src/features/routes/widgets/route_map_preview.dart`
- Test: `apps/mobile/test/route_detail_screen_test.dart`

- [ ] Add a widget test covering the compact route detail actions and expanded metrics.
- [ ] Run `flutter test test/route_detail_screen_test.dart` from `apps/mobile` and confirm it fails before the refactor.
- [ ] Replace the existing `Column` detail layout with the shared map-first sheet scaffold.
- [ ] Keep stopwatch, edit, notes, and session history intact inside the expanded sheet content.
- [ ] Hide elevation when route geometry has no altitude data.
- [ ] Re-run `flutter test test/route_detail_screen_test.dart`.

### Task 3: Refactor route editor screen to use the shared sheet

**Files:**
- Modify: `apps/mobile/lib/src/features/editor/route_editor_screen.dart`
- Modify: `apps/mobile/test/route_editor_screen_test.dart`

- [ ] Add a widget test that verifies the editor shows compact quick controls and expanded route metrics.
- [ ] Run `flutter test test/route_editor_screen_test.dart` from `apps/mobile` and confirm the new expectation fails before implementation.
- [ ] Replace the editor bottom panel with the shared map-first sheet scaffold.
- [ ] Keep waypoint/sector controls, manual point dialog, status chips, and point list behavior intact inside the new sheet.
- [ ] Re-run `flutter test test/route_editor_screen_test.dart`.

### Task 4: Verify integrated behavior

**Files:**
- Modify: `apps/mobile/test/route_detail_screen_test.dart`
- Modify: `apps/mobile/test/route_editor_screen_test.dart`

- [ ] Run `flutter test test/route_detail_screen_test.dart test/route_editor_screen_test.dart test/route_map_bottom_sheet_test.dart` from `apps/mobile`.
- [ ] Run `dart format` on touched Dart files.
- [ ] Re-run the same Flutter test command to confirm formatting did not introduce regressions.
