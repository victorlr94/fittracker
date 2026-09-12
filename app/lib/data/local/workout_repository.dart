import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/logged_set.dart';
import '../../domain/entities/set_type.dart';
import '../../domain/entities/workout_exceptions.dart';
import '../../domain/services/one_rep_max.dart';
import '../../domain/services/volume_calculator.dart';

/// Resumen de una sesión para un ejercicio: lo que alimenta las gráficas
/// de progresión de la Fase 1 (docs/02-roadmap.md).
class ExerciseSessionSummary {
  const ExerciseSessionSummary({
    required this.sessionId,
    required this.sessionDate,
    required this.volume,
    required this.bestEstimatedOneRepMax,
  });

  final int sessionId;

  /// 'YYYY-MM-DD' local.
  final String sessionDate;
  final double volume;

  /// Epley, sobre la mejor serie de la sesión. `null` si ninguna serie
  /// tuvo reps y peso válidos (p. ej. solo series de tiempo/distancia).
  final double? bestEstimatedOneRepMax;
}

/// Acceso a rutinas, sesiones y series. La regla de "solo una sesión
/// activa a la vez" se impone aquí, no en el esquema (docs/01-modelo-de-datos.md
/// § workout_session): SQLite no puede expresar "a lo más una fila con
/// endedAt NULL" como una restricción declarativa limpia.
class WorkoutRepository {
  WorkoutRepository(this._db);

  final AppDatabase _db;

  // --- Rutinas ---

  Future<List<Routine>> listRoutines() {
    return (_db.select(_db.routines)
          ..where((r) => r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .get();
  }

  Future<int> createRoutine({required String name, String? description}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.into(_db.routines).insert(
          RoutinesCompanion.insert(
            name: name,
            description: Value(description),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> renameRoutine(int id, {required String name, String? description}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (_db.update(_db.routines)..where((r) => r.id.equals(id))).write(
      RoutinesCompanion(
        name: Value(name),
        description: Value(description),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteRoutine(int id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (_db.update(_db.routines)..where((r) => r.id.equals(id))).write(
      RoutinesCompanion(deletedAt: Value(now)),
    );
  }

  Future<List<RoutineExercise>> exercisesForRoutine(int routineId) {
    return (_db.select(_db.routineExercises)
          ..where((re) => re.routineId.equals(routineId))
          ..orderBy([(re) => OrderingTerm.asc(re.position)]))
        .get();
  }

  Future<void> addExerciseToRoutine({
    required int routineId,
    required int exerciseId,
    int? targetSets,
    int? targetRepsMin,
    int? targetRepsMax,
    int? restSeconds,
  }) async {
    final current = await exercisesForRoutine(routineId);
    await _db.into(_db.routineExercises).insert(
          RoutineExercisesCompanion.insert(
            routineId: routineId,
            exerciseId: exerciseId,
            position: current.length,
            targetSets: Value(targetSets),
            targetRepsMin: Value(targetRepsMin),
            targetRepsMax: Value(targetRepsMax),
            restSeconds: Value(restSeconds),
          ),
        );
  }

  Future<void> removeExerciseFromRoutine(int routineExerciseId) {
    return (_db.delete(
      _db.routineExercises,
    )..where((re) => re.id.equals(routineExerciseId))).go();
  }

  /// `(routineId, position)` es único, así que reasignar posiciones de un
  /// jalón puede chocar a medio camino (mover el ítem 1 a la posición 0
  /// mientras el ítem 0 todavía la ocupa). Se despeja primero a posiciones
  /// negativas temporales, dentro de la misma transacción, para que nunca
  /// haya un choque transitorio.
  Future<void> reorderRoutineExercises(List<int> routineExerciseIdsInOrder) {
    return _db.transaction(() async {
      for (var i = 0; i < routineExerciseIdsInOrder.length; i++) {
        await (_db.update(_db.routineExercises)
              ..where((re) => re.id.equals(routineExerciseIdsInOrder[i])))
            .write(RoutineExercisesCompanion(position: Value(-(i + 1))));
      }
      for (var i = 0; i < routineExerciseIdsInOrder.length; i++) {
        await (_db.update(_db.routineExercises)
              ..where((re) => re.id.equals(routineExerciseIdsInOrder[i])))
            .write(RoutineExercisesCompanion(position: Value(i)));
      }
    });
  }

  // --- Sesiones ---

  /// `null` si no hay ninguna sesión en curso.
  Future<WorkoutSession?> getActiveSession() {
    return (_db.select(
      _db.workoutSessions,
    )..where((s) => s.endedAt.isNull())).getSingleOrNull();
  }

  /// Lanza [ActiveSessionAlreadyExistsException] si ya hay una sesión sin
  /// terminar — nunca se pueden tener dos a la vez.
  Future<int> startSession({
    int? routineId,
    required String sessionDate,
    required int tzOffsetMinutes,
  }) async {
    final active = await getActiveSession();
    if (active != null) {
      throw const ActiveSessionAlreadyExistsException();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.into(_db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            routineId: Value(routineId),
            sessionDate: sessionDate,
            startedAt: now,
            tzOffsetMinutes: tzOffsetMinutes,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> endSession(int sessionId, {double? bodyweightKg, String? notes}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (_db.update(_db.workoutSessions)..where((s) => s.id.equals(sessionId)))
        .write(
      WorkoutSessionsCompanion(
        endedAt: Value(now),
        bodyweightKg: Value(bodyweightKg),
        notes: Value(notes),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<WorkoutSession>> recentSessions({int limit = 30}) {
    return (_db.select(_db.workoutSessions)
          ..orderBy([(s) => OrderingTerm.desc(s.sessionDate)])
          ..limit(limit))
        .get();
  }

  // --- Series ---

  Future<List<WorkoutSet>> setsForSession(int sessionId) {
    return (_db.select(_db.workoutSets)
          ..where((s) => s.sessionId.equals(sessionId))
          ..orderBy([(s) => OrderingTerm.asc(s.position)]))
        .get();
  }

  /// Igual que [setsForSession], pero como stream: la pantalla de sesión
  /// en vivo se refresca sola al registrar cada serie, sin recargar a mano.
  Stream<List<WorkoutSet>> watchSetsForSession(int sessionId) {
    return (_db.select(_db.workoutSets)
          ..where((s) => s.sessionId.equals(sessionId))
          ..orderBy([(s) => OrderingTerm.asc(s.position)]))
        .watch();
  }

  Stream<WorkoutSession?> watchActiveSession() {
    return (_db.select(
      _db.workoutSessions,
    )..where((s) => s.endedAt.isNull())).watchSingleOrNull();
  }

  Future<int> logSet({
    required int sessionId,
    required int exerciseId,
    required int position,
    SetType setType = SetType.normal,
    int? reps,
    double? weightKg,
    int? durationSeconds,
    double? distanceM,
    double? rpe,
    int? supersetGroup,
    String? notes,
  }) {
    return _db.into(_db.workoutSets).insert(
          WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: position,
            setType: Value(setType.toDb()),
            reps: Value(reps),
            weightKg: Value(weightKg),
            durationSeconds: Value(durationSeconds),
            distanceM: Value(distanceM),
            rpe: Value(rpe),
            supersetGroup: Value(supersetGroup),
            notes: Value(notes),
            completedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> deleteSet(int setId) {
    return (_db.delete(_db.workoutSets)..where((s) => s.id.equals(setId))).go();
  }

  /// Las series de la sesión más reciente (distinta de [excludingSessionId],
  /// normalmente la activa) en la que se registró este ejercicio. Es el
  /// prellenado: "la última vez hiciste 3x8 a 80 kg".
  Future<List<WorkoutSet>> lastSetsForExercise(
    int exerciseId, {
    int? excludingSessionId,
  }) async {
    final sessionRow = await _db
        .customSelect(
          'SELECT session_id FROM workout_set '
          'WHERE exercise_id = ? AND session_id != ? '
          'ORDER BY completed_at DESC LIMIT 1',
          variables: [
            Variable(exerciseId),
            Variable(excludingSessionId ?? -1),
          ],
        )
        .getSingleOrNull();
    if (sessionRow == null) return const [];

    final sessionId = sessionRow.read<int>('session_id');
    return (_db.select(_db.workoutSets)
          ..where(
            (s) => s.sessionId.equals(sessionId) & s.exerciseId.equals(exerciseId),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.position)]))
        .get();
  }

  /// Volumen y mejor 1RM estimado por sesión, para las gráficas de
  /// progresión de un ejercicio. Ordenado por fecha ascendente.
  Future<List<ExerciseSessionSummary>> progressionForExercise(
    int exerciseId,
  ) async {
    final rows = await (_db.select(_db.workoutSets).join([
          innerJoin(
            _db.workoutSessions,
            _db.workoutSessions.id.equalsExp(_db.workoutSets.sessionId),
          ),
        ])
          ..where(_db.workoutSets.exerciseId.equals(exerciseId)))
        .get();

    final bySession = <int, List<WorkoutSet>>{};
    final sessionDates = <int, String>{};
    for (final row in rows) {
      final session = row.readTable(_db.workoutSessions);
      final set = row.readTable(_db.workoutSets);
      bySession.putIfAbsent(session.id, () => []).add(set);
      sessionDates[session.id] = session.sessionDate;
    }

    final summaries = bySession.entries.map((entry) {
      final sets = entry.value;
      final volume = calculateVolume(
        sets.map(
          (s) => LoggedSet(
            setType: SetType.fromDb(s.setType),
            reps: s.reps,
            weightKg: s.weightKg,
          ),
        ),
      );

      double? best1Rm;
      for (final s in sets) {
        final reps = s.reps;
        final weight = s.weightKg;
        if (reps != null && reps > 0 && weight != null) {
          final estimate = estimateOneRepMaxEpley(weight, reps);
          if (best1Rm == null || estimate > best1Rm) best1Rm = estimate;
        }
      }

      return ExerciseSessionSummary(
        sessionId: entry.key,
        sessionDate: sessionDates[entry.key]!,
        volume: volume,
        bestEstimatedOneRepMax: best1Rm,
      );
    }).toList();

    summaries.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    return summaries;
  }
}
