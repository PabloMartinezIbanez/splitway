import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../data/repositories/local_draft_repository.dart';
import '../../data/repositories/supabase_sync_service.dart';

enum RoutePreviewStatus { idle, loading, error }

class RouteEditorController extends ChangeNotifier {
  RouteEditorController({
    required this.repository,
    required this.syncService,
    this.editRouteId,
  });

  static const closureThresholdMeters = 30.0;
  static const routePreviewDebounce = Duration(milliseconds: 300);

  final LocalDraftRepository repository;
  final SupabaseSyncService syncService;
  final String? editRouteId;

  final List<GeoPoint> _waypoints = [];
  final List<GeoPoint> _sectorPoints = [];
  Timer? _routePreviewTimer;
  int _routePreviewRequestId = 0;

  RouteTemplate? _existingRoute;
  RouteDifficulty _selectedDifficulty = RouteDifficulty.easy;
  bool _isClosed = false;
  bool _isClosureCandidate = false;
  bool _sectorMode = false;
  bool _isSaving = false;
  bool _isLoading = false;
  bool? _manualClosedOverride;
  List<GeoPoint>? _snappedGeometryPreview;
  RoutePreviewStatus _routePreviewStatus = RoutePreviewStatus.idle;
  String _routeName = '';
  String _routeNotes = '';

  bool get isEditing => editRouteId != null;
  bool get canSave => _waypoints.length >= 2;
  bool get isClosed => _isClosed;
  bool get isClosureCandidate => _isClosureCandidate;
  bool get sectorMode => _sectorMode;
  bool get isSaving => _isSaving;
  bool get isLoading => _isLoading;
  bool get isRoutingPreviewLoading => _routePreviewStatus == RoutePreviewStatus.loading;
  RouteDifficulty get selectedDifficulty => _selectedDifficulty;
  RoutePreviewStatus get routePreviewStatus => _routePreviewStatus;
  String get routeName => _routeName;
  String get routeNotes => _routeNotes;
  List<GeoPoint> get waypoints => List.unmodifiable(_waypoints);
  List<GeoPoint> get sectorPoints => List.unmodifiable(_sectorPoints);
  List<GeoPoint>? get snappedGeometryPreview => _snappedGeometryPreview;
  List<GeoPoint> get routePreviewWaypoints {
    final points = List<GeoPoint>.from(_waypoints);
    if (_isClosed && points.length >= 2) {
      points.add(points.first);
    }
    return points;
  }

  List<GeoPoint> get displayedGeometry =>
      _snappedGeometryPreview ?? routePreviewWaypoints;

  Future<void> initialize() async {
    if (isEditing) {
      await _loadExistingRoute();
      return;
    }
    _syncClosureState();
  }

  void toggleSectorMode(bool enabled) {
    _sectorMode = enabled;
    notifyListeners();
  }

  void updateDraft({
    required String name,
    required String notes,
    required RouteDifficulty difficulty,
  }) {
    _routeName = name;
    _routeNotes = notes;
    _selectedDifficulty = difficulty;
    notifyListeners();
  }

  void addWaypoint(double latitude, double longitude) {
    _waypoints.add(GeoPoint(latitude: latitude, longitude: longitude));
    _syncClosureState();
    _scheduleRoutePreview();
    notifyListeners();
  }

  bool addSectorPoint(double latitude, double longitude) {
    final routeGeometry = displayedGeometry;
    if (routeGeometry.length < 2) {
      return false;
    }

    final snapped = _nearestPointOnRoute(latitude, longitude);
    if (snapped == null) {
      return false;
    }

    _sectorPoints.add(snapped);
    notifyListeners();
    return true;
  }

  void undo() {
    if (_sectorMode && _sectorPoints.isNotEmpty) {
      _sectorPoints.removeLast();
    } else if (_waypoints.isNotEmpty) {
      _waypoints.removeLast();
    }

    _syncClosureState();
    _scheduleRoutePreview();
    notifyListeners();
  }

  void setClosedPreference(bool value) {
    _manualClosedOverride = value;
    _isClosed = value;
    _scheduleRoutePreview();
    notifyListeners();
  }

  Future<RouteTemplate?> saveRoute() async {
    if (_isSaving || !canSave) {
      return null;
    }

    _isSaving = true;
    notifyListeners();

    try {
      await _ensureRoutePreviewIsCurrent();

      final routeId = isEditing ? editRouteId! : repository.createId('route');
      final route = RouteTemplate(
        id: routeId,
        name: _routeName.trim(),
        difficulty: _selectedDifficulty,
        isClosed: _isClosed,
        rawGeometry: List<GeoPoint>.from(_waypoints),
        snappedGeometry: _snappedGeometryPreview == null
            ? null
            : List<GeoPoint>.from(_snappedGeometryPreview!),
        startFinishGate: _buildGateFromPoint(
          _waypoints.first,
          'start-finish',
          'Salida/Meta',
        ),
        sectors: _buildSectors(routeId),
        notes: _routeNotes.trim().isEmpty ? null : _routeNotes.trim(),
        createdAt: _existingRoute?.createdAt ?? DateTime.now(),
      );

      await repository.saveRoute(route);
      return route;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _routePreviewTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadExistingRoute() async {
    _isLoading = true;
    notifyListeners();

    final route = await repository.loadRouteById(editRouteId!);
    if (route == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _existingRoute = route;
    _routeName = route.name;
    _routeNotes = route.notes ?? '';
    _selectedDifficulty = route.difficulty;
    _isClosed = route.isClosed;
    _manualClosedOverride = route.isClosed;
    _snappedGeometryPreview = route.snappedGeometry;
    _waypoints
      ..clear()
      ..addAll(route.rawGeometry);
    _sectorPoints
      ..clear()
      ..addAll(
        route.sectors.map(
          (sector) => GeoPoint(
            latitude: sector.gate.start.latitude,
            longitude: sector.gate.start.longitude,
          ),
        ),
      );
    _isLoading = false;
    _syncClosureState();
    _scheduleRoutePreview();
    notifyListeners();
  }

  List<SectorDefinition> _buildSectors(String routeId) {
    final sectors = <SectorDefinition>[];
    for (var index = 0; index < _sectorPoints.length; index++) {
      final point = _sectorPoints[index];
      sectors.add(
        SectorDefinition(
          id: repository.createId('sector'),
          routeTemplateId: routeId,
          order: index + 1,
          label: 'Sector ${index + 1}',
          gate: _buildGateFromPoint(point, 'gate-s${index + 1}', 'S${index + 1}'),
        ),
      );
    }
    return sectors;
  }

  GateDefinition _buildGateFromPoint(GeoPoint point, String id, String label) {
    const offsetDeg = 0.0003;
    return GateDefinition(
      id: id,
      label: label,
      start: GeoPoint(
        latitude: point.latitude - offsetDeg,
        longitude: point.longitude - offsetDeg,
      ),
      end: GeoPoint(
        latitude: point.latitude + offsetDeg,
        longitude: point.longitude + offsetDeg,
      ),
    );
  }

  void _syncClosureState() {
    final candidate = _waypoints.length >= 2 &&
        _haversineMeters(
              _waypoints.first.latitude,
              _waypoints.first.longitude,
              _waypoints.last.latitude,
              _waypoints.last.longitude,
            ) <
            closureThresholdMeters;
    _isClosureCandidate = candidate;
    _isClosed = _manualClosedOverride ?? candidate;
  }

  void _scheduleRoutePreview() {
    _routePreviewTimer?.cancel();

    if (_waypoints.length < 2) {
      _snappedGeometryPreview = null;
      _routePreviewStatus = RoutePreviewStatus.idle;
      return;
    }

    _snappedGeometryPreview = null;
    _routePreviewStatus = RoutePreviewStatus.loading;
    _routePreviewTimer = Timer(routePreviewDebounce, _resolveRoutePreview);
  }

  Future<void> _resolveRoutePreview() async {
    final requestId = ++_routePreviewRequestId;
    final payload = await syncService.requestDirections(
      waypoints: routePreviewWaypoints,
    );
    final geometry = syncService.parseGeometry(payload);

    if (requestId != _routePreviewRequestId) {
      return;
    }

    _snappedGeometryPreview = geometry;
    _routePreviewStatus =
        geometry == null ? RoutePreviewStatus.error : RoutePreviewStatus.idle;
    notifyListeners();
  }

  Future<void> _ensureRoutePreviewIsCurrent() async {
    _routePreviewTimer?.cancel();
    _routePreviewTimer = null;

    if (_waypoints.length < 2) {
      return;
    }

    await _resolveRoutePreview();
  }

  GeoPoint? _nearestPointOnRoute(double lat, double lng) {
    const maxDistanceM = 500.0;
    double bestDistance = double.infinity;
    GeoPoint? bestPoint;

    final routeGeometry = displayedGeometry;
    for (var index = 0; index < routeGeometry.length - 1; index++) {
      final a = routeGeometry[index];
      final b = routeGeometry[index + 1];
      final projected = _projectOntoSegment(lat, lng, a, b);
      final distance = _haversineMeters(
        lat,
        lng,
        projected.latitude,
        projected.longitude,
      );

      if (distance < bestDistance) {
        bestDistance = distance;
        bestPoint = projected;
      }
    }

    if (bestDistance <= maxDistanceM) {
      return bestPoint;
    }
    return null;
  }

  GeoPoint _projectOntoSegment(double lat, double lng, GeoPoint a, GeoPoint b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) {
      return a;
    }

    var t = ((lng - a.longitude) * dx + (lat - a.latitude) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);

    return GeoPoint(
      latitude: a.latitude + t * dy,
      longitude: a.longitude + t * dx,
    );
  }

  double totalDistanceKm() {
    var total = 0.0;
    for (var index = 0; index < _waypoints.length - 1; index++) {
      total += _haversineMeters(
        _waypoints[index].latitude,
        _waypoints[index].longitude,
        _waypoints[index + 1].latitude,
        _waypoints[index + 1].longitude,
      );
    }
    return total / 1000;
  }

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const radius = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final value = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return radius * 2 * atan2(sqrt(value), sqrt(1 - value));
  }

  static double _toRad(double deg) => deg * pi / 180;
}
