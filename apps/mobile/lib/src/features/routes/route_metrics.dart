import 'dart:math';

import 'package:splitway_core/splitway_core.dart';

class RouteMetrics {
  const RouteMetrics({
    required this.distanceKm,
    required this.pointCount,
    required this.sectorCount,
    required this.elevationDeltaM,
  });

  factory RouteMetrics.fromGeometry({
    required List<GeoPoint> geometry,
    required int sectorCount,
  }) {
    var distanceMeters = 0.0;
    for (var index = 0; index < geometry.length - 1; index++) {
      distanceMeters += _haversineMeters(
        geometry[index].latitude,
        geometry[index].longitude,
        geometry[index + 1].latitude,
        geometry[index + 1].longitude,
      );
    }

    return RouteMetrics(
      distanceKm: distanceMeters / 1000,
      pointCount: geometry.length,
      sectorCount: sectorCount,
      elevationDeltaM: null,
    );
  }

  final double distanceKm;
  final int pointCount;
  final int sectorCount;
  final double? elevationDeltaM;

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const radius = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final value =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return radius * 2 * atan2(sqrt(value), sqrt(1 - value));
  }

  static double _toRad(double deg) => deg * pi / 180;
}
