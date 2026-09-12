import 'package:fit_tracker/domain/services/one_rep_max.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimateOneRepMaxEpley', () {
    test('con 1 rep devuelve el peso tal cual (borde exacto)', () {
      expect(estimateOneRepMaxEpley(100, 1), 100);
    });

    test('8 reps a 80 kg: 80 * (1 + 8/30)', () {
      expect(estimateOneRepMaxEpley(80, 8), closeTo(101.33, 0.01));
    });

    test('rechaza reps <= 0', () {
      expect(() => estimateOneRepMaxEpley(80, 0), throwsArgumentError);
      expect(() => estimateOneRepMaxEpley(80, -1), throwsArgumentError);
    });
  });

  group('estimateOneRepMaxBrzycki', () {
    test('con 1 rep devuelve el peso tal cual (borde exacto)', () {
      expect(estimateOneRepMaxBrzycki(100, 1), 100);
    });

    test('8 reps a 80 kg: 80 * 36 / (37 - 8)', () {
      expect(estimateOneRepMaxBrzycki(80, 8), closeTo(99.31, 0.01));
    });

    test('rechaza reps <= 0', () {
      expect(() => estimateOneRepMaxBrzycki(80, 0), throwsArgumentError);
    });

    test('rechaza reps donde la fórmula diverge (>= 37)', () {
      expect(() => estimateOneRepMaxBrzycki(80, 37), throwsArgumentError);
      expect(() => estimateOneRepMaxBrzycki(80, 50), throwsArgumentError);
    });

    test('acepta el borde justo antes de divergir', () {
      expect(estimateOneRepMaxBrzycki(80, 36), closeTo(2880, 0.01));
    });
  });
}
