import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/router/app_routes.dart';

void main() {
  group('AppRoutes', () {
    test(
      'define únicamente las cuatro secciones principales de navegación',
      () {
        expect(AppRoutes.mainDestinations, [
          AppRoutes.home,
          AppRoutes.events,
          AppRoutes.routines,
          AppRoutes.indicators,
        ]);

        expect(AppRoutes.mainDestinations, hasLength(4));
      },
    );

    test('define Login como ruta pública independiente', () {
      expect(AppRoutes.login, '/login');

      expect(AppRoutes.mainDestinations, isNot(contains(AppRoutes.login)));
    });

    test('los seis tipos de evento pertenecen al módulo Eventos', () {
      expect(AppRoutes.eventManagementRoutes, [
        AppRoutes.behavior,
        AppRoutes.sleep,
        AppRoutes.feeding,
        AppRoutes.socialInteraction,
        AppRoutes.dysregulation,
        AppRoutes.atypicalSituation,
      ]);

      expect(AppRoutes.eventManagementRoutes, hasLength(6));

      expect(
        AppRoutes.eventManagementRoutes.every(
          (route) => route.startsWith('${AppRoutes.events}/'),
        ),
        isTrue,
      );
    });

    test(
      'cada tipo de evento dispone de una ruta de creación dentro de Eventos',
      () {
        expect(AppRoutes.eventCreationRoutes, [
          AppRoutes.behaviorNew,
          AppRoutes.sleepNew,
          AppRoutes.feedingNew,
          AppRoutes.socialInteractionNew,
          AppRoutes.dysregulationNew,
          AppRoutes.atypicalSituationNew,
        ]);

        expect(AppRoutes.eventCreationRoutes, hasLength(6));

        expect(
          AppRoutes.eventCreationRoutes.every(
            (route) =>
                route.startsWith('${AppRoutes.events}/') &&
                route.endsWith('/new'),
          ),
          isTrue,
        );
      },
    );

    test(
      'cada tipo de evento conserva rutas canónicas de detalle y edición',
      () {
        const detailRoutes = [
          AppRoutes.behaviorDetail,
          AppRoutes.sleepDetail,
          AppRoutes.feedingDetail,
          AppRoutes.socialInteractionDetail,
          AppRoutes.dysregulationDetail,
          AppRoutes.atypicalSituationDetail,
        ];

        const editRoutes = [
          AppRoutes.behaviorEdit,
          AppRoutes.sleepEdit,
          AppRoutes.feedingEdit,
          AppRoutes.socialInteractionEdit,
          AppRoutes.dysregulationEdit,
          AppRoutes.atypicalSituationEdit,
        ];

        expect(detailRoutes, [
          '/events/behavior/detail',
          '/events/sleep/detail',
          '/events/feeding/detail',
          '/events/social-interaction/detail',
          '/events/dysregulation/detail',
          '/events/atypical-situation/detail',
        ]);

        expect(editRoutes, [
          '/events/behavior/edit',
          '/events/sleep/edit',
          '/events/feeding/edit',
          '/events/social-interaction/edit',
          '/events/dysregulation/edit',
          '/events/atypical-situation/edit',
        ]);

        expect(
          detailRoutes.every(
            (route) =>
                route.startsWith('${AppRoutes.events}/') &&
                route.endsWith('/detail'),
          ),
          isTrue,
        );

        expect(
          editRoutes.every(
            (route) =>
                route.startsWith('${AppRoutes.events}/') &&
                route.endsWith('/edit'),
          ),
          isTrue,
        );
      },
    );

    test('Rutinas conserva un namespace independiente de Eventos', () {
      expect(AppRoutes.routines, '/routines');

      expect(AppRoutes.routineManagement, '/routines/manage');

      expect(AppRoutes.routineDetail, '/routines/detail');

      expect(AppRoutes.routineNew, '/routines/new');

      expect(AppRoutes.routineEdit, '/routines/edit');

      const routineRoutes = [
        AppRoutes.routines,
        AppRoutes.routineManagement,
        AppRoutes.routineDetail,
        AppRoutes.routineNew,
        AppRoutes.routineEdit,
        AppRoutes.routineStatus,
        AppRoutes.routineStatusNew,
        AppRoutes.routineStatusDetail,
        AppRoutes.routineStatusEdit,
      ];

      expect(
        routineRoutes.every((route) => route.startsWith(AppRoutes.routines)),
        isTrue,
      );
    });

    test('Estado de rutina dispone de gestión creación detalle y edición', () {
      expect(AppRoutes.routineStatus, '/routines/status');

      expect(AppRoutes.routineStatusNew, '/routines/status/new');

      expect(AppRoutes.routineStatusDetail, '/routines/status/detail');

      expect(AppRoutes.routineStatusEdit, '/routines/status/edit');

      const statusRoutes = [
        AppRoutes.routineStatus,
        AppRoutes.routineStatusNew,
        AppRoutes.routineStatusDetail,
        AppRoutes.routineStatusEdit,
      ];

      expect(
        statusRoutes.every(
          (route) => route.startsWith(AppRoutes.routineStatus),
        ),
        isTrue,
      );
    });

    test('Ajustes queda fuera de los destinos del bottom navigation', () {
      expect(AppRoutes.settings, '/settings');

      expect(AppRoutes.mainDestinations, isNot(contains(AppRoutes.settings)));
    });

    test('todas las rutas declaradas en la arquitectura actual son únicas', () {
      const routes = [
        AppRoutes.home,
        AppRoutes.login,
        AppRoutes.events,
        AppRoutes.behavior,
        AppRoutes.behaviorNew,
        AppRoutes.behaviorDetail,
        AppRoutes.behaviorEdit,
        AppRoutes.sleep,
        AppRoutes.sleepNew,
        AppRoutes.sleepDetail,
        AppRoutes.sleepEdit,
        AppRoutes.feeding,
        AppRoutes.feedingNew,
        AppRoutes.feedingDetail,
        AppRoutes.feedingEdit,
        AppRoutes.socialInteraction,
        AppRoutes.socialInteractionNew,
        AppRoutes.socialInteractionDetail,
        AppRoutes.socialInteractionEdit,
        AppRoutes.dysregulation,
        AppRoutes.dysregulationNew,
        AppRoutes.dysregulationDetail,
        AppRoutes.dysregulationEdit,
        AppRoutes.atypicalSituation,
        AppRoutes.atypicalSituationNew,
        AppRoutes.atypicalSituationDetail,
        AppRoutes.atypicalSituationEdit,
        AppRoutes.routines,
        AppRoutes.routineManagement,
        AppRoutes.routineDetail,
        AppRoutes.routineNew,
        AppRoutes.routineEdit,
        AppRoutes.routineStatus,
        AppRoutes.routineStatusNew,
        AppRoutes.routineStatusDetail,
        AppRoutes.routineStatusEdit,
        AppRoutes.indicators,
        AppRoutes.settings,
      ];

      expect(routes.toSet(), hasLength(routes.length));
    });
  });
}
