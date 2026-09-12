import 'package:fit_tracker/core/db/app_database.dart';
import 'package:fit_tracker/core/db/connection.dart';
import 'package:fit_tracker/data/local/workout_repository.dart';
import 'package:fit_tracker/domain/entities/set_type.dart';
import 'package:fit_tracker/domain/entities/workout_exceptions.dart';
import 'package:fit_tracker/domain/services/one_rep_max.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _insertExercise(AppDatabase db, String name) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return db.into(db.exercises).insert(
        ExercisesCompanion.insert(
          source: 'user',
          name: name,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

void main() {
  late AppDatabase db;
  late WorkoutRepository repo;

  setUp(() {
    db = AppDatabase(openTestConnection());
    repo = WorkoutRepository(db);
  });

  tearDown(() async => db.close());

  group('rutinas', () {
    test('crear, listar, renombrar y borrar (lógico)', () async {
      final id = await repo.createRoutine(name: 'Empuje A');
      expect((await repo.listRoutines()).map((r) => r.name), ['Empuje A']);

      await repo.renameRoutine(id, name: 'Empuje A (v2)');
      expect((await repo.listRoutines()).single.name, 'Empuje A (v2)');

      await repo.deleteRoutine(id);
      expect(await repo.listRoutines(), isEmpty);
    });

    test('agregar ejercicios asigna posición incremental y se puede reordenar',
        () async {
      final routineId = await repo.createRoutine(name: 'Empuje A');
      final benchId = await _insertExercise(db, 'Bench Press');
      final ohpId = await _insertExercise(db, 'Overhead Press');

      await repo.addExerciseToRoutine(routineId: routineId, exerciseId: benchId);
      await repo.addExerciseToRoutine(routineId: routineId, exerciseId: ohpId);

      var items = await repo.exercisesForRoutine(routineId);
      expect(items.map((e) => e.exerciseId), [benchId, ohpId]);
      expect(items.map((e) => e.position), [0, 1]);

      await repo.reorderRoutineExercises([items[1].id, items[0].id]);
      items = await repo.exercisesForRoutine(routineId);
      expect(items.map((e) => e.exerciseId), [ohpId, benchId]);
    });
  });

  group('sesiones', () {
    test('sin sesión activa, getActiveSession da null', () async {
      expect(await repo.getActiveSession(), isNull);
    });

    test('iniciar una sesión la deja activa (endedAt null)', () async {
      final id = await repo.startSession(
        sessionDate: '2026-09-12',
        tzOffsetMinutes: -360,
      );

      final active = await repo.getActiveSession();
      expect(active!.id, id);
      expect(active.endedAt, isNull);
    });

    test('no se pueden tener dos sesiones activas a la vez', () async {
      await repo.startSession(sessionDate: '2026-09-12', tzOffsetMinutes: -360);

      expect(
        () => repo.startSession(sessionDate: '2026-09-12', tzOffsetMinutes: -360),
        throwsA(isA<ActiveSessionAlreadyExistsException>()),
      );
    });

    test('terminar una sesión libera el slot para una nueva', () async {
      final id = await repo.startSession(
        sessionDate: '2026-09-12',
        tzOffsetMinutes: -360,
      );
      await repo.endSession(id, bodyweightKg: 78.4);

      expect(await repo.getActiveSession(), isNull);
      final sessions = await repo.recentSessions();
      expect(sessions.single.endedAt, isNotNull);
      expect(sessions.single.bodyweightKg, 78.4);
    });
  });

  group('series y prellenado', () {
    test('las series quedan ordenadas por posición', () async {
      final sessionId = await repo.startSession(
        sessionDate: '2026-09-12',
        tzOffsetMinutes: -360,
      );
      final exerciseId = await _insertExercise(db, 'Bench Press');

      await repo.logSet(
        sessionId: sessionId,
        exerciseId: exerciseId,
        position: 1,
        reps: 8,
        weightKg: 80,
      );
      await repo.logSet(
        sessionId: sessionId,
        exerciseId: exerciseId,
        position: 0,
        setType: SetType.warmup,
        reps: 10,
        weightKg: 40,
      );

      final sets = await repo.setsForSession(sessionId);
      expect(sets.map((s) => s.setType), ['warmup', 'normal']);
    });

    test('sin historial previo, el prellenado da una lista vacía', () async {
      final exerciseId = await _insertExercise(db, 'Bench Press');
      expect(await repo.lastSetsForExercise(exerciseId), isEmpty);
    });

    test('el prellenado trae las series de la última sesión, no la activa',
        () async {
      final exerciseId = await _insertExercise(db, 'Bench Press');

      final pastSession = await repo.startSession(
        sessionDate: '2026-09-01',
        tzOffsetMinutes: -360,
      );
      await repo.logSet(
        sessionId: pastSession,
        exerciseId: exerciseId,
        position: 0,
        reps: 8,
        weightKg: 75,
      );
      await repo.endSession(pastSession);

      final activeSession = await repo.startSession(
        sessionDate: '2026-09-12',
        tzOffsetMinutes: -360,
      );

      final prefill = await repo.lastSetsForExercise(
        exerciseId,
        excludingSessionId: activeSession,
      );

      expect(prefill, hasLength(1));
      expect(prefill.single.weightKg, 75);
    });
  });

  group('progresión (volumen y 1RM por sesión)', () {
    test('el volumen excluye el calentamiento y el 1RM usa la mejor serie',
        () async {
      final exerciseId = await _insertExercise(db, 'Bench Press');
      final sessionId = await repo.startSession(
        sessionDate: '2026-09-12',
        tzOffsetMinutes: -360,
      );

      await repo.logSet(
        sessionId: sessionId,
        exerciseId: exerciseId,
        position: 0,
        setType: SetType.warmup,
        reps: 10,
        weightKg: 40,
      );
      await repo.logSet(
        sessionId: sessionId,
        exerciseId: exerciseId,
        position: 1,
        reps: 8,
        weightKg: 80,
      );
      await repo.logSet(
        sessionId: sessionId,
        exerciseId: exerciseId,
        position: 2,
        reps: 8,
        weightKg: 85, // mismas reps, más peso: 1RM estimado inequívocamente mayor
      );

      final progression = await repo.progressionForExercise(exerciseId);

      expect(progression, hasLength(1));
      final summary = progression.single;
      expect(summary.volume, 8 * 80 + 8 * 85); // el calentamiento no cuenta
      expect(
        summary.bestEstimatedOneRepMax,
        closeTo(estimateOneRepMaxEpley(85, 8), 0.001),
      );
    });

    test('una sesión sin series válidas para 1RM da null, no revienta',
        () async {
      final exerciseId = await _insertExercise(db, 'Plancha');
      final sessionId = await repo.startSession(
        sessionDate: '2026-09-12',
        tzOffsetMinutes: -360,
      );
      await repo.logSet(
        sessionId: sessionId,
        exerciseId: exerciseId,
        position: 0,
        durationSeconds: 60,
      );

      final progression = await repo.progressionForExercise(exerciseId);
      expect(progression.single.bestEstimatedOneRepMax, isNull);
      expect(progression.single.volume, 0);
    });

    test('varias sesiones quedan ordenadas por fecha', () async {
      final exerciseId = await _insertExercise(db, 'Bench Press');

      final s1 = await repo.startSession(
        sessionDate: '2026-09-01',
        tzOffsetMinutes: -360,
      );
      await repo.logSet(
        sessionId: s1,
        exerciseId: exerciseId,
        position: 0,
        reps: 8,
        weightKg: 70,
      );
      await repo.endSession(s1);

      final s2 = await repo.startSession(
        sessionDate: '2026-09-08',
        tzOffsetMinutes: -360,
      );
      await repo.logSet(
        sessionId: s2,
        exerciseId: exerciseId,
        position: 0,
        reps: 8,
        weightKg: 75,
      );

      final progression = await repo.progressionForExercise(exerciseId);
      expect(progression.map((p) => p.sessionDate), ['2026-09-01', '2026-09-08']);
      expect(progression.first.volume, lessThan(progression.last.volume));
    });
  });
}
