import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../../config/app_config.dart';

class RouteMapPreview extends StatefulWidget {
  const RouteMapPreview({
    required this.route,
    required this.config,
    required this.mapKey,
    this.cameraZoom = 13,
    super.key,
  });

  final RouteTemplate route;
  final AppConfig config;
  final Key mapKey;
  final double cameraZoom;

  @override
  State<RouteMapPreview> createState() => _RouteMapPreviewState();
}

class _RouteMapPreviewState extends State<RouteMapPreview> {
  CircleAnnotationManager? _circleManager;
  PolylineAnnotationManager? _polylineManager;

  @override
  void dispose() {
    _circleManager?.deleteAll();
    _polylineManager?.deleteAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geometry = widget.route.effectiveGeometry;
    if (!widget.config.hasMapboxToken || geometry.isEmpty) {
      return _MapFallback(
        label: widget.config.hasMapboxToken
            ? 'La ruta aún no tiene geometría suficiente'
            : 'Añade MAPBOX_ACCESS_TOKEN para ver el mapa',
      );
    }

    return MapWidget(
      key: widget.mapKey,
      styleUri: widget.config.mapboxStyleUri,
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(geometry.first.longitude, geometry.first.latitude),
        ),
        zoom: widget.cameraZoom,
      ),
      onMapCreated: _handleMapCreated,
    );
  }

  Future<void> _handleMapCreated(MapboxMap map) async {
    _circleManager = await map.annotations.createCircleAnnotationManager();
    _polylineManager = await map.annotations.createPolylineAnnotationManager();
    await _refreshAnnotations();
  }

  Future<void> _refreshAnnotations() async {
    final circleManager = _circleManager;
    final polylineManager = _polylineManager;
    if (circleManager == null || polylineManager == null) {
      return;
    }

    await circleManager.deleteAll();
    await polylineManager.deleteAll();

    final geometry = widget.route.effectiveGeometry;
    if (geometry.length >= 2) {
      await polylineManager.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: geometry
                .map((point) => Position(point.longitude, point.latitude))
                .toList(),
          ),
          lineColor: const Color(0xFF9A3412).toARGB32(),
          lineWidth: 4,
        ),
      );
    }

    final circles = <CircleAnnotationOptions>[
      CircleAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            widget.route.startFinishGate.start.longitude,
            widget.route.startFinishGate.start.latitude,
          ),
        ),
        circleColor: const Color(0xFF0F766E).toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2,
        circleRadius: 9,
      ),
      ...widget.route.sectors.map(
        (sector) => CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              sector.gate.start.longitude,
              sector.gate.start.latitude,
            ),
          ),
          circleColor: const Color(0xFFEA580C).toARGB32(),
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2,
          circleRadius: 8,
        ),
      ),
    ];

    await circleManager.createMulti(circles);
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({required this.label});

  final String label;

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
                label,
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
