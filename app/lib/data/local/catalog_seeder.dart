import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/db/app_database.dart';
import 'exercise_repository.dart';

/// Siembra versionada del catálogo empaquetado en `assets/catalog/`
/// (docs/03-ingesta-de-datos.md). Compara la versión del manifiesto
/// contra `app_setting.catalog_version_*`; si no subió, no hace nada.
class CatalogSeeder {
  CatalogSeeder(this._db) : _exercises = ExerciseRepository(_db);

  final AppDatabase _db;
  final ExerciseRepository _exercises;

  static const _exercisesVersionKey = 'catalog_version_exercises';

  Future<void> seedIfNeeded() async {
    final manifestText = await rootBundle.loadString(
      'assets/catalog/manifest.json',
    );
    final manifest = jsonDecode(manifestText) as Map<String, dynamic>;
    final datasets = manifest['datasets'] as Map<String, dynamic>? ?? const {};

    final exercisesEntry = datasets['exercises'] as Map<String, dynamic>?;
    if (exercisesEntry != null) {
      await _seedExercisesIfNeeded(exercisesEntry['version'] as int);
    }
  }

  Future<void> _seedExercisesIfNeeded(int bundledVersion) async {
    final installed = await _getVersion(_exercisesVersionKey);
    if (installed != null && installed >= bundledVersion) {
      return;
    }

    final exercisesText = await rootBundle.loadString(
      'assets/catalog/exercises.json',
    );
    final rows = (jsonDecode(exercisesText) as List).cast<Map<String, dynamic>>();

    await _db.transaction(() async {
      for (final row in rows) {
        await _exercises.upsertFromCatalog(_toCompanion(row));
      }
      await _setVersion(_exercisesVersionKey, bundledVersion);
    });
  }

  ExercisesCompanion _toCompanion(Map<String, dynamic> row) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ExercisesCompanion.insert(
      source: row['source'] as String,
      sourceId: Value(row['source_id'] as String?),
      name: row['name'] as String,
      force: Value(row['force'] as String?),
      level: Value(row['level'] as String?),
      mechanic: Value(row['mechanic'] as String?),
      equipment: Value(row['equipment'] as String?),
      category: Value(row['category'] as String?),
      primaryMuscles: Value(jsonEncode(row['primary_muscles'])),
      secondaryMuscles: Value(jsonEncode(row['secondary_muscles'])),
      instructions: Value(jsonEncode(row['instructions'])),
      imageUrls: Value(jsonEncode(row['image_urls'])),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<int?> _getVersion(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    return int.tryParse(row.value);
  }

  Future<void> _setVersion(String key, int version) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db
        .into(_db.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: key,
            value: '$version',
            updatedAt: now,
          ),
          onConflict: DoUpdate.withExcluded(
            (old, excluded) => AppSettingsCompanion.custom(
              value: excluded.value,
              updatedAt: excluded.updatedAt,
            ),
            target: [_db.appSettings.key],
          ),
        );
  }
}
