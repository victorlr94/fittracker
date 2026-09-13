import 'package:drift/drift.dart';
import 'package:fit_tracker/core/db/app_database.dart';
import 'package:fit_tracker/core/db/connection.dart';
import 'package:fit_tracker/data/local/exercise_repository.dart';
import 'package:flutter_test/flutter_test.dart';

int _now() => DateTime.now().millisecondsSinceEpoch;

ExercisesCompanion _catalogRow({
  required String sourceId,
  required String name,
  String? nameEs,
  List<String> primaryMuscles = const ['chest'],
}) {
  final now = _now();
  return ExercisesCompanion.insert(
    source: 'free-exercise-db',
    sourceId: Value(sourceId),
    name: name,
    nameEs: Value(nameEs),
    equipment: const Value('barbell'),
    level: const Value('intermediate'),
    primaryMuscles: Value('["${primaryMuscles.join('","')}"]'),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late AppDatabase db;
  late ExerciseRepository repo;

  setUp(() {
    db = AppDatabase(openTestConnection());
    repo = ExerciseRepository(db);
  });

  tearDown(() async => db.close());

  group('upsertFromCatalog', () {
    test('inserta un ejercicio nuevo', () async {
      await repo.upsertFromCatalog(
        _catalogRow(sourceId: 'Bench_Press', name: 'Bench Press'),
      );

      final rows = await repo.listAll();
      expect(rows, hasLength(1));
      expect(rows.single.name, 'Bench Press');
    });

    test('reejecutar la siembra no duplica filas', () async {
      final row = _catalogRow(sourceId: 'Bench_Press', name: 'Bench Press');
      await repo.upsertFromCatalog(row);
      await repo.upsertFromCatalog(row);

      final rows = await repo.listAll();
      expect(rows, hasLength(1));
    });

    test('actualiza el nombre cuando cambia en el catálogo', () async {
      await repo.upsertFromCatalog(
        _catalogRow(sourceId: 'Bench_Press', name: 'Bench Press (viejo)'),
      );
      await repo.upsertFromCatalog(
        _catalogRow(sourceId: 'Bench_Press', name: 'Barbell Bench Press'),
      );

      final rows = await repo.listAll();
      expect(rows.single.name, 'Barbell Bench Press');
    });

    test(
      'NO pisa is_favorite ni user_notes al resembrar (invariante #4)',
      () async {
        final id = await db
            .into(db.exercises)
            .insert(_catalogRow(sourceId: 'Bench_Press', name: 'Bench Press'));
        await repo.setFavorite(id, true);
        await repo.setUserNotes(id, 'ojo con el hombro izquierdo');

        // El catálogo trae una actualización de nombre, como pasaría al
        // resembrar con una versión nueva.
        await repo.upsertFromCatalog(
          _catalogRow(sourceId: 'Bench_Press', name: 'Barbell Bench Press'),
        );

        final updated = await repo.getById(id);
        expect(updated!.name, 'Barbell Bench Press'); // sí se actualizó
        expect(updated.isFavorite, isTrue); // esto NO se tocó
        expect(updated.userNotes, 'ojo con el hombro izquierdo'); // ni esto
      },
    );

    test('permite muchos ejercicios propios sin sourceId sin chocar entre sí', () async {
      final now = _now();
      final a = ExercisesCompanion.insert(
        source: 'user',
        name: 'Mi ejercicio A',
        createdAt: now,
        updatedAt: now,
      );
      final b = ExercisesCompanion.insert(
        source: 'user',
        name: 'Mi ejercicio B',
        createdAt: now,
        updatedAt: now,
      );

      await db.into(db.exercises).insert(a);
      await db.into(db.exercises).insert(b);

      expect(await repo.listAll(), hasLength(2));
    });
  });

  group('search', () {
    setUp(() async {
      await repo.upsertFromCatalog(
        _catalogRow(
          sourceId: 'Bench_Press',
          name: 'Barbell Bench Press',
          nameEs: 'Press de banca',
          primaryMuscles: ['chest'],
        ),
      );
      await repo.upsertFromCatalog(
        _catalogRow(
          sourceId: 'Squat',
          name: 'Barbell Squat',
          primaryMuscles: ['quadriceps'],
        ),
      );
    });

    test('encuentra por nombre en inglés', () async {
      final results = await repo.search(query: 'bench');
      expect(results.map((e) => e.sourceId), ['Bench_Press']);
    });

    test('encuentra por nombre en español sin acentos', () async {
      final results = await repo.search(query: 'banca');
      expect(results.map((e) => e.sourceId), ['Bench_Press']);
    });

    test('sin texto de búsqueda, devuelve todo ordenado por nombre', () async {
      final results = await repo.search();
      expect(results.map((e) => e.name), [
        'Barbell Bench Press',
        'Barbell Squat',
      ]);
    });

    test('filtra por músculo primario', () async {
      final results = await repo.search(muscle: 'quadriceps');
      expect(results.map((e) => e.sourceId), ['Squat']);
    });

    test('un texto sin resultados no rompe (ni con caracteres raros)', () async {
      expect(await repo.search(query: 'xyz-no-existe"'), isEmpty);
    });
  });
}
