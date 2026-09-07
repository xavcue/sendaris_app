import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';

void main() {
  group('AtypicalSituationCategory', () {
    test('expone códigos persistibles estables', () {
      expect(
        AtypicalSituationCategory.environmentChange.code,
        'cambio_entorno',
      );

      expect(
        AtypicalSituationCategory.transitionOrTransfer.code,
        'transicion_traslado',
      );

      expect(
        AtypicalSituationCategory.unexpectedEvent.code,
        'evento_inesperado',
      );

      expect(
        AtypicalSituationCategory.unusualActivity.code,
        'actividad_no_habitual',
      );

      expect(AtypicalSituationCategory.scheduleChange.code, 'cambio_horario');

      expect(
        AtypicalSituationCategory.externalInterruption.code,
        'interrupcion_externa',
      );

      expect(AtypicalSituationCategory.other.code, 'otro');
    });

    test('recupera una categoría desde su código', () {
      final category = AtypicalSituationCategory.fromCode('evento_inesperado');

      expect(category, AtypicalSituationCategory.unexpectedEvent);
    });

    test('rechaza una categoría desconocida', () {
      expect(
        () => AtypicalSituationCategory.fromCode('categoria_invalida'),
        throwsFormatException,
      );
    });
  });
}
