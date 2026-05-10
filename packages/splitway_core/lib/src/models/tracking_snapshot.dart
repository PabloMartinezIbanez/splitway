enum TrackingStatus { idle, awaitingStart, inLap, finished }

class TrackingSnapshot {
  const TrackingSnapshot({
    required this.status,
    required this.currentLap,
    required this.currentLapElapsed,
    required this.totalDistanceMeters,
    required this.lastSpeedMps,
    this.lastCrossedSectorId,
    this.lastSectorTime,
    this.bestLap,
  });

  final TrackingStatus status;
  final int currentLap;
  final Duration currentLapElapsed;
  final double totalDistanceMeters;
  final double lastSpeedMps;
  final String? lastCrossedSectorId;
  final Duration? lastSectorTime;
  final Duration? bestLap;

  static const TrackingSnapshot initial = TrackingSnapshot(
    status: TrackingStatus.idle,
    currentLap: 0,
    currentLapElapsed: Duration.zero,
    totalDistanceMeters: 0,
    lastSpeedMps: 0,
  );
}
