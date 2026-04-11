import 'package:carnometer_core/carnometer_core.dart';
import 'package:carnometer_mobile/src/bootstrap/app_bootstrap.dart';
import 'package:carnometer_mobile/src/config/app_config.dart';
import 'package:carnometer_mobile/src/data/local/carnometer_local_database.dart';
import 'package:carnometer_mobile/src/data/repositories/local_draft_repository.dart';
import 'package:carnometer_mobile/src/data/repositories/supabase_sync_service.dart';
import 'package:carnometer_mobile/src/features/editor/route_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creates a route with the selected difficulty', (tester) async {
    final database = _FakeCarnometerLocalDatabase();
    final repository = LocalDraftRepository(
      database: database,
      installId: 'test-installation',
    );
    final bundle = BootstrapBundle(
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteEditorScreen(bundle: bundle),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Puerto de Navacerrada');
    await tester.tap(find.text('Facil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Experto').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar ruta'));
    await tester.pumpAndSettle();

    expect(database.savedRoutes, hasLength(1));
    expect(database.savedRoutes.single.name, 'Puerto de Navacerrada');
    expect(database.savedRoutes.single.difficulty, RouteDifficulty.expert);
    expect(find.textContaining('Experto'), findsWidgets);
  });
}

class _FakeCarnometerLocalDatabase extends CarnometerLocalDatabase {
  final List<RouteTemplate> savedRoutes = [];

  @override
  Future<void> open() async {}

  @override
  Future<void> saveRouteTemplate(RouteTemplate route, {bool queueSync = true}) async {
    savedRoutes.removeWhere((item) => item.id == route.id);
    savedRoutes.insert(0, route);
  }

  @override
  Future<List<RouteTemplate>> loadRouteTemplates() async => List.unmodifiable(savedRoutes);
}
