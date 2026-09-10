import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_duration_calculator.dart';

void main() {
  group('SleepDurationCalculator', () {
    test('calcula duración dentro del mismo día', () {
      final duration = SleepDurationCalculator.calculate(
        startTime: '08:15',
        endTime: '09:45',
      );

      expect(duration, 90);
    });

    test('calcula duración cuando el sueño cruza medianoche', () {
      final duration = SleepDurationCalculator.calculate(
        startTime: '22:00',
        endTime: '06:00',
      );

      expect(duration, 480);
    });

    test('calcula correctamente un periodo corto que cruza medianoche', () {
      final duration = SleepDurationCalculator.calculate(
        startTime: '23:30',
        endTime: '00:30',
      );

      expect(duration, 60);
    });

    test('rechaza horas iguales', () {
      expect(
        () => SleepDurationCalculator.calculate(
          startTime: '22:00',
          endTime: '22:00',
        ),
        throwsArgumentError,
      );
    });

    test('rechaza una hora inválida', () {
      expect(
        () => SleepDurationCalculator.calculate(
          startTime: '25:00',
          endTime: '06:00',
        ),
        throwsArgumentError,
      );
    });
  });
}
