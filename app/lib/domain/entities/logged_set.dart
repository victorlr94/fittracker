import 'set_type.dart';

/// Una serie reducida a lo que hace falta para calcular volumen y 1RM.
/// A propósito NO es la fila de Drift (ADR-006, docs/00-decisiones.md):
/// `domain/` no depende de la capa de datos, así que estas pruebas corren
/// en milisegundos y sin abrir una base de datos.
class LoggedSet {
  const LoggedSet({
    required this.setType,
    this.reps,
    this.weightKg,
  });

  final SetType setType;
  final int? reps;
  final double? weightKg;

  /// reps × peso. Cero si falta cualquiera de los dos (series de tiempo
  /// o distancia, sin reps ni peso, no aportan volumen de fuerza).
  double get volume => (reps ?? 0) * (weightKg ?? 0);
}
