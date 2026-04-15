import 'package:splitway_core/splitway_core.dart';
import 'package:splitway_mobile/src/bootstrap/app_bootstrap.dart';
import 'package:splitway_mobile/src/config/app_config.dart';
import 'package:splitway_mobile/src/data/local/splitway_local_database.dart';
import 'package:splitway_mobile/src/data/repositories/local_draft_repository.dart';
import 'package:splitway_mobile/src/data/repositories/supabase_sync_service.dart';
import 'package:splitway_mobile/src/features/editor/route_editor_screen.dart';
import 'package:splitway_mobile/src/features/editor/widgets/route_editor_map_panel.dart';
import 'package:splitway_mobile/src/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('back from create route opened on home returns to home', (
    tester,
  ) async {
    final database = _FakeSplitwayLocalDatabase();
    final bundle = _buildBundle(database: database);

    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildAppRouter(bundle)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear Nueva Ruta'));
    await tester.pumpAndSettle();
    expect(find.text('Crear ruta'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué quieres hacer?'), findsOneWidget);
  });

  testWidgets('save button is disabled until 2+ waypoints are added', (
    tester,
  ) async {
    final database = _FakeSplitwayLocalDatabase();
    final bundle = _buildBundle(database: database);

    await tester.pumpWidget(_buildTestApp(RouteEditorScreen(bundle: bundle)));
    await tester.pumpAndSettle();

    // The save icon button should be disabled when no waypoints exist
    final saveButton = find.byIcon(Icons.save);
    expect(saveButton, findsOneWidget);

    // Find the IconButton wrapping the save icon
    final iconButton = tester.widget<IconButton>(
      find.ancestor(of: saveButton, matching: find.byType(IconButton)),
    );
    expect(
      iconButton.onPressed,
      isNull,
      reason: 'Save should be disabled with no waypoints',
    );
  });

  testWidgets(
    'persists snapped closed route when last waypoint is within 30 meters',
    (tester) async {
      final database = _FakeSplitwayLocalDatabase();
      final syncService = _FakeSupabaseSyncService(
        directionsResponse: {
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [-3.7038, 40.4168],
              [-3.7025, 40.4175],
              [-3.7038, 40.4168],
            ],
          },
        },
      );
      final bundle = _buildBundle(database: database, syncService: syncService);

      await tester.pumpWidget(_buildTestApp(RouteEditorScreen(bundle: bundle)));
      await tester.pumpAndSettle();

      await _addWaypoint(tester, latitude: 40.4168, longitude: -3.7038);
      await _addWaypoint(tester, latitude: 40.4174, longitude: -3.7028);
      await _addWaypoint(tester, latitude: 40.41681, longitude: -3.70381);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );

      await tester.enterText(find.byType(TextFormField).first, 'Ruta cerrada');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(syncService.requestedWaypoints, hasLength(4));
      expect(
        syncService.requestedWaypoints!.first.latitude,
        closeTo(40.4168, 0.000001),
      );
      expect(
        syncService.requestedWaypoints!.last.latitude,
        closeTo(40.4168, 0.000001),
      );

      final saved = database.savedRoutes.single;
      expect(saved.isClosed, isTrue);
      expect(saved.snappedGeometry, isNotNull);
      expect(saved.snappedGeometry, hasLength(3));
      expect(saved.rawGeometry, hasLength(3));
    },
  );

  testWidgets('respects manual open override for closure candidates', (
    tester,
  ) async {
    final database = _FakeSplitwayLocalDatabase();
    final syncService = _FakeSupabaseSyncService(
      directionsResponse: {
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [-3.7038, 40.4168],
            [-3.7025, 40.4175],
            [-3.7038, 40.4168],
          ],
        },
      },
    );
    final bundle = _buildBundle(database: database, syncService: syncService);

    await tester.pumpWidget(_buildTestApp(RouteEditorScreen(bundle: bundle)));
    await tester.pumpAndSettle();

    await _addWaypoint(tester, latitude: 40.4168, longitude: -3.7038);
    await _addWaypoint(tester, latitude: 40.4174, longitude: -3.7028);
    await _addWaypoint(tester, latitude: 40.41681, longitude: -3.70381);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Ruta abierta');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    final saved = database.savedRoutes.single;
    expect(saved.isClosed, isFalse);
    expect(saved.snappedGeometry, isNotNull);
  });

  testWidgets('falls back to raw geometry when directions are unavailable', (
    tester,
  ) async {
    final database = _FakeSplitwayLocalDatabase();
    final syncService = _FakeSupabaseSyncService(directionsResponse: null);
    final bundle = _buildBundle(database: database, syncService: syncService);

    await tester.pumpWidget(_buildTestApp(RouteEditorScreen(bundle: bundle)));
    await tester.pumpAndSettle();

    await _addWaypoint(tester, latitude: 40.4168, longitude: -3.7038);
    await _addWaypoint(tester, latitude: 40.4174, longitude: -3.7028);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Ruta fallback');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    final saved = database.savedRoutes.single;
    expect(saved.isClosed, isFalse);
    expect(saved.snappedGeometry, isNull);
    expect(saved.rawGeometry, hasLength(2));
  });

  testWidgets('keeps editor controls accessible on a narrow viewport', (
    tester,
  ) async {
    final database = _FakeSplitwayLocalDatabase();
    final bundle = _buildBundle(database: database);

    tester.view.physicalSize = const Size(320, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildTestApp(RouteEditorScreen(bundle: bundle)));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Añadir punto manual'), findsNothing);
    expect(find.text('Nuevo trazado'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Waypoint'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Sector'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses draggable bottom sheet to keep map dominant', (
    tester,
  ) async {
    final database = _FakeSplitwayLocalDatabase();
    final bundle = _buildBundle(database: database);

    await tester.pumpWidget(_buildTestApp(RouteEditorScreen(bundle: bundle)));
    await tester.pumpAndSettle();

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byTooltip('Añadir punto manual'), findsNothing);
    expect(find.text('Nuevo trazado'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Waypoint'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Sector'), findsOneWidget);
  });
}

BootstrapBundle _buildBundle({
  _FakeSplitwayLocalDatabase? database,
  SupabaseSyncService? syncService,
}) {
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
    syncService:
        syncService ??
        const SupabaseSyncService(
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

Future<void> _addWaypoint(
  WidgetTester tester, {
  required double latitude,
  required double longitude,
}) async {
  final mapPanel = tester.widget<RouteEditorMapPanel>(
    find.byType(RouteEditorMapPanel),
  );
  mapPanel.onMapTap(latitude, longitude);
  await tester.pumpAndSettle();
}

class _FakeSplitwayLocalDatabase extends SplitwayLocalDatabase {
  final List<RouteTemplate> savedRoutes = [];

  @override
  Future<void> open() async {}

  @override
  Future<void> saveRouteTemplate(
    RouteTemplate route, {
    bool queueSync = true,
  }) async {
    savedRoutes.removeWhere((item) => item.id == route.id);
    savedRoutes.insert(0, route);
  }

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
}

class _FakeSupabaseSyncService extends SupabaseSyncService {
  _FakeSupabaseSyncService({required this.directionsResponse})
    : super(client: null, mapboxBaseUrl: 'https://api.mapbox.com');

  final Map<String, dynamic>? directionsResponse;
  List<GeoPoint>? requestedWaypoints;

  @override
  Future<Map<String, dynamic>?> requestDirections({
    required List<GeoPoint> waypoints,
    String profile = 'driving',
  }) async {
    requestedWaypoints = List<GeoPoint>.from(waypoints);
    return directionsResponse;
  }
}
