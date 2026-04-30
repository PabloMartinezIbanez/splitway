import 'geo_point.dart';

class TelemetryPoint {
  const TelemetryPoint({
    required this.timestamp,
    required this.location,
    this.speedMps,
    this.accuracyMeters,
    this.bearingDeg,
    this.altitudeMeters,
  });

  final DateTime timestamp;
  final GeoPoint location;
  final double? speedMps;
  final double? accuracyMeters;
  final double? bearingDeg;
  final double? altitudeMeters;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'location': location.toJson(),
        'speedMps': speedMps,
        'accuracyMeters': accuracyMeters,
        'bearingDeg': bearingDeg,
        'altitudeMeters': altitudeMeters,
      };

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) => TelemetryPoint(
        timestamp: DateTime.parse(json['timestamp'] as String),
        location: GeoPoint.fromJson(json['location'] as Map<String, dynamic>),
        speedMps: (json['speedMps'] as num?)?.toDouble(),
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
        bearingDeg: (json['bearingDeg'] as num?)?.toDouble(),
        altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble(),
      );
}
