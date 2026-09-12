import 'package:fit_tracker/core/db/app_database.dart';
import 'package:fit_tracker/core/db/connection.dart';
import 'package:fit_tracker/data/local/catalog_seeder.dart';
import 'package:fit_tracker/data/local/exercise_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(openTestConnection());
  });

  tearDown(() async => db.close());

  test(
    'siembra el catálogo real empaquetado en assets/catalog/',
    () async {
      await CatalogSeeder(db).seedIfNeeded();

      final exercises = await ExerciseRepository(db).listAll();
      // El pipeline de ingesta descarta un puñado de filas sin
      // instrucciones (ver tools/); el conteo exacto vive en
      // assets/catalog/manifest.json, aquí solo se confirma que la
      // siembra corrió de verdad y no quedó vacía ni truncada a unas
      // pocas filas.
      expect(exercises.length, greaterThan(800));

      final setting = await db.customSelect(
        "SELECT value FROM app_setting WHERE key = 'catalog_version_exercises'",
      ).getSingleOrNull();
      expect(setting, isNotNull);
    },
  );

  test('sembrar dos veces no duplica filas', () async {
    final seeder = CatalogSeeder(db);
    await seeder.seedIfNeeded();
    final firstCount = await ExerciseRepository(db).listAll();

    await seeder.seedIfNeeded(); // misma versión: no debe reprocesar nada
    final secondCount = await ExerciseRepository(db).listAll();

    expect(secondCount.length, firstCount.length);
  });
}
