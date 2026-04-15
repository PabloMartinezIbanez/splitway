import 'lap_summary.dart';
import 'manual_split_summary.dart';
import 'sector_summary.dart';
import 'telemetry_point.dart';

enum SessionRunStatus {
  draft,
  recording,
  completed,
  synced,
}

class SessionRun {
  const SessionRun({
    required this.id,
    required this.routeTemplateId,
    required this.installId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.distanceM,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.lapSummaries,
    required this.sectorSummaries,
    required this.manualSplitSummaries,
    required this.telemetry,
  });

  final String id;
  final String routeTemplateId;
  final String installId;
  final SessionRunStatus status;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceM;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final List<LapSummary> lapSummaries;
  final List<SectorSummary> sectorSummaries;
  final List<ManualSplitSummary> manualSplitSummaries;
  final List<TelemetryPoint> telemetry;

  Map<String, dynamic> toJson() => {
        'id': id,
        'routeTemplateId': routeTemplateId,
        'installId': installId,
        'status': status.name,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'distanceM': distanceM,
        'maxSpeedKmh': maxSpeedKmh,
        'avgSpeedKmh': avgSpeedKmh,
        'lapSummaries': lapSummaries.map((item) => item.toJson()).toList(),
        'sectorSummaries': sectorSummaries.map((item) => item.toJson()).toList(),
        'manualSplitSummaries':
            manualSplitSummaries.map((item) => item.toJson()).toList(),
        'telemetry': telemetry.map((item) => item.toJson()).toList(),
      };

  factory SessionRun.fromJson(Map<String, dynamic> json) => SessionRun(
        id: json['id'] as String,
        routeTemplateId: json['routeTemplateId'] as String,
        installId: json['installId'] as String,
        status: SessionRunStatus.values.byName(json['status'] as String),
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        distanceM: (json['distanceM'] as num).toDouble(),
        maxSpeedKmh: (json['maxSpeedKmh'] as num).toDouble(),
        avgSpeedKmh: (json['avgSpeedKmh'] as num).toDouble(),
        lapSummaries: (json['lapSummaries'] as List<dynamic>)
            .map((item) => LapSummary.fromJson(item as Map<String, dynamic>))
            .toList(),
        sectorSummaries: (json['sectorSummaries'] as List<dynamic>)
            .map((item) => SectorSummary.fromJson(item as Map<String, dynamic>))
            .toList(),
        manualSplitSummaries:
            ((json['manualSplitSummaries'] as List<dynamic>?) ?? const [])
                .map(
                  (item) =>
                      ManualSplitSummary.fromJson(item as Map<String, dynamic>),
                )
                .toList(),
        telemetry: (json['telemetry'] as List<dynamic>)
            .map((item) => TelemetryPoint.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
