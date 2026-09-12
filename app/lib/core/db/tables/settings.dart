import 'package:drift/drift.dart';

/// Configuración clave-valor. La API key de Anthropic NUNCA vive aquí:
/// va en flutter_secure_storage (invariante #7 de CLAUDE.md).
///
/// Llaves conocidas: catalog_version_exercises, catalog_version_foods,
/// export_folder_uri, export_last_run_at, photo_month_cost_usd,
/// photo_prompt_version.
class AppSettings extends Table {
  @override
  String get tableName => 'app_setting';

  TextColumn get key => text().named('key')();
  TextColumn get value => text().named('value')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {key};
}
