import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:splitway_mobile/src/bootstrap/app_bootstrap.dart';
import 'package:splitway_mobile/src/config/app_config.dart';
import 'package:splitway_mobile/src/data/local/splitway_local_database.dart';
import 'package:splitway_mobile/src/data/repositories/local_draft_repository.dart';
import 'package:splitway_mobile/src/data/repositories/supabase_sync_service.dart';
import 'package:splitway_mobile/src/features/session/live_session_screen.dart';

void main() {
  testWidgets('persists manual sector marks in the saved session', (tester) async {
    final database = _FakeSplitwayLocalDatabase();
    final bundle = _buildBundle(database: database);

    await tester.pumpWidget(
      _buildTestApp(
        LiveSessionScreen(bundle: bundle, routeId: _demoRoute.id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar'));
    await tester.pump();

    await tester.tap(find.text('Sector'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(FilledButton, 'Fin'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar Sesión'));
    await tester.pumpAndSettle();

    expect(database.savedSessions, hasLength(1));
    expect(database.savedSessions.single.manualSplitSummaries, hasLength(1));
    expect(
      database.savedSessions.single.manualSplitSummaries.single.label,
      'Manual 1',
    );
  });

  testWidgets('keeps controls accessible on a narrow viewport', (tester) async {
    final database = _FakeSplitwayLocalDatabase();
    final bundle = _buildBundle(database: database);

    tester.view.physicalSize = const Size(320, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildTestApp(
        LiveSessionScreen(bundle: bundle, routeId: _demoRoute.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Iniciar'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _demoRoute = RouteTemplate(
  id: 'route-1',
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
      id: 'sector-1',
      routeTemplateId: 'route-1',
      order: 1,
      label: 'Sector Norte',
      gate: GateDefinition(
        id: 'sector-1-gate',
        label: 'Sector Norte',
        start: GeoPoint(latitude: 40.4338, longitude: -3.7014),
        end: GeoPoint(latitude: 40.4362, longitude: -3.6986),
      ),
    ),
  ],
  createdAt: DateTime.utc(2026, 4, 10),
);

BootstrapBundle _buildBundle({_FakeSplitwayLocalDatabase? database}) {
  final localDatabase = database ?? _FakeSplitwayLocalDatabase();
  final repository = LocalDraftRepository(
    database: localDatabase,
    installId: 'test-installation',
  );

  localDatabase.routes.add(_demoRoute);

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
        path: '/routes/:id',
        builder: (context, state) => const Scaffold(body: Text('Route detail')),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

class _FakeSplitwayLocalDatabase extends SplitwayLocalDatabase {
  final List<RouteTemplate> routes = [];
  final List<SessionRun> savedSessions = [];

  @override
  Future<void> open() async {}

  @override
  Future<RouteTemplate?> loadRouteTemplateById(String id) async {
    for (final route in routes) {
      if (route.id == id) {
        return route;
      }
    }
    return null;
  }

  @override
  Future<void> saveSessionRun(SessionRun session, {bool queueSync = true}) async {
    savedSessions.add(session);
  }
}
