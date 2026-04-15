import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:splitway_mobile/src/bootstrap/app_bootstrap.dart';
import 'package:splitway_mobile/src/config/app_config.dart';
import 'package:splitway_mobile/src/data/local/splitway_local_database.dart';
import 'package:splitway_mobile/src/data/repositories/local_draft_repository.dart';
import 'package:splitway_mobile/src/data/repositories/supabase_sync_service.dart';
import 'package:splitway_mobile/src/features/routes/route_detail_screen.dart';

void main() {
  testWidgets('uses draggable bottom sheet with compact route actions', (
    tester,
  ) async {
    await initializeDateFormatting('es_ES');
    final database = _FakeSplitwayLocalDatabase()
      ..savedRoutes.add(_sampleRoute());
    final bundle = _buildBundle(database: database);

    await tester.pumpWidget(
      _buildTestApp(RouteDetailScreen(bundle: bundle, routeId: 'route-1')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Iniciar Cronómetro'),
      findsOneWidget,
    );
    expect(find.text('Editar'), findsOneWidget);
  });
}

BootstrapBundle _buildBundle({_FakeSplitwayLocalDatabase? database}) {
  final localDatabase = database ?? _FakeSplitwayLocalDatabase();
  final repository = LocalDraftRepository(
    database: localDatabase,
    installId: 'test-installation',
  );

  return BootstrapBundle(
    config: const AppConfig(
      supabaseUrl: '',
      supabaseAnonKey: '',
      mapboxAccessToken: '',
      mapboxStyleUri: 'mapbox://styles/mapbox/streets-v12',
      mapboxBaseUrl: 'https://api.mapbox.com',
    ),
    repository: repository,
    syncService: const SupabaseSyncService(
      client: null,
      mapboxBaseUrl: 'https://api.mapbox.com',
    ),
    installId: 'test-installation',
    isSupabaseEnabled: false,
  );
}

Widget _buildTestApp(Widget child) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => child),
      GoRoute(
        path: '/routes',
        builder: (context, state) => const Scaffold(body: Text('Routes')),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

RouteTemplate _sampleRoute() {
  return RouteTemplate(
    id: 'route-1',
    name: 'Ruta de prueba',
    difficulty: RouteDifficulty.medium,
    isClosed: false,
    rawGeometry: const [
      GeoPoint(latitude: 40.4168, longitude: -3.7038),
      GeoPoint(latitude: 40.4174, longitude: -3.7028),
    ],
    startFinishGate: const GateDefinition(
      id: 'gate-1',
      label: 'Salida/Meta',
      start: GeoPoint(latitude: 40.4168, longitude: -3.7038),
      end: GeoPoint(latitude: 40.4169, longitude: -3.7037),
    ),
    sectors: const [],
    createdAt: DateTime(2026, 4, 14),
  );
}

class _FakeSplitwayLocalDatabase extends SplitwayLocalDatabase {
  final List<RouteTemplate> savedRoutes = [];

  @override
  Future<void> open() async {}

  @override
  Future<List<RouteTemplate>> loadRouteTemplates() async =>
      List.unmodifiable(savedRoutes);

  @override
  Future<RouteTemplate?> loadRouteTemplateById(String id) async {
    for (final route in savedRoutes) {
      if (route.id == id) {
        return route;
      }
    }
    return null;
  }

  @override
  Future<List<SessionRun>> loadSessionRunsByRouteId(String routeId) async =>
      const [];
}
