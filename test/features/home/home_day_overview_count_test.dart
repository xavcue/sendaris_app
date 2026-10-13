import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/home/domain/models/home_activity_area.dart';
import 'package:sendaris/features/home/domain/models/home_day_overview.dart';

void main() {
  group('HomeDayOverview - conteos diarios', () {
    test('expone el conteo correspondiente a cada área visible', () {
      final overview = HomeDayOverview(
        date: DateTime(2026, 10, 12, 23, 30),
        areas: const {
          HomeActivityArea.behavior,
          HomeActivityArea.sleep,
          HomeActivityArea.feeding,
        },
        counts: const {
          HomeActivityArea.behavior: 3,
          HomeActivityArea.sleep: 2,
          HomeActivityArea.feeding: 4,
        },
      );

      expect(overview.date, DateTime(2026, 10, 12));

      expect(overview.countFor(HomeActivityArea.behavior), 3);

      expect(overview.countFor(HomeActivityArea.sleep), 2);

      expect(overview.countFor(HomeActivityArea.feeding), 4);

      expect(overview.countFor(HomeActivityArea.socialInteraction), 0);
    });

    test('mantiene el orden funcional de las áreas', () {
      final overview = HomeDayOverview(
        date: DateTime(2026, 10, 12),
        areas: const {
          HomeActivityArea.routines,
          HomeActivityArea.feeding,
          HomeActivityArea.behavior,
        },
        counts: const {
          HomeActivityArea.routines: 2,
          HomeActivityArea.feeding: 1,
          HomeActivityArea.behavior: 5,
        },
      );

      expect(overview.orderedAreas, const [
        HomeActivityArea.behavior,
        HomeActivityArea.feeding,
        HomeActivityArea.routines,
      ]);
    });

    test(
      'conserva compatibilidad cuando un área no recibe conteo explícito',
      () {
        final overview = HomeDayOverview(
          date: DateTime(2026, 10, 12),
          areas: const {HomeActivityArea.behavior, HomeActivityArea.sleep},
        );

        expect(overview.countFor(HomeActivityArea.behavior), 1);

        expect(overview.countFor(HomeActivityArea.sleep), 1);
      },
    );

    test('rechaza conteos inválidos para un área visible', () {
      expect(
        () => HomeDayOverview(
          date: DateTime(2026, 10, 12),
          areas: const {HomeActivityArea.behavior},
          counts: const {HomeActivityArea.behavior: 0},
        ),
        throwsArgumentError,
      );
    });
  });
}
