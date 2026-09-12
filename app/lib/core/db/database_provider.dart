import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';

part 'database_provider.g.dart';

/// Instancia única de la base de datos para toda la app.
///
/// `keepAlive: true`: la conexión debe sobrevivir mientras la app esté
/// viva, no cerrarse cuando el último widget que la observa se desmonte
/// (por ejemplo, al cambiar de pestaña).
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

/// Se resuelve cuando la base de datos abrió y la migración corrió sin
/// errores. La conexión es perezosa (`LazyDatabase`), así que solo
/// construir `AppDatabase` no basta para probar que abre de verdad: hace
/// falta tocarla. Sirve como criterio de "terminado" de la Fase 0 ("la app
/// crea la base de datos en el primer arranque") y como pantalla de espera
/// si algo falla, en vez de un error silencioso.
@riverpod
Future<void> databaseReady(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  await db.customSelect('SELECT 1').getSingle();
}
