import 'package:splitway_core/splitway_core.dart';
import 'package:test/test.dart';

void main() {
  group('SessionRun', () {
    test('serializes and restores manual split summaries', () {
      final session = SessionRun(
        id: 'session-1',
        routeTemplateId: 'route-1',
        installId: 'install-1',
        status: SessionRunStatus.completed,
        startedAt: DateTime.utc(2026, 4, 14, 10, 0, 0),
        endedAt: DateTime.utc(2026, 4, 14, 10, 3, 0),
        distanceM: 1240,
        maxSpeedKmh: 45,
        avgSpeedKmh: 24,
        lapSummaries: const [],
        sectorSummaries: const [],
        manualSplitSummaries: const [
          ManualSplitSummary(
            splitNumber: 1,
            label: 'Manual 1',
            duration: Duration(seconds: 35),
            markedAt: Duration(seconds: 35),
          ),
          ManualSplitSummary(
            splitNumber: 2,
            label: 'Manual 2',
            duration: Duration(seconds: 41),
            markedAt: Duration(seconds: 76),
          ),
        ],
        telemetry: const [],
      );

      final json = session.toJson();
      final restored = SessionRun.fromJson(json);

      expect(json['manualSplitSummaries'], hasLength(2));
      expect(restored.manualSplitSummaries, hasLength(2));
      expect(restored.manualSplitSummaries.first.label, 'Manual 1');
      expect(
        restored.manualSplitSummaries.last.markedAt,
        const Duration(seconds: 76),
      );
    });

    test('defaults missing manual split summaries to empty for legacy sessions', () {
      final restored = SessionRun.fromJson({
        'id': 'legacy-session',
        'routeTemplateId': 'route-1',
        'installId': 'install-1',
        'status': 'completed',
        'startedAt': '2026-04-14T10:00:00.000Z',
        'endedAt': '2026-04-14T10:03:00.000Z',
        'distanceM': 1240,
        'maxSpeedKmh': 45,
        'avgSpeedKmh': 24,
        'lapSummaries': const [],
        'sectorSummaries': const [],
        'telemetry': const [],
      });

      expect(restored.manualSplitSummaries, isEmpty);
    });
  });
}
