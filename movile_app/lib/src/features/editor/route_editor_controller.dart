import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../data/repositories/local_draft_repository.dart';
import '../../services/geocoding/reverse_geocoding_service.dart';
import '../../services/routing/routing_service.dart';

/// Which kind of input the next map tap should produce while drawing a
/// new route in the editor.
enum DrawInputMode {
  /// Each tap appends a point to the route path.
  appendPath,

  /// A single tap snaps to the nearest path vertex and auto-generates a
  /// perpendicular sector gate at that point.
  sectorPoint,
}

class RouteEditorController extends ChangeNotifier {
  RouteEditorController(this._repo, {this.routingService, this.geocodingService});

  final LocalDraftRepository _repo;

  /// Optional: when present each new waypoint triggers a Mapbox Directions
  /// API call to snap the drawn path to actual roads in real time.
  final RoutingService? routingService;

  /// Optional: when present, reverse geocoding is called on save to populate
  /// the route's locationLabel field.
  final ReverseGeocodingService? geocodingService;

  List<SessionRun> _sessionsForSelected = const [];
  List<SessionRun> get sessionsForSelected => _sessionsForSelected;

  bool _loading = true;
  bool get loading => _loading;

  /// True while a Mapbox snap request is in flight.
  bool _snapping = false;
  bool get snapping => _snapping;

  /// True when the last snap attempt failed (API error, no connectivity…).
  /// Resets to false as soon as the next snap succeeds.
  bool _snapFailed = false;
  bool get snapFailed => _snapFailed;

  List<RouteTemplate> _routes = const [];
  List<RouteTemplate> get routes => _routes;

  RouteTemplate? _selected;
  RouteTemplate? get selected => _selected;

  // ---------- Draw mode state ----------

  bool _drawing = false;
  bool get drawing => _drawing;

  String _draftName = '';
  String? _draftDescription;
  RouteDifficulty _draftDifficulty = RouteDifficulty.medium;
  String get draftName => _draftName;
  String? get draftDescription => _draftDescription;
  RouteDifficulty get draftDifficulty => _draftDifficulty;

  /// Raw waypoints tapped by the user — the canonical input for snapping.
  final List<GeoPoint> _rawWaypoints = [];
  List<GeoPoint> get rawWaypoints => List.unmodifiable(_rawWaypoints);

  /// Road-following display path (snapped via Mapbox, or == _rawWaypoints
  /// when routing is unavailable).
  final List<GeoPoint> _draftPath = [];
  List<GeoPoint> get draftPath => List.unmodifiable(_draftPath);

  /// Number of user-tapped waypoints (shown in the status bar).
  int get draftWaypointCount => _rawWaypoints.length;

  final List<GateDefinition> _draftSectorGates = [];
  List<GateDefinition> get draftSectorGates =>
      List.unmodifiable(_draftSectorGates);

  /// Path vertices snapped by the sectorPoint mode (parallel to _draftSectorGates).
  final List<GeoPoint> _draftSectorPoints = [];
  List<GeoPoint> get draftSectorPoints => List.unmodifiable(_draftSectorPoints);

  /// Always null — retained for widget compatibility after removing 2-tap gate.
  GeoPoint? get pendingGateLeft => null;

  DrawInputMode _inputMode = DrawInputMode.appendPath;
  DrawInputMode get inputMode => _inputMode;

  /// True if a draft can be persisted (≥2 waypoints and a name).
  bool get draftCanSave =>
      _rawWaypoints.length >= 2 && _draftName.trim().isNotEmpty;

  // Debounce live snapping so rapid taps only fire one API call.
  Timer? _snapDebouncer;
  // Monotonically-increasing generation counter — stale responses are ignored.
  int _snapGeneration = 0;

  // ---------- Load / select ----------

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _routes = await _repo.getAllRoutes();
    _selected ??= _routes.isNotEmpty ? _routes.first : null;
    if (_selected != null) {
      _selected = _routes.firstWhere(
        (r) => r.id == _selected!.id,
        orElse: () => _routes.first,
      );
    }
    _loading = false;
    notifyListeners();
    if (_selected != null) {
      _loadSessionsForRoute(_selected!.id);
    }
  }

  void select(RouteTemplate route) {
    _selected = route;
    notifyListeners();
    _loadSessionsForRoute(route.id);
  }

  Future<void> _loadSessionsForRoute(String routeId) async {
    _sessionsForSelected = await _repo.getSessionsByRoute(routeId);
    notifyListeners();
  }

  // ---------- Draw mode lifecycle ----------

  void startDrawing({
    required String name,
    String? description,
    required RouteDifficulty difficulty,
  }) {
    _cancelSnap();
    _drawing = true;
    _snapFailed = false;
    _draftName = name;
    _draftDescription = description;
    _draftDifficulty = difficulty;
    _rawWaypoints.clear();
    _draftPath.clear();
    _draftSectorGates.clear();
    _draftSectorPoints.clear();
    _inputMode = DrawInputMode.appendPath;
    notifyListeners();
  }

  void cancelDrawing() {
    _cancelSnap();
    _drawing = false;
    _snapFailed = false;
    _draftName = '';
    _draftDescription = null;
    _draftDifficulty = RouteDifficulty.medium;
    _rawWaypoints.clear();
    _draftPath.clear();
    _draftSectorGates.clear();
    _draftSectorPoints.clear();
    _inputMode = DrawInputMode.appendPath;
    notifyListeners();
  }

  void setInputMode(DrawInputMode mode) {
    _inputMode = mode;
    notifyListeners();
  }

  void undoLastPathPoint() {
    if (_rawWaypoints.isEmpty) return;
    _cancelSnap();
    _rawWaypoints.removeLast();
    if (_rawWaypoints.length < 2 || routingService == null) {
      // Nothing to snap: just mirror raw waypoints into the display path.
      _snapping = false;
      _draftPath
        ..clear()
        ..addAll(_rawWaypoints);
      notifyListeners();
    } else {
      // Re-snap the reduced waypoint list.
      _draftPath.clear();
      notifyListeners();
      _scheduleSnap();
    }
  }

  /// Routes a single map tap to the right drafting bucket.
  void handleMapTap(GeoPoint p) {
    if (!_drawing) return;
    switch (_inputMode) {
      case DrawInputMode.appendPath:
        _rawWaypoints.add(p);
        // Show the raw tap immediately for instant visual feedback.
        _draftPath.add(p);
        notifyListeners();
        // Then schedule a snap to replace the straight segment with a road.
        _scheduleSnap();
      case DrawInputMode.sectorPoint:
        if (_draftPath.length < 2) return;  // Need at least 2 points to compute a bearing
        final idx = _nearestPathIndex(p);
        final snapped = _draftPath[idx];
        final gate = _gateAtPathIndex(idx);
        _draftSectorPoints.add(snapped);
        _draftSectorGates.add(gate);
        notifyListeners();
    }
  }

  // ---------- Sector-point helpers ----------

  /// Returns the index of the [_draftPath] vertex closest to [tap].
  int _nearestPathIndex(GeoPoint tap) {
    int bestIdx = 0;
    double bestDist = _draftPath[0].distanceTo(tap);
    for (var i = 1; i < _draftPath.length; i++) {
      final d = _draftPath[i].distanceTo(tap);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Builds a perpendicular [GateDefinition] at [_draftPath[idx]].
  GateDefinition _gateAtPathIndex(int idx) {
    final anchor = _draftPath[idx];
    if (idx < _draftPath.length - 1) {
      return _perpendicularGate(anchor, _draftPath[idx + 1]);
    }
    // At the last vertex: extrapolate the bearing forward to keep the gate
    // centered on anchor (not on the previous vertex).
    final prev = _draftPath[idx - 1];
    final bearing = prev.bearingTo(anchor);
    final reference = anchor.destinationPoint(bearing, 1.0);
    return _perpendicularGate(anchor, reference);
  }

  // ---------- Live snap helpers ----------

  /// Cancels any pending debounce timer and in-flight snap request.
  void _cancelSnap() {
    _snapDebouncer?.cancel();
    _snapDebouncer = null;
    _snapGeneration++;   // invalidates any in-flight response
    _snapping = false;
  }

  /// Schedules a snap request to fire after 600 ms of inactivity.
  void _scheduleSnap() {
    if (routingService == null || _rawWaypoints.length < 2) return;
    _snapDebouncer?.cancel();
    _snapDebouncer = Timer(const Duration(milliseconds: 600), _snapPath);
  }

  Future<void> _snapPath() async {
    if (routingService == null || _rawWaypoints.length < 2) return;

    final waypoints = List<GeoPoint>.of(_rawWaypoints); // snapshot
    final generation = ++_snapGeneration;

    _snapping = true;
    notifyListeners();

    final snapped = await routingService!.snapToRoads(waypoints);

    // Discard if a newer snap was already triggered.
    if (_snapGeneration != generation) return;

    _snapping = false;
    if (snapped != null && snapped.length >= 2) {
      _snapFailed = false;
      _draftPath
        ..clear()
        ..addAll(snapped);
      debugPrint(
          'LiveSnap: ${waypoints.length} waypoints → ${snapped.length} road points');
    } else {
      // Fallback: show straight lines between waypoints.
      _snapFailed = true;
      _draftPath
        ..clear()
        ..addAll(waypoints);
      debugPrint('LiveSnap: failed, showing straight segments');
    }
    notifyListeners();
  }

  // ---------- Save ----------

  Future<RouteTemplate?> saveDraft() async {
    if (!draftCanSave) return null;

    // Cancel any pending live snap — we handle the final path here.
    _cancelSnap();

    // Determine whether this should be a closed circuit.
    final distFirstLast = _rawWaypoints.first.distanceTo(_rawWaypoints.last);
    final isClosed = distFirstLast <= 20.0;

    List<GeoPoint> finalPath;

    if (routingService != null) {
      // Build the waypoint list for the final snap.
      final List<GeoPoint> waypointsToSnap;
      if (isClosed) {
        // Replace the last raw waypoint with the first to force a clean loop.
        waypointsToSnap = [
          ..._rawWaypoints.sublist(0, _rawWaypoints.length - 1),
          _rawWaypoints.first,
        ];
      } else {
        waypointsToSnap = List<GeoPoint>.of(_rawWaypoints);
      }

      _snapping = true;
      notifyListeners();
      final snapped = await routingService!.snapToRoads(waypointsToSnap);
      _snapping = false;
      notifyListeners();

      if (snapped != null && snapped.length >= 2) {
        finalPath = snapped;
        debugPrint(
            'SaveSnap: ${waypointsToSnap.length} waypoints → ${snapped.length} road points');
        // Guarantee exact closure for closed circuits.
        if (isClosed && finalPath.first != finalPath.last) {
          finalPath = [...finalPath, finalPath.first];
        }
      } else {
        debugPrint('SaveSnap: failed, using straight segments');
        finalPath = waypointsToSnap;
      }
    } else {
      // No routing service — work with raw waypoints.
      if (isClosed) {
        finalPath = [
          ..._rawWaypoints.sublist(0, _rawWaypoints.length - 1),
          _rawWaypoints.first,
        ];
      } else {
        finalPath = List<GeoPoint>.of(_rawWaypoints);
      }
    }

    debugPrint(
        'Route: ${isClosed ? "closed" : "open"} circuit, '
        'distance first↔last = ${distFirstLast.toStringAsFixed(1)} m');

    // Reverse geocode the first point for the location label.
    String? locationLabel;
    if (geocodingService != null && finalPath.isNotEmpty) {
      locationLabel = await geocodingService!.reverseGeocode(finalPath.first);
    }

    // Auto-generate start/finish gate perpendicular to the route at the
    // first point, using the bearing toward the second point.
    final startFinishGate = _perpendicularGate(finalPath[0], finalPath[1]);

    final id = 'route-${DateTime.now().microsecondsSinceEpoch}';
    final route = RouteTemplate(
      id: id,
      name: _draftName.trim(),
      description: _draftDescription?.trim().isEmpty ?? true
          ? null
          : _draftDescription!.trim(),
      locationLabel: locationLabel,
      path: List.unmodifiable(finalPath),
      startFinishGate: startFinishGate,
      sectors: [
        for (var i = 0; i < _draftSectorGates.length; i++)
          SectorDefinition(
            id: '$id-sec-${i + 1}',
            order: i,
            label: 'Sector ${i + 1}',
            gate: _draftSectorGates[i],
          ),
      ],
      difficulty: _draftDifficulty,
      createdAt: DateTime.now(),
    );

    await _repo.saveRouteTemplate(route);

    _drawing = false;
    _draftName = '';
    _draftDescription = null;
    _draftDifficulty = RouteDifficulty.medium;
    _rawWaypoints.clear();
    _draftPath.clear();
    _draftSectorGates.clear();
    _draftSectorPoints.clear();
    _inputMode = DrawInputMode.appendPath;

    await load();
    _selected = route;
    notifyListeners();
    return route;
  }

  /// Builds a [GateDefinition] perpendicular to the direction [anchor]→[next],
  /// centred on [anchor], with a half-width of 15 m each side (30 m total).
  static GateDefinition _perpendicularGate(GeoPoint anchor, GeoPoint next) {
    const halfWidth = 15.0;
    final fwdBearing = anchor.bearingTo(next);
    final left =
        anchor.destinationPoint((fwdBearing - 90 + 360) % 360, halfWidth);
    final right = anchor.destinationPoint((fwdBearing + 90) % 360, halfWidth);
    return GateDefinition(left: left, right: right);
  }

  // ---------- CRUD on existing routes ----------

  Future<void> deleteRoute(String id) async {
    await _repo.deleteRoute(id);
    if (_selected?.id == id) {
      _selected = null;
    }
    await load();
  }

  Future<void> updateRouteMetadata({
    required String routeId,
    required String name,
    String? description,
    required RouteDifficulty difficulty,
  }) async {
    final existing = _routes.firstWhere((r) => r.id == routeId);
    final updated = existing.copyWith(
      name: name,
      description: description,
      difficulty: difficulty,
    );
    await _repo.saveRouteTemplate(updated);
    await load();
  }

  @override
  void dispose() {
    _snapDebouncer?.cancel();
    super.dispose();
  }
}
