import 'package:drift/drift.dart';

import 'exercises.dart';

/// Rutina: una plantilla reutilizable, no un registro. `WorkoutSession` la
/// referencia pero no copia nada de ella: lo que de verdad hiciste vive en
/// `WorkoutSets`, así que editar la rutina no reescribe sesiones pasadas.
class Routines extends Table {
  @override
  String get tableName => 'routine';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().named('name')();
  TextColumn get description => text().named('description').nullable()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();
}

class RoutineExercises extends Table {
  @override
  String get tableName => 'routine_exercise';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get routineId => integer()
      .named('routine_id')
      .references(Routines, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().named('exercise_id').references(Exercises, #id)();

  IntColumn get position => integer().named('position')();
  IntColumn get targetSets => integer().named('target_sets').nullable()();
  IntColumn get targetRepsMin =>
      integer().named('target_reps_min').nullable()();
  IntColumn get targetRepsMax =>
      integer().named('target_reps_max').nullable()();
  RealColumn get targetRpe => real().named('target_rpe').nullable()();
  IntColumn get restSeconds => integer().named('rest_seconds').nullable()();

  /// Mismo número = mismo superset.
  IntColumn get supersetGroup =>
      integer().named('superset_group').nullable()();
  TextColumn get notes => text().named('notes').nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {routineId, position},
      ];
}

/// Una sesión de entrenamiento. `endedAt == NULL` significa "en curso": no
/// hay una columna `isActive` redundante que pueda desincronizarse. La
/// regla de "solo una sesión activa a la vez" se impone en el repositorio,
/// no aquí (docs/01-modelo-de-datos.md § workout_session).
class WorkoutSessions extends Table {
  @override
  String get tableName => 'workout_session';

  IntColumn get id => integer().autoIncrement()();

  /// NULL = sesión libre, sin rutina.
  IntColumn get routineId =>
      integer().named('routine_id').nullable().references(Routines, #id)();

  /// 'YYYY-MM-DD' local.
  TextColumn get sessionDate => text().named('session_date')();
  IntColumn get startedAt => integer().named('started_at')();

  /// NULL mientras la sesión está en curso.
  IntColumn get endedAt => integer().named('ended_at').nullable()();
  IntColumn get tzOffsetMinutes =>
      integer().named('tz_offset_minutes')();
  RealColumn get bodyweightKg => real().named('bodyweight_kg').nullable()();
  TextColumn get notes => text().named('notes').nullable()();

  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
}

/// Una serie ejecutada. `setType` es lo que hace correcto el cálculo de
/// volumen: `warmup` NO cuenta; `normal`, `drop` y `failure` SÍ cuentan
/// (invariante #9 de CLAUDE.md, docs/01-modelo-de-datos.md).
class WorkoutSets extends Table {
  @override
  String get tableName => 'workout_set';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get sessionId => integer()
      .named('session_id')
      .references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().named('exercise_id').references(Exercises, #id)();

  IntColumn get position => integer().named('position')();

  /// 'normal' | 'warmup' | 'drop' | 'failure'.
  TextColumn get setType => text()
      .named('set_type')
      .withDefault(const Constant('normal'))();

  IntColumn get reps => integer().named('reps').nullable()();
  RealColumn get weightKg => real().named('weight_kg').nullable()();

  /// Plancha, cardio.
  IntColumn get durationSeconds =>
      integer().named('duration_seconds').nullable()();
  RealColumn get distanceM => real().named('distance_m').nullable()();
  RealColumn get rpe => real().named('rpe').nullable()();
  IntColumn get supersetGroup =>
      integer().named('superset_group').nullable()();
  TextColumn get notes => text().named('notes').nullable()();

  IntColumn get completedAt => integer().named('completed_at')();

  @override
  List<String> get customConstraints => [
        "CHECK (set_type IN ('normal', 'warmup', 'drop', 'failure'))",
        'CHECK (reps IS NULL OR reps > 0)',
        'CHECK (weight_kg IS NULL OR weight_kg >= 0)',
        'CHECK (rpe IS NULL OR (rpe >= 1 AND rpe <= 10))',
        'CHECK (reps IS NOT NULL OR duration_seconds IS NOT NULL OR '
            'distance_m IS NOT NULL)',
      ];
}
