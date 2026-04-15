import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../../config/app_config.dart';
import 'route_editor_map_refresh_scheduler.dart';

class RouteEditorMapPanel extends StatefulWidget {
  const RouteEditorMapPanel({
    required this.config,
    required this.displayedGeometry,
    required this.waypoints,
    required this.sectorPoints,
    required this.sectorMode,
    required this.onMapTap,
    super.key,
  });

  final AppConfig config;
  final List<GeoPoint> displayedGeometry;
  final List<GeoPoint> waypoints;
  final List<GeoPoint> sectorPoints;
  final bool sectorMode;
  final void Function(double latitude, double longitude) onMapTap;

  @override
  State<RouteEditorMapPanel> createState() => _RouteEditorMapPanelState();
}

class _RouteEditorMapPanelState extends State<RouteEditorMapPanel> {
  MapboxMap? _map;
  CircleAnnotationManager? _circleManager;
  PolylineAnnotationManager? _polylineManager;
  late final RouteEditorMapRefreshScheduler _refreshScheduler;

  @override
  void initState() {
    super.initState();
    _refreshScheduler = RouteEditorMapRefreshScheduler(
      onRefresh: _refreshAnnotationsForGeneration,
    );
  }

  @override
  void didUpdateWidget(covariant RouteEditorMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshScheduler.requestRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.waypoints.isNotEmpty
        ? Position(
            widget.waypoints.first.longitude,
            widget.waypoints.first.latitude,
          )
        : Position(-3.7038, 40.4168);

    return Stack(
      children: [
        if (widget.config.hasMapboxToken)
          MapWidget(
            key: const ValueKey('route-editor-mapbox-map'),
            styleUri: widget.config.mapboxStyleUri,
            cameraOptions: CameraOptions(
              center: Point(coordinates: center),
              zoom: widget.waypoints.isNotEmpty ? 13 : 10.4,
            ),
            onMapCreated: _handleMapCreated,
            onStyleLoadedListener: _handleStyleLoaded,
            onTapListener: _handleTap,
          )
        else
          const _EditorMapFallback(),
        if (widget.sectorMode)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Modo sector activo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _refreshScheduler.dispose();
    _map = null;
    _circleManager = null;
    _polylineManager = null;
    super.dispose();
  }

  void _handleMapCreated(MapboxMap map) {
    _map = map;
    _circleManager = null;
    _polylineManager = null;
    _refreshScheduler.markMapRecreated();
  }

  Future<void> _handleStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null || !mounted) {
      return;
    }

    final generation = _refreshScheduler.currentGeneration;
    final circleManager = await map.annotations.createCircleAnnotationManager();
    final polylineManager = await map.annotations
        .createPolylineAnnotationManager();
    if (!mounted || !_refreshScheduler.isActiveGeneration(generation)) {
      return;
    }

    _circleManager = circleManager;
    _polylineManager = polylineManager;
    _refreshScheduler.markStyleReady();
    _refreshScheduler.requestRefresh();
  }

  void _handleTap(MapContentGestureContext context) {
    final coords = context.point.coordinates;
    widget.onMapTap(coords.lat.toDouble(), coords.lng.toDouble());
  }

  Future<void> _refreshAnnotationsForGeneration(int generation) async {
    final circleManager = _circleManager;
    final polylineManager = _polylineManager;
    if (circleManager == null ||
        polylineManager == null ||
        !_canApplyRefresh(generation)) {
      return;
    }

    final displayedGeometry = List<GeoPoint>.from(widget.displayedGeometry);
    final waypoints = List<GeoPoint>.from(widget.waypoints);
    final sectorPoints = List<GeoPoint>.from(widget.sectorPoints);

    await circleManager.deleteAll();
    await polylineManager.deleteAll();
    if (!_canApplyRefresh(generation)) {
      return;
    }

    final waypointCircles = waypoints
        .map(
          (point) => CircleAnnotationOptions(
            geometry: Point(
              coordinates: Position(point.longitude, point.latitude),
            ),
            circleRadius: 8,
            circleColor: const Color(0xFF2563EB).toARGB32(),
            circleStrokeColor: Colors.white.toARGB32(),
            circleStrokeWidth: 2,
          ),
        )
        .toList();
    final sectorCircles = sectorPoints
        .map(
          (point) => CircleAnnotationOptions(
            geometry: Point(
              coordinates: Position(point.longitude, point.latitude),
            ),
            circleRadius: 8,
            circleColor: const Color(0xFFEA580C).toARGB32(),
            circleStrokeColor: Colors.white.toARGB32(),
            circleStrokeWidth: 2,
          ),
        )
        .toList();

    if (waypointCircles.isNotEmpty) {
      await circleManager.createMulti(waypointCircles);
      if (!_canApplyRefresh(generation)) {
        return;
      }
    }
    if (sectorCircles.isNotEmpty) {
      await circleManager.createMulti(sectorCircles);
      if (!_canApplyRefresh(generation)) {
        return;
      }
    }

    if (displayedGeometry.length >= 2) {
      await polylineManager.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: displayedGeometry
                .map((point) => Position(point.longitude, point.latitude))
                .toList(),
          ),
          lineColor: const Color(0xFF2563EB).toARGB32(),
          lineWidth: 3.5,
        ),
      );
    }
  }

  bool _canApplyRefresh(int generation) =>
      mounted && _refreshScheduler.isRefreshAllowed(generation);
}

class _EditorMapFallback extends StatelessWidget {
  const _EditorMapFallback();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: const Color(0xFFE7DED1),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'Añade MAPBOX_ACCESS_TOKEN\npara ver el mapa',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
