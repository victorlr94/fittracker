import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables/exercises.dart';
import 'tables/food.dart';
import 'tables/meals.dart';
import 'tables/recipes.dart';
import 'tables/settings.dart';
import 'tables/workouts.dart';

part 'app_database.g.dart';

/// Base de datos de la app. Ver docs/01-modelo-de-datos.md para el DDL
/// conceptual completo y docs/00-decisiones.md ADR-002 para las reglas de
/// migración.
///
/// INVARIANTE (CLAUDE.md #2): una migración ya aplicada no se edita. El
/// esquema crece agregando la siguiente versión, nunca modificando
/// `_migrationVX` de una versión anterior.
@DriftDatabase(
  tables: [
    Foods,
    FoodPortions,
    Recipes,
    RecipeIngredients,
    RecipeSteps,
    MealEntries,
    NutritionTargets,
    Exercises,
    Routines,
    RoutineExercises,
    WorkoutSessions,
    WorkoutSets,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _lazyDefault());

  /// Abre la conexión real solo cuando hace falta (primer uso), no al
  /// construir el objeto. Permite inyectar otra conexión en pruebas sin
  /// pagar el costo de abrir el archivo real.
  static QueryExecutor _lazyDefault() =>
      LazyDatabase(() => openConnection());

  // Fase 0: solo la v1. La v2 (tablas de foto) llega en la Fase 4, como una
  // migración nueva — nunca reescribiendo esta.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createFullTextSearch(this);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// Tablas FTS5 de búsqueda y los triggers que las mantienen sincronizadas
/// con `food` y `exercise`. Drift no modela FTS5 de contenido externo de
/// forma nativa, así que esto se crea con SQL directo — exactamente el DDL
/// de docs/01-modelo-de-datos.md § Búsqueda: FTS5.
///
/// `remove_diacritics 2` no es cosmético: sin eso, "platano" no encuentra
/// "plátano" en una app en español.
Future<void> _createFullTextSearch(GeneratedDatabase db) async {
  await db.customStatement('''
    CREATE VIRTUAL TABLE food_fts USING fts5(
      name, name_es, brand,
      content = 'food', content_rowid = 'id',
      tokenize = "unicode61 remove_diacritics 2"
    );
  ''');
  await db.customStatement('''
    CREATE TRIGGER food_ai AFTER INSERT ON food BEGIN
      INSERT INTO food_fts(rowid, name, name_es, brand)
      VALUES (new.id, new.name, new.name_es, new.brand);
    END;
  ''');
  await db.customStatement('''
    CREATE TRIGGER food_ad AFTER DELETE ON food BEGIN
      INSERT INTO food_fts(food_fts, rowid, name, name_es, brand)
      VALUES ('delete', old.id, old.name, old.name_es, old.brand);
    END;
  ''');
  await db.customStatement('''
    CREATE TRIGGER food_au AFTER UPDATE ON food BEGIN
      INSERT INTO food_fts(food_fts, rowid, name, name_es, brand)
      VALUES ('delete', old.id, old.name, old.name_es, old.brand);
      INSERT INTO food_fts(rowid, name, name_es, brand)
      VALUES (new.id, new.name, new.name_es, new.brand);
    END;
  ''');

  await db.customStatement('''
    CREATE VIRTUAL TABLE exercise_fts USING fts5(
      name, name_es,
      content = 'exercise', content_rowid = 'id',
      tokenize = "unicode61 remove_diacritics 2"
    );
  ''');
  await db.customStatement('''
    CREATE TRIGGER exercise_ai AFTER INSERT ON exercise BEGIN
      INSERT INTO exercise_fts(rowid, name, name_es)
      VALUES (new.id, new.name, new.name_es);
    END;
  ''');
  await db.customStatement('''
    CREATE TRIGGER exercise_ad AFTER DELETE ON exercise BEGIN
      INSERT INTO exercise_fts(exercise_fts, rowid, name, name_es)
      VALUES ('delete', old.id, old.name, old.name_es);
    END;
  ''');
  await db.customStatement('''
    CREATE TRIGGER exercise_au AFTER UPDATE ON exercise BEGIN
      INSERT INTO exercise_fts(exercise_fts, rowid, name, name_es)
      VALUES ('delete', old.id, old.name, old.name_es);
      INSERT INTO exercise_fts(rowid, name, name_es)
      VALUES (new.id, new.name, new.name_es);
    END;
  ''');
}
