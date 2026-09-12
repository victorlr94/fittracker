import 'package:fit_tracker/domain/entities/logged_set.dart';
import 'package:fit_tracker/domain/entities/set_type.dart';
import 'package:fit_tracker/domain/services/volume_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateVolume', () {
    test('excluye las series de calentamiento', () {
      final sets = [
        const LoggedSet(setType: SetType.warmup, reps: 10, weightKg: 40),
        const LoggedSet(setType: SetType.normal, reps: 8, weightKg: 80),
        const LoggedSet(setType: SetType.normal, reps: 8, weightKg: 80),
      ];

      expect(calculateVolume(sets), 1280); // 8*80 + 8*80, sin el warmup
    });

    test('dropset y failure sí cuentan', () {
      final sets = [
        const LoggedSet(setType: SetType.normal, reps: 6, weightKg: 80),
        const LoggedSet(setType: SetType.drop, reps: 8, weightKg: 60),
        const LoggedSet(setType: SetType.failure, reps: 4, weightKg: 80),
      ];

      expect(calculateVolume(sets), 6 * 80 + 8 * 60 + 4 * 80);
    });

    test('una lista vacía da volumen cero', () {
      expect(calculateVolume(const []), 0);
    });

    test('series sin reps o peso (tiempo/distancia) no rompen el cálculo', () {
      final sets = [
        const LoggedSet(setType: SetType.normal, reps: null, weightKg: null),
        const LoggedSet(setType: SetType.normal, reps: 8, weightKg: 80),
      ];

      expect(calculateVolume(sets), 640);
    });

    test('todo calentamiento da volumen cero', () {
      final sets = [
        const LoggedSet(setType: SetType.warmup, reps: 10, weightKg: 40),
        const LoggedSet(setType: SetType.warmup, reps: 8, weightKg: 60),
      ];

      expect(calculateVolume(sets), 0);
    });
  });

  group('SetType.fromDb / toDb', () {
    test('ida y vuelta para los cuatro valores', () {
      for (final type in SetType.values) {
        expect(SetType.fromDb(type.toDb()), type);
      }
    });

    test('rechaza un valor desconocido', () {
      expect(() => SetType.fromDb('superserie'), throwsArgumentError);
    });
  });
}
