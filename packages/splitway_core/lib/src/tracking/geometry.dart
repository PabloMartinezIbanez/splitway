import '../models/geo_point.dart';

/// Orientation of the ordered triplet (p, q, r).
/// 0 = collinear, 1 = clockwise, -1 = counter-clockwise.
int _orientation(GeoPoint p, GeoPoint q, GeoPoint r) {
  // For short segments (a few tens of meters) we treat lat/lng as planar.
  // The angular error is negligible compared to GPS noise.
  final val = (q.longitude - p.longitude) * (r.latitude - q.latitude) -
      (q.latitude - p.latitude) * (r.longitude - q.longitude);
  if (val.abs() < 1e-12) return 0;
  return val > 0 ? 1 : -1;
}

/// True if segment a1-a2 properly intersects segment b1-b2.
/// Collinear overlaps return false — a vehicle gliding along a gate line
/// must not fire an event.
bool segmentsIntersect(GeoPoint a1, GeoPoint a2, GeoPoint b1, GeoPoint b2) {
  final o1 = _orientation(a1, a2, b1);
  final o2 = _orientation(a1, a2, b2);
  final o3 = _orientation(b1, b2, a1);
  final o4 = _orientation(b1, b2, a2);

  // Require strict crossing — both pairs must have opposite, non-zero
  // orientations. This rejects endpoint touches and collinear glide-bys,
  // which we don't want to count as gate crossings under GPS noise.
  if (o1 == 0 || o2 == 0 || o3 == 0 || o4 == 0) return false;
  return o1 != o2 && o3 != o4;
}
