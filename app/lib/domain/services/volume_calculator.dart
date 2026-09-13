import '../entities/logged_set.dart';

/// Volumen total: reps × peso de cada serie que cuenta, sumado. Las
/// series de calentamiento quedan fuera (invariante #9 de CLAUDE.md).
double calculateVolume(Iterable<LoggedSet> sets) {
  return sets
      .where((s) => s.setType.countsTowardVolume)
      .fold(0.0, (sum, s) => sum + s.volume);
}
