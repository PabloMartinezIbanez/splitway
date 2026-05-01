import 'package:flutter/material.dart' hide Image;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:splitway_core/splitway_core.dart';

import 'route_map_painter.dart';

/// Wraps a real Mapbox `MapWidget` when [useMapbox] is true; otherwise falls
/// back to the iter 1 `RouteMapPainter`. The fallback keeps widget tests
/// working (no Mapbox SDK in test env) and lets the app boot without a
/// token configured.
///
/// Tap/long-press are reported with a [GeoPoint] in WGS84 (lat/lng).
class SplitwayMap extends StatefulWidget {
  const SplitwayMap({
    super.key,
    required this.useMapbox,
    this.route,
    this.telemetry = const [],
    this.draftPath = const [],
    this.draftStartGate,
    this.draftSectorGates = const [],
    this.highlightSectorId,
    this.onTap,
    this.onLongPress,
    this.styleUri,
  });

  final bool useMapbox;
  final RouteTemplate? route;
  final List<TelemetryPoint> telemetry;
  final List<GeoPoint> draftPath;
  final GateDefinition? draftStartGate;
  final List<GateDefinition> draftSectorGates;
  final String? highlightSectorId;
  final ValueChanged<GeoPoint>? onTap;
  final ValueChanged<GeoPoint>? onLongPress;
  final String? styleUri;

  @override
  State<SplitwayMap> createState() => _SplitwayMapState();
}

class _SplitwayMapState extends State<SplitwayMap> {
  mbx.MapboxMap? _map;
  mbx.PolylineAnnotationManager? _lineManager;
  mbx.CircleAnnotationManager? _circleManager;

  @override
  Widget build(BuildContext context) {
    if (!widget.useMapbox) {
      return _buildPainterFallback();
    }
    // Mapbox 2.x marks `cameraOptions`/`onTapListener`/`onLongTapListener` as
    // deprecated in favour of `viewport`/`MapboxMap.addInteraction`. The
    // newer API needs the map controller to register interactions per call,
    // which is more state plumbing than this iter wants. Migration to the
    // new API is tracked for iter 2.5.
    // ignore: deprecated_member_use
    return mbx.MapWidget(
      key: const ValueKey('splitway-mapbox'),
      styleUri: widget.styleUri ?? mbx.MapboxStyles.OUTDOORS,
      // ignore: deprecated_member_use
      cameraOptions: _initialCamera(),
      onMapCreated: _onMapCreated,
      // ignore: deprecated_member_use
      onTapListener: widget.onTap == null ? null : _handleTap,
      // ignore: deprecated_member_use
      onLongTapListener: widget.onLongPress == null ? null : _handleLongTap,
    );
  }

  @override
  void didUpdateWidget(covariant SplitwayMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.useMapbox &&
        (oldWidget.route != widget.route ||
            oldWidget.telemetry.length != widget.telemetry.length ||
            oldWidget.draftPath.length != widget.draftPath.length ||
            oldWidget.draftStartGate != widget.draftStartGate ||
            oldWidget.draftSectorGates.length !=
                widget.draftSectorGates.length ||
            oldWidget.highlightSectorId != widget.highlightSectorId)) {
      _renderAnnotations();
    }
  }

  Widget _buildPainterFallback() {
    final route = widget.route;
    if (route == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Text('Sin ruta')),
      );
    }
    return CustomPaint(
      painter: RouteMapPainter(
        route: route,
        telemetry: widget.telemetry,
        highlightSectorId: widget.highlightSectorId,
      ),
      child: const SizedBox.expand(),
    );
  }

  mbx.CameraOptions _initialCamera() {
    final center = _focusPoint();
    return mbx.CameraOptions(
      center: mbx.Point(
        coordinates: mbx.Position(center.longitude, center.latitude),
      ),
      zoom: 15,
    );
  }

  GeoPoint _focusPoint() {
    if (widget.route?.path.isNotEmpty ?? false) {
      return widget.route!.path.first;
    }
    if (widget.draftPath.isNotEmpty) return widget.draftPath.first;
    return const GeoPoint(latitude: 40.4168, longitude: -3.7038);
  }

  Future<void> _onMapCreated(mbx.MapboxMap map) async {
    _map = map;
    _lineManager = await map.annotations.createPolylineAnnotationManager();
    _circleManager = await map.annotations.createCircleAnnotationManager();
    await _renderAnnotations();
    await _flyToFitRoute();
  }

  Future<void> _flyToFitRoute() async {
    final map = _map;
    if (map == null) return;
    final geometry = _allGeometry();
    if (geometry.isEmpty) return;
    double minLat = geometry.first.latitude;
    double maxLat = minLat;
    double minLng = geometry.first.longitude;
    double maxLng = minLng;
    for (final p in geometry) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final spanLat = (maxLat - minLat).abs();
    final spanLng = (maxLng - minLng).abs();
    // Rough zoom estimate: each zoom step halves the visible span. At z=15
    // a degree of latitude is ~360/2^15 ≈ 0.011, so we pick the zoom that
    // makes the larger span fit in ~70% of the viewport.
    final span = (spanLat > spanLng ? spanLat : spanLng).clamp(1e-5, 1.0);
    final zoom = (15 - (span / 0.005).clamp(0.0, 6.0)).clamp(8.0, 18.0);
    await map.flyTo(
      mbx.CameraOptions(
        center: mbx.Point(coordinates: mbx.Position(centerLng, centerLat)),
        zoom: zoom,
      ),
      mbx.MapAnimationOptions(duration: 800),
    );
  }

  List<GeoPoint> _allGeometry() {
    final all = <GeoPoint>[];
    final r = widget.route;
    if (r != null) {
      all.addAll(r.path);
      all
        ..add(r.startFinishGate.left)
        ..add(r.startFinishGate.right);
      for (final s in r.sectors) {
        all
          ..add(s.gate.left)
          ..add(s.gate.right);
      }
    }
    all.addAll(widget.draftPath);
    final dsg = widget.draftStartGate;
    if (dsg != null) {
      all
        ..add(dsg.left)
        ..add(dsg.right);
    }
    for (final g in widget.draftSectorGates) {
      all
        ..add(g.left)
        ..add(g.right);
    }
    for (final t in widget.telemetry) {
      all.add(t.location);
    }
    return all;
  }

  Future<void> _renderAnnotations() async {
    final lineMgr = _lineManager;
    final circleMgr = _circleManager;
    if (lineMgr == null || circleMgr == null) return;

    await lineMgr.deleteAll();
    await circleMgr.deleteAll();

    final r = widget.route;
    if (r != null && r.path.isNotEmpty) {
      await lineMgr.create(mbx.PolylineAnnotationOptions(
        geometry: _toLineString(r.path),
        lineColor: 0xFF1565C0,
        lineWidth: 4,
      ));
      await _drawGate(lineMgr, circleMgr, r.startFinishGate,
          color: 0xFF2E7D32, width: 5);
      for (final s in r.sectors) {
        final highlight = s.id == widget.highlightSectorId;
        await _drawGate(
          lineMgr,
          circleMgr,
          s.gate,
          color: highlight ? 0xFFFFB300 : 0xFFC62828,
          width: highlight ? 5 : 4,
        );
      }
    }

    if (widget.telemetry.length >= 2) {
      await lineMgr.create(mbx.PolylineAnnotationOptions(
        geometry: _toLineString(
          widget.telemetry.map((t) => t.location).toList(growable: false),
        ),
        lineColor: 0xFFE65100,
        lineWidth: 3,
        lineOpacity: 0.85,
      ));
    }

    if (widget.draftPath.length >= 2) {
      await lineMgr.create(mbx.PolylineAnnotationOptions(
        geometry: _toLineString(widget.draftPath),
        lineColor: 0xFF6A1B9A,
        lineWidth: 3,
      ));
    }
    for (final p in widget.draftPath) {
      await circleMgr.create(mbx.CircleAnnotationOptions(
        geometry: mbx.Point(
            coordinates: mbx.Position(p.longitude, p.latitude)),
        circleColor: 0xFF6A1B9A,
        circleRadius: 4,
      ));
    }
    final dsg = widget.draftStartGate;
    if (dsg != null) {
      await _drawGate(lineMgr, circleMgr, dsg,
          color: 0xFF2E7D32, width: 4);
    }
    for (final g in widget.draftSectorGates) {
      await _drawGate(lineMgr, circleMgr, g, color: 0xFFC62828, width: 3);
    }
  }

  Future<void> _drawGate(
    mbx.PolylineAnnotationManager lines,
    mbx.CircleAnnotationManager circles,
    GateDefinition gate, {
    required int color,
    required double width,
  }) async {
    await lines.create(mbx.PolylineAnnotationOptions(
      geometry: _toLineString([gate.left, gate.right]),
      lineColor: color,
      lineWidth: width,
    ));
    for (final p in [gate.left, gate.right]) {
      await circles.create(mbx.CircleAnnotationOptions(
        geometry: mbx.Point(
            coordinates: mbx.Position(p.longitude, p.latitude)),
        circleColor: color,
        circleRadius: 5,
      ));
    }
  }

  mbx.LineString _toLineString(List<GeoPoint> points) {
    return mbx.LineString(
      coordinates:
          points.map((p) => mbx.Position(p.longitude, p.latitude)).toList(),
    );
  }

  void _handleTap(mbx.MapContentGestureContext ctx) {
    final coords = ctx.point.coordinates;
    widget.onTap?.call(GeoPoint(
      latitude: coords.lat.toDouble(),
      longitude: coords.lng.toDouble(),
    ));
  }

  void _handleLongTap(mbx.MapContentGestureContext ctx) {
    final coords = ctx.point.coordinates;
    widget.onLongPress?.call(GeoPoint(
      latitude: coords.lat.toDouble(),
      longitude: coords.lng.toDouble(),
    ));
  }
}
