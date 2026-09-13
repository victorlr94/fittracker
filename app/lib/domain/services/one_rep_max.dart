/// Estimadores de 1RM (una repetición máxima) a partir de una serie de
/// más de una repetición. Ninguna fórmula es exacta; ambas se degradan
/// mucho arriba de ~10-12 reps — son una referencia de progresión, no una
/// medición (docs/02-roadmap.md, Fase 1 § qué se prueba).
library;

/// Epley: peso × (1 + reps/30). La más citada; algo optimista a reps altas.
double estimateOneRepMaxEpley(double weightKg, int reps) {
  _checkReps(reps);
  if (reps == 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

/// Brzycki: peso × 36 / (37 - reps). Diverge cerca de 37 reps; se acota
/// explícitamente en vez de devolver un número sin sentido.
double estimateOneRepMaxBrzycki(double weightKg, int reps) {
  _checkReps(reps);
  if (reps == 1) return weightKg;
  if (reps >= 37) {
    throw ArgumentError.value(
      reps,
      'reps',
      'la fórmula de Brzycki no es válida a partir de 37 reps',
    );
  }
  return weightKg * 36 / (37 - reps);
}

void _checkReps(int reps) {
  if (reps <= 0) {
    throw ArgumentError.value(reps, 'reps', 'debe ser mayor que cero');
  }
}
