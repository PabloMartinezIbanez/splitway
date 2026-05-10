import 'package:flutter/material.dart';
import 'package:splitway_core/splitway_core.dart';

/// Iter 1 placeholder for Mapbox. Renders a route, gates and (optionally)
/// a session telemetry trace by projecting lat/lng to the canvas with
/// uniform bounding-box scaling. Replaceable with a real MapboxMap in iter 2.
class RouteMapPainter extends CustomPainter {
  const RouteMapPainter({
    required this.route,
    this.telemetry = const [],
    this.highlightSectorId,
    this.showSectors = false,
  });

  final RouteTemplate route;
  final List<TelemetryPoint> telemetry;
  final String? highlightSectorId;
  final bool showSectors;

  static const _sectorColors = [
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFF00838F),
    Color(0xFFF57F17),
    Color(0xFF558B2F),
    Color(0xFF4527A0),
    Color(0xFFAD1457),
    Color(0xFF00695C),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final allPoints = <GeoPoint>[
      ...route.path,
      route.startFinishGate.left,
      route.startFinishGate.right,
      for (final s in route.sectors) ...[s.gate.left, s.gate.right],
      for (final p in telemetry) p.location,
    ];
    if (allPoints.isEmpty) return;

    double minLat = allPoints.first.latitude;
    double maxLat = minLat;
    double minLng = allPoints.first.longitude;
    double maxLng = minLng;
    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final pad = 0.0001;
    minLat -= pad;
    maxLat += pad;
    minLng -= pad;
    maxLng += pad;

    final spanLat = (maxLat - minLat).abs().clamp(1e-9, double.infinity);
    final spanLng = (maxLng - minLng).abs().clamp(1e-9, double.infinity);
    // Match aspect — pick the tighter scale.
    final scale = (size.width / spanLng).clamp(0.0, double.infinity) <
            (size.height / spanLat).clamp(0.0, double.infinity)
        ? size.width / spanLng
        : size.height / spanLat;

    final offsetX = (size.width - spanLng * scale) / 2;
    final offsetY = (size.height - spanLat * scale) / 2;

    Offset project(GeoPoint p) {
      final x = (p.longitude - minLng) * scale + offsetX;
      // Latitude grows northward, but canvas y grows downward.
      final y = (maxLat - p.latitude) * scale + offsetY;
      return Offset(x, y);
    }

    // Background grid.
    final gridPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.5;
    for (double x = 0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Path — plain or sector-colored.
    if (route.path.length >= 2) {
      if (showSectors && route.sectors.isNotEmpty) {
        final segments = _computeSectorSegments(route.path, route.sectors);
        for (var i = 0; i < segments.length; i++) {
          final seg = segments[i];
          if (seg.length < 2) continue;
          final paint = Paint()
            ..color = _sectorColors[i % _sectorColors.length]
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round;
          final p = Path()..moveTo(project(seg.first).dx, project(seg.first).dy);
          for (final pt in seg.skip(1)) {
            final o = project(pt);
            p.lineTo(o.dx, o.dy);
          }
          canvas.drawPath(p, paint);
        }
      } else {
        final pathPaint = Paint()
          ..color = const Color(0xFF1565C0)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round;
        final p = Path()
          ..moveTo(project(route.path.first).dx, project(route.path.first).dy);
        for (final pt in route.path.skip(1)) {
          final o = project(pt);
          p.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(p, pathPaint);
      }
    }

    // Telemetry trace (if any).
    if (telemetry.length >= 2) {
      final telPaint = Paint()
        ..color = const Color(0xFFE65100).withValues(alpha: 0.85)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final p = Path()
        ..moveTo(project(telemetry.first.location).dx,
            project(telemetry.first.location).dy);
      for (final t in telemetry.skip(1)) {
        final o = project(t.location);
        p.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(p, telPaint);
    }

    // Start/finish gate.
    _drawGate(canvas, project, route.startFinishGate,
        const Color(0xFF2E7D32), 4);

    // Sector gates.
    for (final s in route.sectors) {
      final isHighlight = s.id == highlightSectorId;
      _drawGate(canvas, project, s.gate,
          isHighlight ? const Color(0xFFFFB300) : const Color(0xFFC62828),
          isHighlight ? 4 : 3);
    }
  }

  List<List<GeoPoint>> _computeSectorSegments(
      List<GeoPoint> path, List<SectorDefinition> sectors) {
    if (sectors.isEmpty || path.length < 2) return [path];

    final breakIndices = sectors.map((s) {
      int bestIdx = 0;
      double bestDist = path[0].distanceTo(s.gate.center);
      for (var i = 1; i < path.length; i++) {
        final d = path[i].distanceTo(s.gate.center);
        if (d < bestDist) {
          bestDist = d;
          bestIdx = i;
        }
      }
      return bestIdx;
    }).toSet().toList()
      ..sort();

    final segments = <List<GeoPoint>>[];
    int start = 0;
    for (final bp in breakIndices) {
      if (bp > start) segments.add(path.sublist(start, bp + 1));
      start = bp;
    }
    if (start < path.length) segments.add(path.sublist(start));
    return segments;
  }

  void _drawGate(
    Canvas canvas,
    Offset Function(GeoPoint) project,
    GateDefinition gate,
    Color color,
    double width,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(project(gate.left), project(gate.right), paint);
    final dot = Paint()..color = color;
    canvas.drawCircle(project(gate.left), 3, dot);
    canvas.drawCircle(project(gate.right), 3, dot);
  }

  @override
  bool shouldRepaint(covariant RouteMapPainter oldDelegate) {
    return oldDelegate.route != route ||
        oldDelegate.telemetry.length != telemetry.length ||
        oldDelegate.highlightSectorId != highlightSectorId ||
        oldDelegate.showSectors != showSectors;
  }
}
