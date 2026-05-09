import 'package:flutter/foundation.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../data/repositories/local_draft_repository.dart';
import '../../services/routing/routing_service.dart';

/// Which kind of input the next map tap should produce while drawing a
/// new route in the editor.
enum DrawInputMode {
  /// Each tap appends a point to the route path.
  appendPath,

  /// The next two taps define the start/finish gate.
  startGate,

  /// The next two taps define a sector gate.
  sectorGate,
}

class RouteEditorController extends ChangeNotifier {
  RouteEditorController(this._repo, {this.routingService});

  final LocalDraftRepository _repo;

  /// Optional: when present, [saveDraft] will snap the drawn path to
  /// actual roads using the Mapbox Directions API before persisting.
  final RoutingService? routingService;

  bool _loading = true;
  bool get loading => _loading;

  /// True while [saveDraft] is waiting for the routing API response.
  bool _snapping = false;
  bool get snapping => _snapping;

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

  final List<GeoPoint> _draftPath = [];
  List<GeoPoint> get draftPath => List.unmodifiable(_draftPath);

  GateDefinition? _draftStartGate;
  GateDefinition? get draftStartGate => _draftStartGate;

  final List<GateDefinition> _draftSectorGates = [];
  List<GateDefinition> get draftSectorGates =>
      List.unmodifiable(_draftSectorGates);

  /// Buffers between long-presses while defining a 2-point gate.
  GeoPoint? _pendingGateLeft;
  GeoPoint? get pendingGateLeft => _pendingGateLeft;

  DrawInputMode _inputMode = DrawInputMode.appendPath;
  DrawInputMode get inputMode => _inputMode;

  /// True if a draft can be persisted (≥2 path points and a start gate).
  bool get draftCanSave =>
      _draftPath.length >= 2 &&
      _draftStartGate != null &&
      _draftName.trim().isNotEmpty;

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
  }

  void select(RouteTemplate route) {
    _selected = route;
    notifyListeners();
  }

  // ---------- Draw mode lifecycle ----------

  void startDrawing({
    required String name,
    String? description,
    required RouteDifficulty difficulty,
  }) {
    _drawing = true;
    _draftName = name;
    _draftDescription = description;
    _draftDifficulty = difficulty;
    _draftPath.clear();
    _draftStartGate = null;
    _draftSectorGates.clear();
    _pendingGateLeft = null;
    _inputMode = DrawInputMode.appendPath;
    notifyListeners();
  }

  void cancelDrawing() {
    _drawing = false;
    _draftName = '';
    _draftDescription = null;
    _draftDifficulty = RouteDifficulty.medium;
    _draftPath.clear();
    _draftStartGate = null;
    _draftSectorGates.clear();
    _pendingGateLeft = null;
    _inputMode = DrawInputMode.appendPath;
    notifyListeners();
  }

  void setInputMode(DrawInputMode mode) {
    _inputMode = mode;
    _pendingGateLeft = null;
    notifyListeners();
  }

  void undoLastPathPoint() {
    if (_draftPath.isEmpty) return;
    _draftPath.removeLast();
    notifyListeners();
  }

  /// Routes a single map tap to the right drafting bucket.
  void handleMapTap(GeoPoint p) {
    if (!_drawing) return;
    switch (_inputMode) {
      case DrawInputMode.appendPath:
        _draftPath.add(p);
      case DrawInputMode.startGate:
        if (_pendingGateLeft == null) {
          _pendingGateLeft = p;
        } else {
          _draftStartGate =
              GateDefinition(left: _pendingGateLeft!, right: p);
          _pendingGateLeft = null;
          _inputMode = DrawInputMode.appendPath;
        }
      case DrawInputMode.sectorGate:
        if (_pendingGateLeft == null) {
          _pendingGateLeft = p;
        } else {
          _draftSectorGates.add(
              GateDefinition(left: _pendingGateLeft!, right: p));
          _pendingGateLeft = null;
        }
    }
    notifyListeners();
  }

  Future<RouteTemplate?> saveDraft() async {
    if (!draftCanSave) return null;

    // Snap the drawn path to actual roads if the routing service is available.
    List<GeoPoint> finalPath = List.of(_draftPath);
    if (routingService != null && _draftPath.length >= 2) {
      _snapping = true;
      notifyListeners();
      final snapped = await routingService!.snapToRoads(_draftPath);
      _snapping = false;
      notifyListeners();
      if (snapped != null && snapped.length >= 2) {
        finalPath = snapped;
        debugPrint(
            'RoutingService: snapped ${_draftPath.length} waypoints → ${snapped.length} road points');
      } else {
        debugPrint('RoutingService: snapping failed, using raw waypoints');
      }
    }

    final id = 'route-${DateTime.now().microsecondsSinceEpoch}';
    final route = RouteTemplate(
      id: id,
      name: _draftName.trim(),
      description: _draftDescription?.trim().isEmpty ?? true
          ? null
          : _draftDescription!.trim(),
      path: List.unmodifiable(finalPath),
      startFinishGate: _draftStartGate!,
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
    _draftPath.clear();
    _draftStartGate = null;
    _draftSectorGates.clear();
    _pendingGateLeft = null;
    _inputMode = DrawInputMode.appendPath;
    await load();
    _selected = route;
    notifyListeners();
    return route;
  }

  // ---------- CRUD on existing routes ----------

  Future<void> deleteRoute(String id) async {
    await _repo.deleteRoute(id);
    if (_selected?.id == id) {
      _selected = null;
    }
    await load();
  }
}
