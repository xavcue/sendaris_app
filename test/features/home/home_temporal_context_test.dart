import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/home/domain/services/home_temporal_context.dart';

void main() {
  group('HomeTemporalContext', () {
    test('usa Buenos días desde las 05:00 hasta las 11:59', () {
      expect(
        HomeTemporalContext.greetingFor(DateTime(2026, 10, 12, 5)),
        'Buenos días',
      );

      expect(
        HomeTemporalContext.greetingFor(DateTime(2026, 10, 12, 11, 59, 59)),
        'Buenos días',
      );
    });

    test('usa Buenas tardes desde las 12:00 hasta las 18:59', () {
      expect(
        HomeTemporalContext.greetingFor(DateTime(2026, 10, 12, 12)),
        'Buenas tardes',
      );

      expect(
        HomeTemporalContext.greetingFor(DateTime(2026, 10, 12, 18, 59, 59)),
        'Buenas tardes',
      );
    });

    test('usa Buenas noches desde las 19:00 hasta las 04:59', () {
      expect(
        HomeTemporalContext.greetingFor(DateTime(2026, 10, 12, 19)),
        'Buenas noches',
      );

      expect(
        HomeTemporalContext.greetingFor(DateTime(2026, 10, 12, 23, 59, 59)),
        'Buenas noches',
      );

      expect(
        HomeTemporalContext.greetingFor(DateTime(2026, 10, 13, 0)),
        'Buenas noches',
      );

      expect(
        HomeTemporalContext.greetingFor(DateTime(2026, 10, 13, 4, 59, 59)),
        'Buenas noches',
      );
    });

    test('calcula las transiciones temporales de la mañana y tarde', () {
      expect(
        HomeTemporalContext.nextTemporalBoundaryAfter(
          DateTime(2026, 10, 12, 4, 59, 30),
        ),
        DateTime(2026, 10, 12, 5),
      );

      expect(
        HomeTemporalContext.nextTemporalBoundaryAfter(
          DateTime(2026, 10, 12, 11, 59, 30),
        ),
        DateTime(2026, 10, 12, 12),
      );

      expect(
        HomeTemporalContext.nextTemporalBoundaryAfter(
          DateTime(2026, 10, 12, 18, 59, 30),
        ),
        DateTime(2026, 10, 12, 19),
      );
    });

    test('prioriza medianoche para actualizar también la fecha local', () {
      expect(
        HomeTemporalContext.nextTemporalBoundaryAfter(
          DateTime(2026, 10, 12, 23, 30),
        ),
        DateTime(2026, 10, 13),
      );
    });

    test('después de medianoche programa las 05:00', () {
      expect(
        HomeTemporalContext.nextTemporalBoundaryAfter(
          DateTime(2026, 10, 13, 0, 30),
        ),
        DateTime(2026, 10, 13, 5),
      );
    });

    test('extrae la fecha local sin conservar la hora', () {
      expect(
        HomeTemporalContext.localDateFor(DateTime(2026, 10, 12, 18, 35, 22)),
        DateTime(2026, 10, 12),
      );
    });
  });
}
