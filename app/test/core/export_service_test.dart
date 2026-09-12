// Prueba del criterio de "terminado" de la Fase 0 (docs/02-roadmap.md):
// "exportar → desinstalar la app → reinstalar → importar → los datos
// están idénticos". Aquí "reinstalar" se simula con una segunda base de
// datos en memoria, vacía desde cero — la manera más fiel de probar el
// camino sin depender de un dispositivo real.
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:fit_tracker/core/db/app_database.dart';
import 'package:fit_tracker/core/db/connection.dart';
import 'package:fit_tracker/core/export/export_schema.dart';
import 'package:fit_tracker/core/export/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

/// Llena una base con al menos una fila representativa por tabla,
/// incluyendo las relaciones entre ellas (para que el orden de
/// restauración quede realmente puesto a prueba, no solo declarado).
Future<void> _seedRepresentativeData(AppDatabase db) async {
  final now = _nowMs();

  await db.into(db.appSettings).insert(AppSettingsCompanion.insert(
        key: 'catalog_version_foods',
        value: '1',
        updatedAt: now,
      ));

  final chickenId = await db.into(db.foods).insert(FoodsCompanion.insert(
        source: 'usda',
        sourceId: const Value('171077'),
        name: 'Chicken breast, cooked',
        nameEs: const Value('Pechuga de pollo cocida'),
        kcal100: 165,
        proteinG100: 31,
        carbsG100: 0,
        fatG100: 3.6,
        createdAt: now,
        updatedAt: now,
      ));
  final portionId = await db.into(db.foodPortions).insert(
        FoodPortionsCompanion.insert(
          foodId: chickenId,
          label: '1 pieza mediana',
          grams: 172,
          source: 'usda',
        ),
      );

  final recipeId = await db.into(db.recipes).insert(RecipesCompanion.insert(
        name: 'Pollo con verduras',
        servings: 4,
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.recipeIngredients).insert(
        RecipeIngredientsCompanion.insert(
          recipeId: recipeId,
          foodId: chickenId,
          grams: 600,
          displayPortionId: Value(portionId),
          position: 0,
        ),
      );
  await db.into(db.recipeSteps).insert(RecipeStepsCompanion.insert(
        recipeId: recipeId,
        position: 0,
        text_: 'Cortar la pechuga en cubos.',
      ));

  await db.into(db.mealEntries).insert(MealEntriesCompanion.insert(
        logDate: '2026-09-12',
        mealSlot: 'comida',
        foodId: const Value(1), // se sobreescribe abajo con chickenId real
        quantityG: const Value(150),
        kcal: 247.5,
        proteinG: 46.5,
        carbsG: 0,
        fatG: 5.4,
        loggedAt: now,
        tzOffsetMinutes: -360,
        createdAt: now,
        updatedAt: now,
      ).copyWith(foodId: Value(chickenId)));

  await db.into(db.nutritionTargets).insert(
        NutritionTargetsCompanion.insert(
          effectiveFrom: '2026-01-01',
          kcal: 2200,
          proteinG: 160,
          carbsG: 220,
          fatG: 70,
          createdAt: now,
        ),
      );

  final exerciseId = await db.into(db.exercises).insert(
        ExercisesCompanion.insert(
          source: 'free-exercise-db',
          sourceId: const Value('Bench_Press'),
          name: 'Bench Press',
          nameEs: const Value('Press de banca'),
          createdAt: now,
          updatedAt: now,
        ),
      );
  final routineId = await db.into(db.routines).insert(
        RoutinesCompanion.insert(
          name: 'Empuje A',
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db.into(db.routineExercises).insert(
        RoutineExercisesCompanion.insert(
          routineId: routineId,
          exerciseId: exerciseId,
          position: 0,
        ),
      );
  final sessionId = await db.into(db.workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          routineId: Value(routineId),
          sessionDate: '2026-09-12',
          startedAt: now,
          tzOffsetMinutes: -360,
          createdAt: now,
          updatedAt: now,
        ),
      );
  await db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
        sessionId: sessionId,
        exerciseId: exerciseId,
        position: 0,
        reps: const Value(8),
        weightKg: const Value(80),
        completedAt: now,
      ));
}

/// Lee todas las tablas en el mismo orden y forma que usa el exportador,
/// para comparar "antes" contra "después" sin pasar por JSON.
Future<Map<String, List<Map<String, Object?>>>> _snapshot(AppDatabase db) async {
  final result = <String, List<Map<String, Object?>>>{};
  for (final table in kExportTableOrder) {
    final rows = await db.customSelect('SELECT * FROM $table').get();
    result[table] = rows.map((r) => r.data).toList();
  }
  return result;
}

void main() {
  test('exportar y luego importar en una BD nueva reproduce los datos '
      'exactos (criterio de terminado de la Fase 0)', () async {
    final source = AppDatabase(openTestConnection());
    await _seedRepresentativeData(source);

    final before = await _snapshot(source);
    // Confirma que el seed de verdad tocó todas las tablas relevantes;
    // si alguien agrega una tabla y olvida sembrarla aquí, esta prueba
    // deja de probar nada silenciosamente sin este guardado.
    expect(before['food'], isNotEmpty);
    expect(before['workout_set'], isNotEmpty);
    expect(before['recipe_ingredient'], isNotEmpty);

    final export = await ExportService(source).exportAll();
    expect(export.rowCounts['food'], 1);
    expect(export.totalRows, before.values.fold(0, (a, l) => a + l.length));
    await source.close();

    // "Reinstalar": una base nueva, vacía, desde cero.
    final restored = AppDatabase(openTestConnection());
    final importResult = await ExportService(restored)
        .importFrom(export.zipBytes, isZip: true);

    expect(importResult.totalRows, export.totalRows);

    final after = await _snapshot(restored);
    for (final table in kExportTableOrder) {
      expect(after[table], equals(before[table]), reason: 'tabla: $table');
    }

    await restored.close();
  });

  test('importar reemplaza el contenido existente, no lo fusiona',
      () async {
    final db = AppDatabase(openTestConnection());
    final now = _nowMs();
    await db.into(db.foods).insert(FoodsCompanion.insert(
          source: 'user',
          name: 'Dato viejo que debe desaparecer',
          kcal100: 1,
          proteinG100: 1,
          carbsG100: 1,
          fatG100: 1,
          createdAt: now,
          updatedAt: now,
        ));

    final emptyExport = <String, Object?>{
      'format_version': kExportFormatVersion,
      'schema_version': db.schemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'tables': {for (final t in kExportTableOrder) t: <Object?>[]},
    };
    final bytes = Uint8List.fromList(
      utf8.encode(jsonEncode(emptyExport)),
    );

    await ExportService(db).importFrom(bytes, isZip: false);

    final rows = await db.customSelect('SELECT * FROM food').get();
    expect(rows, isEmpty);

    await db.close();
  });

  test('rechaza un .zip que no es un respaldo de FitTracker', () async {
    final db = AppDatabase(openTestConnection());
    final bogus = Archive()
      ..addFile(ArchiveFile.bytes('otra_cosa.txt', utf8.encode('hola')));
    final bogusZip = Uint8List.fromList(ZipEncoder().encode(bogus));

    expect(
      () => ExportService(db).importFrom(bogusZip, isZip: true),
      throwsA(isA<InvalidBackupException>()),
    );

    await db.close();
  });

  test('rechaza una versión de formato de respaldo no soportada',
      () async {
    final db = AppDatabase(openTestConnection());
    final payload = <String, Object?>{
      'format_version': 999,
      'tables': <String, Object?>{},
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

    expect(
      () => ExportService(db).importFrom(bytes, isZip: false),
      throwsA(isA<InvalidBackupException>()),
    );

    await db.close();
  });

  test('el .zip exportado trae un CSV legible por tabla', () async {
    final db = AppDatabase(openTestConnection());
    await _seedRepresentativeData(db);

    final export = await ExportService(db).exportAll();
    final archive = ZipDecoder().decodeBytes(export.zipBytes);
    final names = archive.files.map((f) => f.name).toSet();

    expect(names, contains('export.json'));
    expect(names, contains('food.csv'));

    ArchiveFile? foodCsv;
    for (final f in archive.files) {
      if (f.name == 'food.csv') foodCsv = f;
    }
    final csvText = utf8.decode(foodCsv!.content);
    expect(csvText, contains('kcal_100')); // encabezado en snake_case
    expect(csvText, contains('Chicken breast'));

    await db.close();
  });
}
