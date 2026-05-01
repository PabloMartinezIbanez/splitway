import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import 'src/app.dart';
import 'src/config/app_config.dart';
import 'src/data/demo/demo_seed.dart';
import 'src/data/local/splitway_local_database.dart';
import 'src/data/repositories/local_draft_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES');

  final config = await AppConfig.load();
  if (config.hasMapbox) {
    mbx.MapboxOptions.setAccessToken(config.mapboxToken!);
  }

  final database = await SplitwayLocalDatabase.open();
  final seedRepo = LocalDraftRepository(database);
  await DemoSeed.ensureSeeded(seedRepo);
  await seedRepo.dispose();

  runApp(SplitwayApp(config: config, database: database));
}
