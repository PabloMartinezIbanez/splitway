class LapSummary {
  const LapSummary({
    required this.lapNumber,
    required this.duration,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.avgSpeedMps,
    this.completed = true,
  });

  final int lapNumber;
  final Duration duration;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final double avgSpeedMps;
  final bool completed;

  Map<String, dynamic> toJson() => {
        'lapNumber': lapNumber,
        'durationMs': duration.inMilliseconds,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'distanceMeters': distanceMeters,
        'avgSpeedMps': avgSpeedMps,
        'completed': completed,
      };

  factory LapSummary.fromJson(Map<String, dynamic> json) => LapSummary(
        lapNumber: json['lapNumber'] as int,
        duration: Duration(milliseconds: json['durationMs'] as int),
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        avgSpeedMps: (json['avgSpeedMps'] as num).toDouble(),
        completed: json['completed'] as bool? ?? true,
      );
}
