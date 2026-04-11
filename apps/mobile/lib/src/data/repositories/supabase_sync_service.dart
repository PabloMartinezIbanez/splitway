import 'package:carnometer_core/carnometer_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/carnometer_local_database.dart';

class SupabaseSyncService {
  const SupabaseSyncService({
    required this.client,
    required this.mapboxBaseUrl,
  });

  final SupabaseClient? client;
  final String mapboxBaseUrl;

  bool get isEnabled => client != null;

  Future<void> syncPending(
    CarnometerLocalDatabase database, {
    required String installId,
  }) async {
    if (client == null) {
      return;
    }

    final pending = await database.loadPendingSyncItems();
    for (final item in pending) {
      switch (item.entityType) {
        case 'route_template':
          final route = await database.loadRouteTemplateById(item.entityId);
          if (route != null) {
            await syncRouteTemplate(route, installId: installId);
            await database.markSynced(item.entityType, item.entityId);
          }
          break;
        case 'session_run':
          final session = await database.loadSessionRunById(item.entityId);
          if (session != null) {
            await syncSessionRun(session, installId: installId);
            await database.markSynced(item.entityType, item.entityId);
          }
          break;
      }
    }
  }

  Future<void> syncRouteTemplate(
    RouteTemplate route, {
    required String installId,
  }) async {
    final supabase = client;
    if (supabase == null) {
      return;
    }

    await supabase.from('route_templates').upsert({
      'id': route.id,
      'install_id': installId,
      'name': route.name,
      'is_closed': route.isClosed,
      'raw_geometry': _lineString(route.rawGeometry),
      'snapped_geometry':
          route.snappedGeometry == null ? null : _lineString(route.snappedGeometry!),
      'start_finish_gate': _gateLine(route.startFinishGate),
      'notes': route.notes,
      'created_at': route.createdAt.toIso8601String(),
    });

    await supabase.from('sectors').delete().eq('route_template_id', route.id);

    if (route.sectors.isNotEmpty) {
      await supabase.from('sectors').insert(
            route.sectors
                .map(
                  (sector) => {
                    'id': sector.id,
                    'route_template_id': route.id,
                    'display_order': sector.order,
                    'label': sector.label,
                    'gate_geometry': _gateLine(sector.gate),
                    'direction_hint': sector.directionHint ?? sector.gate.directionHint,
                  },
                )
                .toList(),
          );
    }
  }

  Future<void> syncSessionRun(
    SessionRun session, {
    required String installId,
  }) async {
    final supabase = client;
    if (supabase == null) {
      return;
    }

    await supabase.from('session_runs').upsert({
      'id': session.id,
      'route_template_id': session.routeTemplateId,
      'install_id': installId,
      'status': session.status.name,
      'started_at': session.startedAt.toIso8601String(),
      'ended_at': session.endedAt.toIso8601String(),
      'distance_m': session.distanceM,
      'max_speed_kmh': session.maxSpeedKmh,
      'avg_speed_kmh': session.avgSpeedKmh,
      'lap_summaries': session.lapSummaries.map((item) => item.toJson()).toList(),
      'sector_summaries': session.sectorSummaries.map((item) => item.toJson()).toList(),
    });

    await supabase.from('telemetry_points').delete().eq('session_run_id', session.id);

    if (session.telemetry.isNotEmpty) {
      await supabase.from('telemetry_points').insert(
            session.telemetry
                .map(
                  (point) => {
                    'session_run_id': session.id,
                    'timestamp': point.timestamp.toIso8601String(),
                    'latitude': point.latitude,
                    'longitude': point.longitude,
                    'speed_mps': point.speedMps,
                    'accuracy_m': point.accuracyM,
                    'heading_deg': point.headingDeg,
                    'altitude_m': point.altitudeM,
                  },
                )
                .toList(),
          );
    }
  }

  Future<Map<String, dynamic>?> requestDirections({
    required List<GeoPoint> waypoints,
    String profile = 'driving',
  }) async {
    final supabase = client;
    if (supabase == null) {
      return null;
    }

    final response = await supabase.functions.invoke(
      'mapbox-routing',
      body: {
        'mode': 'directions',
        'profile': profile,
        'points': waypoints
            .map(
              (point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              },
            )
            .toList(),
      },
    );

    return response.data as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> requestMapMatching({
    required List<GeoPoint> trace,
    String profile = 'driving',
  }) async {
    final supabase = client;
    if (supabase == null) {
      return null;
    }

    final response = await supabase.functions.invoke(
      'mapbox-routing',
      body: {
        'mode': 'map-matching',
        'profile': profile,
        'points': trace
            .map(
              (point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              },
            )
            .toList(),
      },
    );

    return response.data as Map<String, dynamic>?;
  }

  Map<String, dynamic> _lineString(List<GeoPoint> points) => {
        'type': 'LineString',
        'coordinates': points
            .map((point) => [point.longitude, point.latitude])
            .toList(growable: false),
      };

  Map<String, dynamic> _gateLine(GateDefinition gate) => {
        'type': 'LineString',
        'coordinates': [
          [gate.start.longitude, gate.start.latitude],
          [gate.end.longitude, gate.end.latitude],
        ],
      };
}
