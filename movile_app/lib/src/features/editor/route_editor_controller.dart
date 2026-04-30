import 'package:flutter/foundation.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../data/repositories/local_draft_repository.dart';

class RouteEditorController extends ChangeNotifier {
  RouteEditorController(this._repo);

  final LocalDraftRepository _repo;

  bool _loading = true;
  bool get loading => _loading;

  List<RouteTemplate> _routes = const [];
  List<RouteTemplate> get routes => _routes;

  RouteTemplate? _selected;
  RouteTemplate? get selected => _selected;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _routes = await _repo.getAllRoutes();
    _selected ??= _routes.isNotEmpty ? _routes.first : null;
    if (_selected != null) {
      // Refresh the selected reference in case the list changed.
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

  /// Iter 1: creates a small placeholder route around the demo center so the
  /// user can see the editor reflect their action. In iter 2 this will become
  /// a Mapbox-driven drawing flow.
  Future<RouteTemplate> createPlaceholderRoute({
    required String name,
    required RouteDifficulty difficulty,
    String? description,
  }) async {
    final id = 'route-${DateTime.now().microsecondsSinceEpoch}';
    final base = _routes.isNotEmpty
        ? _routes.first.startFinishGate.center
        : const GeoPoint(latitude: 40.4168, longitude: -3.7038);
    final route = RouteTemplate(
      id: id,
      name: name,
      description: description,
      path: [
        GeoPoint(latitude: base.latitude - 0.0008, longitude: base.longitude - 0.0008),
        GeoPoint(latitude: base.latitude + 0.0008, longitude: base.longitude - 0.0008),
        GeoPoint(latitude: base.latitude + 0.0008, longitude: base.longitude + 0.0008),
        GeoPoint(latitude: base.latitude - 0.0008, longitude: base.longitude + 0.0008),
        GeoPoint(latitude: base.latitude - 0.0008, longitude: base.longitude - 0.0008),
      ],
      startFinishGate: GateDefinition(
        left: GeoPoint(latitude: base.latitude - 0.001, longitude: base.longitude - 0.0008),
        right: GeoPoint(latitude: base.latitude - 0.0006, longitude: base.longitude - 0.0008),
      ),
      sectors: [
        SectorDefinition(
          id: '$id-sec-1',
          order: 0,
          label: 'Sector 1',
          gate: GateDefinition(
            left: GeoPoint(latitude: base.latitude + 0.0008, longitude: base.longitude - 0.0002),
            right: GeoPoint(latitude: base.latitude + 0.0008, longitude: base.longitude + 0.0002),
          ),
        ),
        SectorDefinition(
          id: '$id-sec-2',
          order: 1,
          label: 'Sector 2',
          gate: GateDefinition(
            left: GeoPoint(latitude: base.latitude - 0.0002, longitude: base.longitude + 0.0008),
            right: GeoPoint(latitude: base.latitude + 0.0002, longitude: base.longitude + 0.0008),
          ),
        ),
      ],
      difficulty: difficulty,
      createdAt: DateTime.now(),
    );
    await _repo.saveRouteTemplate(route);
    await load();
    _selected = route;
    notifyListeners();
    return route;
  }

  Future<void> deleteRoute(String id) async {
    await _repo.deleteRoute(id);
    if (_selected?.id == id) {
      _selected = null;
    }
    await load();
  }
}
