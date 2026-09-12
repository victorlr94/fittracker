// Pruebas de humo de la migración v1: que el esquema se cree completo,
// que la búsqueda FTS5 funcione con acentos, y que las restricciones CHECK
// documentadas en docs/01-modelo-de-datos.md realmente se apliquen.
//
// No dependen de Flutter ni de un dispositivo: usan NativeDatabase.memory()
// (docs/02-roadmap.md, Fase 0 § qué se prueba: "cada migración").
import 'package:drift/drift.dart';
import 'package:fit_tracker/core/db/app_database.dart';
import 'package:fit_tracker/core/db/connection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(openTestConnection());
  });

  tearDown(() async {
    await db.close();
  });

  group('esquema v1', () {
    test('crea todas las tablas declaradas', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      final tableNames = rows.map((r) => r.read<String>('name')).toSet();

      const expected = {
        'food',
        'food_portion',
        'recipe',
        'recipe_ingredient',
        'recipe_step',
        'meal_entry',
        'nutrition_target',
        'exercise',
        'routine',
        'routine_exercise',
        'workout_session',
        'workout_set',
        'app_setting',
      };

      expect(tableNames.containsAll(expected), isTrue,
          reason: 'Faltan tablas: ${expected.difference(tableNames)}');
    });

    test('crea las tablas FTS5 y sus triggers de sincronización', () async {
      final rows = await db
          .customSelect(
            "SELECT name, type FROM sqlite_master "
            "WHERE name LIKE '%fts%' OR type = 'trigger'",
          )
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();

      expect(names, containsAll(<String>[
        'food_fts',
        'exercise_fts',
        'food_ai',
        'food_ad',
        'food_au',
        'exercise_ai',
        'exercise_ad',
        'exercise_au',
      ]));
    });
  });

  group('búsqueda FTS5', () {
    test('encuentra "platano" sin acento en un nombre con acento', () async {
      final now = _nowMs();
      await db.into(db.foods).insert(FoodsCompanion.insert(
            source: 'user',
            name: 'Plátano',
            kcal100: 89,
            proteinG100: 1.1,
            carbsG100: 22.8,
            fatG100: 0.3,
            createdAt: now,
            updatedAt: now,
          ));

      final rows = await db
          .customSelect(
            "SELECT rowid FROM food_fts WHERE food_fts MATCH 'platano'",
          )
          .get();

      expect(rows, hasLength(1));
    });

    test('el trigger de borrado limpia el índice', () async {
      final now = _nowMs();
      final id = await db.into(db.foods).insert(FoodsCompanion.insert(
            source: 'user',
            name: 'Aguacate',
            kcal100: 160,
            proteinG100: 2,
            carbsG100: 8.5,
            fatG100: 14.7,
            createdAt: now,
            updatedAt: now,
          ));

      await (db.delete(db.foods)..where((f) => f.id.equals(id))).go();

      final rows = await db
          .customSelect(
            "SELECT rowid FROM food_fts WHERE food_fts MATCH 'aguacate'",
          )
          .get();
      expect(rows, isEmpty);
    });
  });

  group('restricciones CHECK', () {
    test('rechaza un alimento con kcal negativas', () async {
      final now = _nowMs();
      expect(
        () => db.into(db.foods).insert(FoodsCompanion.insert(
              source: 'user',
              name: 'Dato corrupto',
              kcal100: -1,
              proteinG100: 0,
              carbsG100: 0,
              fatG100: 0,
              createdAt: now,
              updatedAt: now,
            )),
        throwsA(isA<SqliteException>()),
      );
    });

    test('permite dos alimentos propios sin sourceId sin chocar '
        '(NULL != NULL en el índice único)', () async {
      final now = _nowMs();
      final companion = FoodsCompanion.insert(
        source: 'user',
        name: 'Comida casera',
        kcal100: 100,
        proteinG100: 5,
        carbsG100: 10,
        fatG100: 2,
        createdAt: now,
        updatedAt: now,
      );

      await db.into(db.foods).insert(companion);
      // Si (source, sourceId) tratara NULL como un valor repetible-y-único,
      // esta segunda inserción del mismo source con sourceId ausente
      // fallaría. No debe fallar: así es como conviven muchos alimentos
      // propios (ADR-003 / docs/01-modelo-de-datos.md § food).
      await db.into(db.foods).insert(companion);

      final count = await db.customSelect('SELECT COUNT(*) AS c FROM food')
          .getSingle()
          .then((r) => r.read<int>('c'));
      expect(count, 2);
    });

    test('meal_entry exige exactamente uno de food_id / recipe_id',
        () async {
      final now = _nowMs();
      // Ninguno de los dos presente -> viola el CHECK de exclusividad.
      expect(
        () => db.into(db.mealEntries).insert(MealEntriesCompanion.insert(
              logDate: '2026-09-12',
              mealSlot: 'comida',
              kcal: 100,
              proteinG: 5,
              carbsG: 10,
              fatG: 2,
              loggedAt: now,
              tzOffsetMinutes: -360,
              createdAt: now,
              updatedAt: now,
            )),
        throwsA(isA<SqliteException>()),
      );
    });

    test('workout_set exige reps, duración o distancia', () async {
      final now = _nowMs();

      final exerciseId = await db.into(db.exercises).insert(
            ExercisesCompanion.insert(
              source: 'user',
              name: 'Sentadilla',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final sessionId = await db.into(db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              sessionDate: '2026-09-12',
              startedAt: now,
              tzOffsetMinutes: -360,
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(
        () => db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
              sessionId: sessionId,
              exerciseId: exerciseId,
              position: 0,
              completedAt: now,
            )),
        throwsA(isA<SqliteException>()),
      );
    });

    test('el volumen excluye las series de calentamiento por set_type',
        () async {
      // Prueba de regla, no de UI: confirma que set_type queda grabado
      // correctamente para que el cálculo de volumen (Fase 1) pueda
      // filtrar por él. El cálculo en sí vive en domain/services.
      final now = _nowMs();
      final exerciseId = await db.into(db.exercises).insert(
            ExercisesCompanion.insert(
              source: 'user',
              name: 'Press de banca',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final sessionId = await db.into(db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
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
            setType: const Value('warmup'),
            reps: const Value(10),
            weightKg: const Value(40),
            completedAt: now,
          ));
      await db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: 1,
            reps: const Value(8),
            weightKg: const Value(80),
            completedAt: now,
          ));

      final sets = await (db.select(db.workoutSets)
            ..where((s) => s.sessionId.equals(sessionId)))
          .get();
      final working = sets.where((s) => s.setType != 'warmup');
      final volume =
          working.fold<double>(0, (sum, s) => sum + (s.reps! * s.weightKg!));

      expect(volume, 640); // 8 x 80; el calentamiento (10 x 40) no cuenta.
    });
  });
}
