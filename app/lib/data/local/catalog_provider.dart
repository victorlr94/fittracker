import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database_provider.dart';
import 'catalog_seeder.dart';

part 'catalog_provider.g.dart';

/// Se resuelve cuando la siembra del catálogo terminó (o no hacía falta
/// correrla). La UI espera esto además de [databaseReadyProvider] antes
/// de mostrar las pantallas que dependen del catálogo.
@riverpod
Future<void> catalogSeeded(Ref ref) async {
  await ref.watch(databaseReadyProvider.future);
  final db = ref.watch(appDatabaseProvider);
  await CatalogSeeder(db).seedIfNeeded();
}
