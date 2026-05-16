import 'package:flutter_test/flutter_test.dart';
import 'package:splitway_core/splitway_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:splitway_mobile/src/data/local/splitway_local_database.dart';
import 'package:splitway_mobile/src/data/repositories/local_draft_repository.dart';
import 'package:splitway_mobile/src/features/editor/route_editor_controller.dart';

Future<LocalDraftRepository> _makeRepo() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await SplitwayLocalDatabase.open(overridePath: inMemoryDatabasePath);
  return LocalDraftRepository(db);
}

void main() {
  late LocalDraftRepository repo;
  late RouteEditorController ctrl;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repo = await _makeRepo();
    ctrl = RouteEditorController(repo);
    ctrl.startDrawing(name: 'Test', difficulty: RouteDifficulty.medium);
    // Build a minimal draft path (3 collinear-ish points going east).
    ctrl.handleMapTap(const GeoPoint(latitude: 40.0, longitude: -3.0));
    ctrl.handleMapTap(const GeoPoint(latitude: 40.0, longitude: -2.9));
    ctrl.handleMapTap(const GeoPoint(latitude: 40.0, longitude: -2.8));
  });

  group('sectorPoint mode', () {
    test('enum contains sectorPoint (not sectorGate)', () {
      expect(DrawInputMode.values.map((e) => e.name), contains('sectorPoint'));
      expect(DrawInputMode.values.map((e) => e.name),
          isNot(contains('sectorGate')));
    });

    test(
        'tap in sectorPoint mode snaps to nearest path vertex and adds a sector gate',
        () {
      ctrl.setInputMode(DrawInputMode.sectorPoint);
      // Tap near the middle vertex (-2.9 lng).
      ctrl.handleMapTap(const GeoPoint(latitude: 40.001, longitude: -2.901));

      expect(ctrl.draftSectorGates, hasLength(1));
      // Gate center should be very close to the snapped path vertex.
      final center = ctrl.draftSectorGates.first.center;
      expect(
          center.distanceTo(const GeoPoint(latitude: 40.0, longitude: -2.9)),
          lessThan(50)); // within 50 m of the snapped vertex
    });

    test('two taps add two sector points', () {
      ctrl.setInputMode(DrawInputMode.sectorPoint);
      ctrl.handleMapTap(const GeoPoint(latitude: 40.001, longitude: -2.901));
      ctrl.handleMapTap(const GeoPoint(latitude: 40.001, longitude: -2.799));

      expect(ctrl.draftSectorGates, hasLength(2));
    });

    test('pendingGateLeft is always null in sectorPoint mode', () {
      ctrl.setInputMode(DrawInputMode.sectorPoint);
      ctrl.handleMapTap(const GeoPoint(latitude: 40.001, longitude: -2.901));
      expect(ctrl.pendingGateLeft, isNull);
    });

    test('draftSectorPoints has same length as draftSectorGates', () {
      ctrl.setInputMode(DrawInputMode.sectorPoint);
      ctrl.handleMapTap(const GeoPoint(latitude: 40.001, longitude: -2.901));
      expect(ctrl.draftSectorPoints, hasLength(1));
      ctrl.handleMapTap(const GeoPoint(latitude: 40.001, longitude: -2.799));
      expect(ctrl.draftSectorPoints, hasLength(2));
    });

    test('tap in sectorPoint mode with no draftPath does nothing', () async {
      // Fresh controller with no path.
      final emptyRepo = await _makeRepo();
      final emptyCtrl = RouteEditorController(emptyRepo);
      emptyCtrl.startDrawing(name: 'Empty', difficulty: RouteDifficulty.easy);
      emptyCtrl.setInputMode(DrawInputMode.sectorPoint);
      emptyCtrl.handleMapTap(const GeoPoint(latitude: 40.0, longitude: -3.0));

      expect(emptyCtrl.draftSectorGates, isEmpty);
    });
  });

  group('cancelDrawing resets sector points', () {
    test('draftSectorPoints cleared on cancel', () {
      ctrl.setInputMode(DrawInputMode.sectorPoint);
      ctrl.handleMapTap(const GeoPoint(latitude: 40.001, longitude: -2.901));
      expect(ctrl.draftSectorPoints, hasLength(1));

      ctrl.cancelDrawing();
      expect(ctrl.draftSectorPoints, isEmpty);
    });
  });
}
