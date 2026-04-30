import '../tracking/geometry.dart';
import 'geo_point.dart';

class GateDefinition {
  const GateDefinition({required this.left, required this.right});

  final GeoPoint left;
  final GeoPoint right;

  /// True if the trajectory from [from] to [to] crossed this gate's line.
  bool crossedBy(GeoPoint from, GeoPoint to) {
    return segmentsIntersect(from, to, left, right);
  }

  GeoPoint get center => GeoPoint(
        latitude: (left.latitude + right.latitude) / 2,
        longitude: (left.longitude + right.longitude) / 2,
      );

  Map<String, dynamic> toJson() => {
        'left': left.toJson(),
        'right': right.toJson(),
      };

  factory GateDefinition.fromJson(Map<String, dynamic> json) => GateDefinition(
        left: GeoPoint.fromJson(json['left'] as Map<String, dynamic>),
        right: GeoPoint.fromJson(json['right'] as Map<String, dynamic>),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GateDefinition && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);
}
