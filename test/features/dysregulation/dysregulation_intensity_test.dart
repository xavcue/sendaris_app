import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';

void main() {
  group('DysregulationIntensity', () {
    test('define únicamente las tres intensidades descriptivas', () {
      expect(DysregulationIntensity.values, hasLength(3));

      expect(DysregulationIntensity.values.map((value) => value.code), [
        'baja',
        'media',
        'alta',
      ]);

      expect(DysregulationIntensity.values.map((value) => value.label), [
        'Baja',
        'Media',
        'Alta',
      ]);
    });

    test('recupera una intensidad válida desde su código', () {
      expect(
        DysregulationIntensity.fromCode('baja'),
        DysregulationIntensity.low,
      );

      expect(
        DysregulationIntensity.fromCode('media'),
        DysregulationIntensity.medium,
      );

      expect(
        DysregulationIntensity.fromCode('alta'),
        DysregulationIntensity.high,
      );
    });

    test('rechaza una intensidad fuera del catálogo', () {
      expect(
        () => DysregulationIntensity.fromCode('severa'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
