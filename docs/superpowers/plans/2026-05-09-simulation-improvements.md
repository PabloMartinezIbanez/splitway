# Simulation Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix and improve the simulated lap feature so it reliably crosses gates, runs fast on road-snapped routes, supports adjustable playback speed, and shows progress feedback.

**Architecture:** Four independent tasks in dependency order: (1) harden the engine's gate-crossing detection with a cooldown guard, (2) rewrite `buildAutoLapScript` to use geometrically-correct approach points and path sampling, (3) add a speed-multiplier control to the session controller and UI, (4) expose simulation progress to the UI.

**Tech Stack:** Dart / Flutter, `splitway_core` (pure Dart), `package:flutter/foundation.dart` (ChangeNotifier), `dart:async` (Timer).

---

## Background — why the current simulation is broken

The start/finish gate is auto-generated **at `path.first`** (the gate centre lies exactly on `path.first`). `segmentsIntersect` uses strict orientation and returns `false` when any endpoint lies on the line being tested. Because `buildAutoLapScript` currently uses `startFinishGate.center` (which equals `path.first`) as a waypoint, every segment that starts or ends there returns `false` → the gate is **never crossed** → the engine stays in `awaitingStart` forever.

Additionally, road-snapped routes can contain 300–1 000 points. Auto-simulation at 600 ms/point means 3–10 minutes per lap.

---

## File Map

| File | Change |
|---|---|
| `packages/splitway_core/lib/src/tracking/tracking_engine.dart` | Add gate-crossing cooldown (Task 1) |
| `packages/splitway_core/test/tracking_engine_test.dart` | Tests for cooldown + correct lap counting (Task 1) |
| `movile_app/lib/src/services/tracking/live_tracking_controller.dart` | Rewrite `buildAutoLapScript`, add `_samplePath` (Task 2) |
| `movile_app/lib/src/features/session/live_session_controller.dart` | Add `_simSpeedMultiplier`, `simProgress`, `simTotal` (Task 3 + 4) |
| `movile_app/lib/src/features/session/live_session_screen.dart` | Speed selector UI, progress bar (Task 3 + 4) |

---

## Task 1 — Gate-crossing cooldown in TrackingEngine

**Why:** Even after fixing the approach points, GPS noise and rapid simulation steps can fire two crossings within milliseconds. A 3-second cooldown prevents spurious consecutive triggers. This is also correct behaviour for real GPS tracking (a car at 100 km/h crosses a 30 m gate in ~1 s; a second crossing within 3 s is always noise).

**Files:**
- Modify: `packages/splitway_core/lib/src/tracking/tracking_engine.dart`
- Modify: `packages/splitway_core/test/tracking_engine_test.dart`

- [ ] **Step 1.1 — Write a failing test that proves double-crossings are ignored**

Open `packages/splitway_core/test/tracking_engine_test.dart` and add this test inside the existing `main()`:

```dart
test('gate cooldown: two crossings 500 ms apart count as one', () async {
  // Minimal route: start gate at (0,0), path goes north briefly.
  final gate = GateDefinition(
    left:  GeoPoint(latitude: 0.0, longitude: -0.0001),
    right: GeoPoint(latitude: 0.0, longitude:  0.0001),
  );
  final route = RouteTemplate(
    id: 'r1', name: 'test',
    path: const [
      GeoPoint(latitude: 0.0,    longitude: 0.0),
      GeoPoint(latitude: 0.0005, longitude: 0.0),
      GeoPoint(latitude: 0.001,  longitude: 0.0),
    ],
    startFinishGate: gate,
    sectors: const [],
    difficulty: RouteDifficulty.easy,
    createdAt: DateTime(2026),
  );

  final now = DateTime(2026, 1, 1, 12, 0, 0);
  var tick = now;
  final engine = TrackingEngine(
    route: route,
    sessionId: 's1',
    clock: () => tick,
  )..start();

  final events = <TrackingEvent>[];
  engine.events.listen(events.add);

  // Approach from south (before gate).
  final pBefore = GeoPoint(latitude: -0.0002, longitude: 0.0);
  // Point past gate (north, inside circuit).
  final pInside = GeoPoint(latitude: 0.0002, longitude: 0.0);

  // First crossing — should open lap 1.
  tick = now;
  engine.ingest(TelemetryPoint(timestamp: tick, location: pBefore, speedMps: 10));
  tick = now.add(const Duration(milliseconds: 100));
  engine.ingest(TelemetryPoint(timestamp: tick, location: pInside, speedMps: 10));

  // Second crossing 500 ms later — should be ignored (cooldown = 3 s).
  tick = now.add(const Duration(milliseconds: 600));
  engine.ingest(TelemetryPoint(timestamp: tick, location: pBefore, speedMps: 10));
  tick = now.add(const Duration(milliseconds: 700));
  engine.ingest(TelemetryPoint(timestamp: tick, location: pInside, speedMps: 10));

  await Future.microtask(() {});  // flush stream

  // Only one TrackingStarted (lap opened once, not twice).
  expect(events.whereType<TrackingStarted>().length, 1);
  // No lap should be closed yet (we haven't done a full second crossing).
  expect(events.whereType<LapClosed>().length, 0);
  engine.dispose();
});
```

- [ ] **Step 1.2 — Run the test to verify it fails**

```
cd packages/splitway_core
dart test test/tracking_engine_test.dart --name "gate cooldown"
```

Expected: `FAIL` — the test reports 2 `TrackingStarted` events instead of 1 (cooldown not implemented yet).

- [ ] **Step 1.3 — Add `_lastCrossingAt` cooldown to `TrackingEngine`**

In `packages/splitway_core/lib/src/tracking/tracking_engine.dart`:

Add the field after `_bestLap`:
```dart
DateTime? _lastCrossingAt;

/// Minimum time between two recognised start/finish crossings.
/// Prevents double-counting from GPS noise or rapid simulation steps.
static const _crossingCooldown = Duration(seconds: 3);
```

Replace `_onStartFinishCrossed` with:
```dart
void _onStartFinishCrossed(DateTime at) {
  // Cooldown: ignore crossings that arrive too soon after the previous one.
  final last = _lastCrossingAt;
  if (last != null && at.difference(last) < _crossingCooldown) return;
  _lastCrossingAt = at;

  if (_status == TrackingStatus.awaitingStart) {
    _status = TrackingStatus.inLap;
    _currentLap = 1;
    _lapStartedAt = at;
    _lastSectorAt = at;
    _nextSectorIndex = 0;
    _lapDistanceAccumulator = 0;
    _sectorDistanceAccumulator = 0;
    _events.add(TrackingStarted(at));
    return;
  }
  if (_status == TrackingStatus.inLap && _lapStartedAt != null) {
    final closed = _buildLap(endedAt: at, completed: true);
    _laps.add(closed);
    if (_bestLap == null || closed.duration < _bestLap!) {
      _bestLap = closed.duration;
    }
    _events.add(LapClosed(at: at, lap: closed));
    _currentLap += 1;
    _lapStartedAt = at;
    _lastSectorAt = at;
    _nextSectorIndex = 0;
    _lapDistanceAccumulator = 0;
    _sectorDistanceAccumulator = 0;
  }
}
```

- [ ] **Step 1.4 — Run the test to verify it passes**

```
cd packages/splitway_core
dart test test/tracking_engine_test.dart --name "gate cooldown"
```

Expected: `PASS`.

- [ ] **Step 1.5 — Run the full splitway_core test suite**

```
cd packages/splitway_core
dart test
```

Expected: all tests `PASS` (no regressions).

- [ ] **Step 1.6 — Commit**

```
git add packages/splitway_core/lib/src/tracking/tracking_engine.dart \
        packages/splitway_core/test/tracking_engine_test.dart
git commit -m "fix(engine): add 3s gate-crossing cooldown to prevent double-counts"
```

---

## Task 2 — Rewrite `buildAutoLapScript` with correct approach points and path sampling

**Why:** The approach point must be geometrically guaranteed to cross the gate. The script must also sample long road-snapped paths to ≤ 50 points so auto-simulation completes in seconds, not minutes.

**Key geometry:**  
- Gate is perpendicular to `path[0] → path[1]` and centred at `path[0]`.  
- `pBefore` = 20 m **behind** `path[0]` → clearly outside the gate.  
- `path[1]` = first point **inside** the circuit → clearly past the gate.  
- Segment `pBefore → path[1]` always crosses the gate. ✓  
- For a closed circuit, segment `sampledPath[-2] → pBefore` also crosses the gate (approaching from inside). The Task 1 cooldown prevents any false double-crossing.

**Files:**
- Modify: `movile_app/lib/src/services/tracking/live_tracking_controller.dart`

- [ ] **Step 2.1 — Replace `buildAutoLapScript` and add `_samplePath`**

Open `movile_app/lib/src/services/tracking/live_tracking_controller.dart`.

Replace the entire `buildAutoLapScript` method and add `_samplePath` below it:

```dart
/// Builds a synthetic telemetry script that drives [lapCount] complete laps
/// around the route. Each point is spaced [intervalMs] ms apart.
///
/// Guarantees:
/// - Uses geometrically-correct approach points so the start/finish gate is
///   always crossed (never relies on gate.center, which lies on the gate line
///   and is rejected by the strict-intersection test).
/// - Samples long road-snapped paths to at most [maxPathPoints] waypoints so
///   the simulation finishes in seconds rather than minutes.
List<TelemetryPoint> buildAutoLapScript({
  required DateTime startTime,
  int lapCount = 1,
  double speedMps = 15.0,
  int intervalMs = 600,
  int maxPathPoints = 50,
}) {
  final path = route.path;
  if (path.length < 2) return const [];

  // Sample the path so the script stays short even for snapped routes.
  final sampled = _samplePath(path, maxPathPoints);

  // Compute a point 20 m BEFORE the gate (guaranteed to be outside).
  // path[0] is the gate centre; path[1] is the first point inside the circuit.
  final fwdBearing = sampled.first.bearingTo(sampled[1]);
  final backBearing = (fwdBearing + 180) % 360;
  final pBefore = route.startFinishGate.center.destinationPoint(backBearing, 20);

  // Build point list: entry approach + N lap iterations.
  // Each iteration: [path[1]..path[-2], pBefore]
  //   - path[1] is inside (past the gate).
  //   - path[-2] is the last point before the gate centre (on the closing approach).
  //   - pBefore finishes outside, crossing the gate to close that lap.
  // The segment pBefore → path[1] (start of the NEXT iteration or the entry)
  // also crosses the gate. The engine cooldown (Task 1) ensures these two
  // rapid consecutive crossings count correctly: one closes a lap, the next
  // is ignored, and the lap continues from path[1].
  final geo = <GeoPoint>[];
  geo.add(pBefore); // entry: start outside so pBefore→sampled[1] opens lap 1.

  for (int lap = 0; lap < lapCount; lap++) {
    // Walk the circuit, skip index 0 (gate centre, on the gate line).
    // For closed circuits skip the last point too (= index 0, same issue).
    final isClosedCircuit = sampled.first == sampled.last;
    final circuitPoints = isClosedCircuit
        ? sampled.skip(1).take(sampled.length - 2).toList() // skip first & last
        : sampled.skip(1).toList();                          // skip only first
    geo.addAll(circuitPoints);
    // Close the lap: go back outside so the gate is crossed.
    geo.add(pBefore);
  }

  // Convert to TelemetryPoints.
  return [
    for (int i = 0; i < geo.length; i++)
      TelemetryPoint(
        timestamp: startTime.add(Duration(milliseconds: i * intervalMs)),
        location: geo[i],
        speedMps: speedMps,
      ),
  ];
}

/// Evenly samples [path] down to at most [max] points, always keeping
/// the first and last point.
static List<GeoPoint> _samplePath(List<GeoPoint> path, int max) {
  if (path.length <= max) return List.of(path);
  final result = <GeoPoint>[];
  final step = (path.length - 1) / (max - 1);
  for (var i = 0; i < max; i++) {
    result.add(path[(i * step).round()]);
  }
  return result;
}
```

- [ ] **Step 2.2 — Run flutter analyze to verify no issues**

```
cd movile_app
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 2.3 — Commit**

```
git add movile_app/lib/src/services/tracking/live_tracking_controller.dart
git commit -m "fix(sim): correct approach points and sample long paths to ≤50 waypoints"
```

---

## Task 3 — Adjustable simulation speed (1×, 5×, 10×)

**Why:** With 50 sampled points at 600 ms/point, one lap takes 30 s. At 10×, it takes 3 s. The user can choose how fast to run through the script.

**Files:**
- Modify: `movile_app/lib/src/features/session/live_session_controller.dart`
- Modify: `movile_app/lib/src/features/session/live_session_screen.dart`

- [ ] **Step 3.1 — Add `_simSpeedMultiplier` to `LiveSessionController`**

Open `movile_app/lib/src/features/session/live_session_controller.dart`.

After the `_autoScript` field declaration add:

```dart
int _simSpeedMultiplier = 1;
int get simSpeedMultiplier => _simSpeedMultiplier;

Duration get _simInterval =>
    Duration(milliseconds: 600 ~/ _simSpeedMultiplier.clamp(1, 20));
```

Add the setter method after `toggleAutoSimulate`:

```dart
/// Sets the simulation playback speed multiplier (1, 5, or 10).
/// If auto-simulate is currently running it is restarted at the new rate.
void setSimSpeedMultiplier(int multiplier) {
  _simSpeedMultiplier = multiplier.clamp(1, 20);
  if (_autoSimulator != null) {
    _autoSimulator?.cancel();
    _autoSimulator = null;
    _startAutoTimer();
  }
  notifyListeners();
}
```

- [ ] **Step 3.2 — Extract the timer logic into `_startAutoTimer`**

Replace the body of `toggleAutoSimulate` with:

```dart
void toggleAutoSimulate() {
  if (_source == TrackingSource.realGps) return;
  if (_autoSimulator != null) {
    _autoSimulator?.cancel();
    _autoSimulator = null;
    notifyListeners();
    return;
  }
  final t = _tracker;
  if (t == null) return;
  if (_autoScript.isEmpty) {
    _autoScript = t.buildAutoLapScript(startTime: DateTime.now());
    _autoIndex = 0;
  }
  _startAutoTimer();
  notifyListeners();
}

void _startAutoTimer() {
  final t = _tracker;
  if (t == null) return;
  _autoSimulator = Timer.periodic(_simInterval, (_) {
    if (_autoIndex >= _autoScript.length) {
      _autoSimulator?.cancel();
      _autoSimulator = null;
      notifyListeners();
      return;
    }
    final scripted = _autoScript[_autoIndex];
    final point = TelemetryPoint(
      timestamp: DateTime.now(),
      location: scripted.location,
      speedMps: scripted.speedMps,
    );
    t.ingestSimulatedPoint(point);
    _autoIndex++;
    notifyListeners();
  });
}
```

- [ ] **Step 3.3 — Add speed selector to `_buildRunning` in `LiveSessionScreen`**

Open `movile_app/lib/src/features/session/live_session_screen.dart`.

Find the simulation controls block (the `if (ctrl.source == TrackingSource.simulated)` block inside `_buildRunning`). Replace the entire block:

```dart
if (ctrl.source == TrackingSource.simulated) ...[
  Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: ctrl.simulateOnePoint,
          icon: const Icon(Icons.fast_forward),
          label: const Text('Simular punto'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: ctrl.toggleAutoSimulate,
          icon: Icon(ctrl.isAutoSimulating ? Icons.pause : Icons.autorenew),
          label: Text(ctrl.isAutoSimulating ? 'Parar auto' : 'Auto vuelta'),
        ),
      ),
    ],
  ),
  const SizedBox(height: 8),
  Row(
    children: [
      Text('Velocidad:',
          style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(width: 8),
      Expanded(
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1,  label: Text('1×')),
            ButtonSegment(value: 5,  label: Text('5×')),
            ButtonSegment(value: 10, label: Text('10×')),
          ],
          selected: {ctrl.simSpeedMultiplier},
          onSelectionChanged: (s) => ctrl.setSimSpeedMultiplier(s.first),
        ),
      ),
    ],
  ),
],
```

- [ ] **Step 3.4 — Run flutter analyze**

```
cd movile_app
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 3.5 — Commit**

```
git add movile_app/lib/src/features/session/live_session_controller.dart \
        movile_app/lib/src/features/session/live_session_screen.dart
git commit -m "feat(sim): add 1×/5×/10× playback speed selector"
```

---

## Task 4 — Simulation progress indicator

**Why:** The user has no feedback on how far through the script the auto-simulation is. A progress bar and a "punto X / Y" label give instant orientation.

**Files:**
- Modify: `movile_app/lib/src/features/session/live_session_controller.dart`
- Modify: `movile_app/lib/src/features/session/live_session_screen.dart`

- [ ] **Step 4.1 — Expose `simProgress` and `simTotal` from `LiveSessionController`**

In `movile_app/lib/src/features/session/live_session_controller.dart`, add two getters after `isAutoSimulating`:

```dart
/// Current position in the auto-simulation script (number of points sent).
int get simProgress => _autoIndex;

/// Total number of points in the current auto-simulation script.
int get simTotal => _autoScript.length;
```

- [ ] **Step 4.2 — Add progress bar + label to `_buildRunning`**

In `movile_app/lib/src/features/session/live_session_screen.dart`, inside `_buildRunning`, find the line:

```dart
if (ctrl.source == TrackingSource.simulated) ...[
```

Add this block **immediately before** the `Row` with the two buttons (after the opening `...[`):

```dart
if (ctrl.isAutoSimulating && ctrl.simTotal > 0) ...[
  Row(
    children: [
      Expanded(
        child: LinearProgressIndicator(
          value: ctrl.simProgress / ctrl.simTotal,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '${ctrl.simProgress} / ${ctrl.simTotal}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ],
  ),
  const SizedBox(height: 6),
],
```

- [ ] **Step 4.3 — Run flutter analyze**

```
cd movile_app
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 4.4 — Commit**

```
git add movile_app/lib/src/features/session/live_session_controller.dart \
        movile_app/lib/src/features/session/live_session_screen.dart
git commit -m "feat(sim): add progress bar and point counter to auto-simulation"
```

---

## Self-Review

**Spec coverage:**

| Improvement | Task |
|---|---|
| Fix gate approach so simulation actually triggers | Task 2 |
| Sample path (fix slow simulation on snapped routes) | Task 2 |
| Multi-lap support | Task 2 (`lapCount` param) |
| Adjustable playback speed | Task 3 |
| Progress indicator | Task 4 |
| Prevent double-crossings (engine robustness) | Task 1 |
| Variable speed by curvature | Not included — YAGNI; speedMps param enables future extension |

**Placeholder scan:** No TBDs or incomplete steps found.

**Type consistency:**
- `buildAutoLapScript` signature changed: new params `lapCount`, `speedMps`, `intervalMs`, `maxPathPoints` — all have defaults so existing call sites (`t.buildAutoLapScript(startTime: base)`) remain valid. ✓
- `_startAutoTimer` is called from both `toggleAutoSimulate` and `setSimSpeedMultiplier`. ✓
- `simProgress` / `simTotal` getters read `_autoIndex` / `_autoScript.length` which are already managed by existing code. ✓
