import 'package:carnometer_core/carnometer_core.dart';

import '../repositories/local_draft_repository.dart';

class DemoSeed {
  static Future<void> seedIfEmpty(LocalDraftRepository repository) async {
    final existingRoutes = await repository.loadRoutes();
    if (existingRoutes.isNotEmpty) {
      return;
    }

    final route = RouteTemplate(
      id: 'a0dfc7b4-99aa-4f42-b321-91c8ce8cbf01',
      name: 'Madrid Demo Loop',
      difficulty: RouteDifficulty.medium,
      isClosed: true,
      rawGeometry: const [
        GeoPoint(latitude: 40.4108, longitude: -3.7285),
        GeoPoint(latitude: 40.4215, longitude: -3.7089),
        GeoPoint(latitude: 40.4351, longitude: -3.6930),
        GeoPoint(latitude: 40.4240, longitude: -3.6673),
        GeoPoint(latitude: 40.4040, longitude: -3.6813),
        GeoPoint(latitude: 40.3954, longitude: -3.7114),
        GeoPoint(latitude: 40.4108, longitude: -3.7285),
      ],
      startFinishGate: const GateDefinition(
        id: 'start-finish',
        label: 'Start / finish',
        start: GeoPoint(latitude: 40.4101, longitude: -3.7291),
        end: GeoPoint(latitude: 40.4114, longitude: -3.7278),
      ),
      sectors: const [
        SectorDefinition(
          id: 'a0dfc7b4-99aa-4f42-b321-91c8ce8cbf11',
          routeTemplateId: 'a0dfc7b4-99aa-4f42-b321-91c8ce8cbf01',
          order: 1,
          label: 'Sector Norte',
          gate: GateDefinition(
            id: 'sector-1-gate',
            label: 'Sector Norte',
            start: GeoPoint(latitude: 40.4338, longitude: -3.7014),
            end: GeoPoint(latitude: 40.4362, longitude: -3.6986),
          ),
        ),
        SectorDefinition(
          id: 'a0dfc7b4-99aa-4f42-b321-91c8ce8cbf12',
          routeTemplateId: 'a0dfc7b4-99aa-4f42-b321-91c8ce8cbf01',
          order: 2,
          label: 'Sector Este',
          gate: GateDefinition(
            id: 'sector-2-gate',
            label: 'Sector Este',
            start: GeoPoint(latitude: 40.4134, longitude: -3.6698),
            end: GeoPoint(latitude: 40.4145, longitude: -3.6660),
          ),
        ),
      ],
      notes: 'Ruta de demostración para validar sectores y vueltas sin GPS real.',
      createdAt: DateTime.utc(2026, 4, 10),
    );

    await repository.saveRoute(route);
  }
}
