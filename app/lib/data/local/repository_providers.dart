import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/app_database.dart';
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

/// Lista de rutinas, reactiva vía Riverpod (no estado local cacheado en
/// cada pantalla): crear o borrar una rutina en la pestaña Rutinas debe
/// verse de inmediato en el selector de la pestaña Sesión, aunque esa
/// pestaña ya esté construida y no se reconstruya sola al cambiar de tab.
/// Quien mute rutinas debe invalidar este provider (`ref.invalidate`).
///
/// A mano, sin `@riverpod`: el generador de código falla
/// (`InvalidTypeException`) al intentar serializar `List<Routine>` como
/// tipo de un provider — `Routine` es una clase que Drift genera en un
/// archivo `part`, y esa combinación con riverpod_generator no funciona.
/// Un `FutureProvider` escrito a mano es un patrón igual de válido en
/// Riverpod y evita el problema por completo.
final routinesProvider = FutureProvider.autoDispose<List<Routine>>((ref) {
  return ref.watch(workoutRepositoryProvider).listRoutines();
});
