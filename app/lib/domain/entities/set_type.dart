/// Los cuatro tipos de serie del esquema (`workout_set.set_type`, ver
/// docs/01-modelo-de-datos.md). Vive en `domain/` porque la regla de qué
/// cuenta para el volumen (invariante #9 de CLAUDE.md) es lógica de
/// negocio, no un detalle de la base de datos.
enum SetType {
  normal,
  warmup,
  drop,
  failure;

  static SetType fromDb(String value) => switch (value) {
        'normal' => SetType.normal,
        'warmup' => SetType.warmup,
        'drop' => SetType.drop,
        'failure' => SetType.failure,
        _ => throw ArgumentError.value(value, 'value', 'set_type desconocido'),
      };

  String toDb() => name;

  /// Si esta serie cuenta para el volumen de la sesión. Solo el
  /// calentamiento queda fuera; `drop` y `failure` sí son trabajo real.
  bool get countsTowardVolume => this != SetType.warmup;
}
