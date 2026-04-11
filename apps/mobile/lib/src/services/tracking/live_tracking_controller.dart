import 'dart:async';

import 'package:carnometer_core/carnometer_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LiveTrackingController extends ChangeNotifier {
  LiveTrackingController({
    required this.route,
  }) : _engine = TrackingEngine(route: route);

  final RouteTemplate route;
  final TrackingEngine _engine;

  StreamSubscription<Position>? _gpsSubscription;

  TrackingSnapshot get snapshot => _engine.snapshot;

  Future<void> startGpsTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission not granted.');
    }

    await _gpsSubscription?.cancel();
    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((position) {
      _engine.addPoint(
        TelemetryPoint(
          timestamp: position.timestamp,
          latitude: position.latitude,
          longitude: position.longitude,
          speedMps: position.speed,
          accuracyM: position.accuracy,
          headingDeg: position.heading,
          altitudeM: position.altitude,
        ),
      );
      notifyListeners();
    });
  }

  Future<void> stopGpsTracking() async {
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
  }

  Future<void> simulateDemoLap() async {
    final base = DateTime.now().toUtc();
    final demoPoints = <TelemetryPoint>[
      TelemetryPoint(
        timestamp: base,
        latitude: route.startFinishGate.start.latitude - 0.0006,
        longitude: route.startFinishGate.start.longitude,
        speedMps: 12,
        accuracyM: 4,
        headingDeg: 0,
      ),
      TelemetryPoint(
        timestamp: base.add(const Duration(seconds: 10)),
        latitude: route.startFinishGate.start.latitude + 0.0006,
        longitude: route.startFinishGate.start.longitude,
        speedMps: 23,
        accuracyM: 4,
        headingDeg: 0,
      ),
      ...route.sectors.mapIndexed((index, sector) {
        return TelemetryPoint(
          timestamp: base.add(Duration(seconds: 30 + (index * 20))),
          latitude: sector.gate.start.latitude + 0.0008,
          longitude: sector.gate.start.longitude,
          speedMps: 18 + index.toDouble(),
          accuracyM: 4,
          headingDeg: 0,
        );
      }),
      TelemetryPoint(
        timestamp: base.add(Duration(seconds: 30 + (route.sectors.length * 20) + 10)),
        latitude: route.startFinishGate.start.latitude - 0.0006,
        longitude: route.startFinishGate.start.longitude,
        speedMps: 16,
        accuracyM: 4,
        headingDeg: 0,
      ),
      TelemetryPoint(
        timestamp: base.add(Duration(seconds: 30 + (route.sectors.length * 20) + 20)),
        latitude: route.startFinishGate.start.latitude + 0.0006,
        longitude: route.startFinishGate.start.longitude,
        speedMps: 16,
        accuracyM: 4,
        headingDeg: 0,
      ),
    ];

    for (final point in demoPoints) {
      _engine.addPoint(point);
    }

    notifyListeners();
  }

  SessionRun buildCompletedSession({
    required String sessionId,
    required String installId,
  }) {
    return _engine.buildCompletedSession(
      sessionId: sessionId,
      installId: installId,
    );
  }
}

extension on Iterable<SectorDefinition> {
  Iterable<T> mapIndexed<T>(T Function(int index, SectorDefinition sector) build) sync* {
    var index = 0;
    for (final sector in this) {
      yield build(index, sector);
      index += 1;
    }
  }
}
