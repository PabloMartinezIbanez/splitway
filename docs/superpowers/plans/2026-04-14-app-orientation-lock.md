# App Orientation Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lock the Flutter mobile app to `portraitUp` at startup so the UI cannot rotate into landscape.

**Architecture:** Keep the change centralized in the Flutter entrypoint by setting preferred orientations before `runApp`. Cover the behavior with one targeted test that inspects the platform channel call made by `SystemChrome`.

**Tech Stack:** Flutter, Material 3, widget tests, `SystemChrome`

---

### Task 1: Add a failing startup test for orientation locking

**Files:**
- Create: `apps/mobile/test/main_test.dart`
- Test: `apps/mobile/test/main_test.dart`

- [ ] Add a test that invokes `main()` and captures the `SystemChrome.setPreferredOrientations` platform message.
- [ ] Run `flutter test test/main_test.dart` from `apps/mobile` and confirm it fails because no orientation preference is set yet.

### Task 2: Lock orientation in the app entrypoint

**Files:**
- Modify: `apps/mobile/lib/main.dart`
- Test: `apps/mobile/test/main_test.dart`

- [ ] Import `package:flutter/services.dart` in `apps/mobile/lib/main.dart`.
- [ ] Call `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` after `WidgetsFlutterBinding.ensureInitialized()` and before `runApp(...)`.
- [ ] Re-run `flutter test test/main_test.dart` from `apps/mobile` and confirm it passes.

### Task 3: Verify the targeted mobile suite

**Files:**
- Modify: `apps/mobile/lib/main.dart`
- Modify: `apps/mobile/test/main_test.dart`

- [ ] Run `dart format lib/main.dart test/main_test.dart` from `apps/mobile`.
- [ ] Run `flutter test test/main_test.dart test/route_editor_screen_test.dart` from `apps/mobile`.
