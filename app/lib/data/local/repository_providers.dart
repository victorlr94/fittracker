import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database_provider.dart';
import 'exercise_repository.dart';
import 'workout_repository.dart';

part 'repository_providers.g.dart';

@Riverpod(keepAlive: true)
ExerciseRepository exerciseRepository(Ref ref) {
  return ExerciseRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
WorkoutRepository workoutRepository(Ref ref) {
  return WorkoutRepository(ref.watch(appDatabaseProvider));
}
