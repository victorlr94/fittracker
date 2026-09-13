/// Errores de negocio del módulo de entrenamientos. Se manejan como
/// excepciones tipadas (no genéricas), para que la UI decida qué mostrar
/// sin tener que inspeccionar mensajes de texto.
sealed class WorkoutException implements Exception {
  const WorkoutException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Ya hay una sesión sin terminar (`endedAt IS NULL`). Solo puede haber
/// una a la vez — ver docs/01-modelo-de-datos.md § workout_session.
class ActiveSessionAlreadyExistsException extends WorkoutException {
  const ActiveSessionAlreadyExistsException()
      : super('Ya hay una sesión de entrenamiento en curso.');
}
