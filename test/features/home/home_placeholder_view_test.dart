import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/home/domain/models/home_activity_area.dart';
import 'package:sendaris/features/home/domain/models/home_day_overview.dart';
import 'package:sendaris/features/home/domain/repositories/home_overview_repository.dart';
import 'package:sendaris/features/home/domain/services/home_clock.dart';
import 'package:sendaris/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:sendaris/features/home/presentation/views/home_placeholder_view.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_deletion_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  testWidgets(
    'home presenta saludo, fecha y propósito breve sin exponer identificadores',
    (tester) async {
      final repository = _FakeTrackingRepository(
        recoveredProfiles: [
          AnonymousTrackingProfile(
            anonymousId: 'ID-INTERNO-NO-DEBE-MOSTRARSE',
            createdAt: DateTime(2026, 9, 7),
            trackingNumber: 1,
          ),
        ],
      );

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await _pumpHome(
        tester,
        viewModel,
        currentDateTime: DateTime(2026, 10, 12, 23, 41),
      );

      expect(find.text('Buenas noches'), findsOneWidget);

      expect(find.text('Hoy, lunes 12 de octubre'), findsOneWidget);

      expect(
        find.text(
          'Organiza eventos, rutinas e indicadores '
          'descriptivos de forma privada.',
        ),
        findsOneWidget,
      );

      expect(find.text('Seguimiento actual'), findsOneWidget);

      expect(find.text('Seguimiento 1'), findsOneWidget);

      expect(find.text('Activo desde el 07 sep 2026'), findsOneWidget);

      expect(find.textContaining('ID-INTERNO'), findsNothing);

      expect(find.text('Perfil activo'), findsNothing);

      expect(find.text('Perfil listo'), findsNothing);

      expect(find.text('Seguimiento inactivo'), findsNothing);
    },
  );

  testWidgets(
    'home elimina resumen anterior, recarga manual y accesos redundantes',
    (tester) async {
      final repository = _FakeTrackingRepository(
        recoveredProfiles: [
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-actual',
            createdAt: DateTime(2026, 9, 7),
            trackingNumber: 1,
          ),
        ],
      );

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await _pumpHome(tester, viewModel, largeViewport: true);

      expect(find.text('Resumen de hoy'), findsNothing);

      expect(find.text('Acciones rápidas'), findsNothing);

      expect(find.byKey(const Key('home-routines-action')), findsNothing);

      expect(find.byKey(const Key('home-frequency-action')), findsNothing);

      expect(find.byKey(const Key('home-duration-action')), findsNothing);

      expect(
        find.byKey(const Key('home-routine-compliance-action')),
        findsNothing,
      );

      expect(find.byKey(const Key('home-new-register-action')), findsNothing);

      expect(find.byKey(const Key('home-history-action')), findsNothing);

      expect(
        find.byKey(const Key('home-refresh-overview-button')),
        findsNothing,
      );

      expect(find.byKey(const Key('home-overview-last-updated')), findsNothing);

      expect(find.text('Frecuencias descriptivas'), findsNothing);

      expect(find.text('Duraciones y promedios'), findsNothing);

      expect(find.text('Cumplimiento de rutinas'), findsNothing);

      expect(find.text('Eventos recientes'), findsNothing);

      expect(find.text('Rutinas recientes'), findsNothing);

      expect(find.text('Hoy en el seguimiento'), findsOneWidget);
    },
  );

  testWidgets('panorama muestra únicamente las áreas registradas del día', (
    tester,
  ) async {
    final repository = _FakeTrackingRepository(
      recoveredProfiles: [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-actual',
          createdAt: DateTime(2026, 9, 7),
          trackingNumber: 1,
        ),
      ],
    );

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    addTearDown(viewModel.dispose);

    await _pumpHome(
      tester,
      viewModel,
      largeViewport: true,
      overviewAreas: const {
        HomeActivityArea.behavior,
        HomeActivityArea.sleep,
        HomeActivityArea.feeding,
        HomeActivityArea.routines,
      },
    );

    expect(find.text('Hoy en el seguimiento'), findsOneWidget);

    expect(find.text('Áreas registradas hoy.'), findsOneWidget);

    expect(find.text('Conducta'), findsOneWidget);

    expect(find.text('Sueño'), findsOneWidget);

    expect(find.text('Alimentación'), findsOneWidget);

    expect(find.text('Rutinas'), findsOneWidget);

    expect(find.text('Interacción social'), findsNothing);

    expect(find.text('Desregulación'), findsNothing);

    expect(find.text('Otra situación'), findsNothing);

    expect(
      find.byKey(const Key('home-overview-area-conducta')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('home-overview-area-sueno')), findsOneWidget);

    expect(
      find.byKey(const Key('home-overview-area-alimentacion')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('home-overview-area-rutinas')), findsOneWidget);

    expect(find.textContaining('eventos hoy'), findsNothing);

    expect(find.textContaining('rutinas hoy'), findsNothing);
  });

  testWidgets(
    'panorama vacío utiliza un mensaje neutral sin señalar áreas pendientes',
    (tester) async {
      final repository = _FakeTrackingRepository(
        recoveredProfiles: [
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-actual',
            createdAt: DateTime(2026, 9, 7),
            trackingNumber: 1,
          ),
        ],
      );

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await _pumpHome(tester, viewModel);

      expect(
        find.byKey(const Key('home-overview-empty-state')),
        findsOneWidget,
      );

      expect(
        find.text(
          'El panorama del día aparecerá aquí '
          'conforme registres información.',
        ),
        findsOneWidget,
      );

      expect(find.textContaining('pendiente'), findsNothing);

      expect(find.textContaining('incompleto'), findsNothing);

      expect(find.textContaining('faltan'), findsNothing);
    },
  );

  testWidgets(
    'selector muestra varios seguimientos sin mostrar sus identificadores',
    (tester) async {
      final repository = _FakeTrackingRepository(
        recoveredProfiles: [
          AnonymousTrackingProfile(
            anonymousId: 'IDENTIFICADOR-UNO',
            createdAt: DateTime(2026, 9, 3),
            trackingNumber: 1,
          ),
          AnonymousTrackingProfile(
            anonymousId: 'IDENTIFICADOR-DOS',
            createdAt: DateTime(2026, 9, 18),
            trackingNumber: 2,
          ),
        ],
      );

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await _pumpHome(tester, viewModel);

      await tester.tap(find.byKey(const Key('home-tracking-selector-card')));

      await tester.pumpAndSettle();

      expect(find.text('Tus seguimientos'), findsOneWidget);

      expect(find.text('Seguimiento 1'), findsWidgets);

      expect(find.text('Seguimiento 2'), findsOneWidget);

      expect(find.text('Creado el 03 sep 2026'), findsOneWidget);

      expect(find.text('Creado el 18 sep 2026'), findsOneWidget);

      expect(
        find.text(
          'Cada seguimiento es anónimo. '
          'No se solicitan nombres ni datos personales.',
        ),
        findsOneWidget,
      );

      expect(find.textContaining('IDENTIFICADOR-UNO'), findsNothing);

      expect(find.textContaining('IDENTIFICADOR-DOS'), findsNothing);

      expect(find.byKey(const Key('tracking-create-button')), findsOneWidget);

      expect(find.byKey(const Key('tracking-manage-button')), findsOneWidget);
    },
  );

  testWidgets('permite cambiar al segundo seguimiento desde el selector', (
    tester,
  ) async {
    final first = AnonymousTrackingProfile(
      anonymousId: 'seguimiento-uno-interno',
      createdAt: DateTime(2026, 9, 3),
      trackingNumber: 1,
    );

    final second = AnonymousTrackingProfile(
      anonymousId: 'seguimiento-dos-interno',
      createdAt: DateTime(2026, 9, 18),
      trackingNumber: 2,
    );

    final repository = _FakeTrackingRepository(
      recoveredProfiles: [first, second],
    );

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    addTearDown(viewModel.dispose);

    await _pumpHome(tester, viewModel);

    expect(viewModel.activeAnonymousId, 'seguimiento-uno-interno');

    await tester.tap(find.byKey(const Key('home-tracking-selector-card')));

    await tester.pumpAndSettle();

    final secondOption = find.byKey(const Key('tracking-option-2'));

    await tester.ensureVisible(secondOption);

    await tester.pumpAndSettle();

    await tester.tap(secondOption);

    await tester.pumpAndSettle();

    expect(viewModel.activeAnonymousId, 'seguimiento-dos-interno');

    expect(find.text('Seguimiento 2'), findsWidgets);

    expect(find.textContaining('seguimiento-dos-interno'), findsNothing);

    expect(find.text('Seguimiento 2 seleccionado.'), findsOneWidget);
  });

  testWidgets('permite crear un nuevo seguimiento desde el selector', (
    tester,
  ) async {
    final repository = _FakeTrackingRepository(
      recoveredProfiles: [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-existente',
          createdAt: DateTime(2020, 1, 1),
          trackingNumber: 1,
        ),
      ],
    );

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    addTearDown(viewModel.dispose);

    await _pumpHome(tester, viewModel);

    await tester.tap(find.byKey(const Key('home-tracking-selector-card')));

    await tester.pumpAndSettle();

    final createButton = find.byKey(const Key('tracking-create-button'));

    await tester.ensureVisible(createButton);

    await tester.pumpAndSettle();

    await tester.tap(createButton);

    await tester.pumpAndSettle();

    expect(repository.persistedProfiles.length, 1);

    expect(viewModel.profiles.length, 2);

    expect(viewModel.activeAnonymousId, 'seguimiento-generado-interno');

    expect(viewModel.activeTrackingLabel, 'Seguimiento 2');

    expect(find.text('Seguimiento 2'), findsWidgets);

    expect(find.textContaining('seguimiento-generado-interno'), findsNothing);

    expect(find.text('Seguimiento 2 creado y seleccionado.'), findsOneWidget);
  });

  testWidgets(
    'botón atrás desde administrar vuelve a tus seguimientos antes de cerrar el selector',
    (tester) async {
      final repository = _FakeTrackingRepository(
        recoveredProfiles: [
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-uno-interno',
            createdAt: DateTime(2026, 9, 3),
            trackingNumber: 1,
          ),
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-dos-interno',
            createdAt: DateTime(2026, 9, 18),
            trackingNumber: 2,
          ),
        ],
      );

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await _pumpHome(tester, viewModel);

      await tester.tap(find.byKey(const Key('home-tracking-selector-card')));

      await tester.pumpAndSettle();

      final manageButton = find.byKey(const Key('tracking-manage-button'));

      await tester.ensureVisible(manageButton);

      await tester.pumpAndSettle();

      await tester.tap(manageButton);

      await tester.pumpAndSettle();

      expect(find.text('Administrar seguimientos'), findsOneWidget);

      expect(find.text('Cancelar'), findsOneWidget);

      expect(
        find.byKey(const Key('tracking-management-cancel-button')),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();

      await tester.pumpAndSettle();

      expect(find.text('Administrar seguimientos'), findsNothing);

      expect(find.text('Tus seguimientos'), findsOneWidget);

      expect(find.byKey(const Key('tracking-manage-button')), findsOneWidget);

      await tester.binding.handlePopRoute();

      await tester.pumpAndSettle();

      expect(find.text('Tus seguimientos'), findsNothing);

      expect(find.text('Hoy en el seguimiento'), findsOneWidget);
    },
  );

  testWidgets('permite administrar y eliminar definitivamente un seguimiento', (
    tester,
  ) async {
    final repository = _FakeTrackingRepository(
      recoveredProfiles: [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-uno-interno',
          createdAt: DateTime(2026, 9, 3),
          trackingNumber: 1,
        ),
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-dos-interno',
          createdAt: DateTime(2026, 9, 18),
          trackingNumber: 2,
        ),
      ],
    );

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    addTearDown(viewModel.dispose);

    await _pumpHome(tester, viewModel);

    await tester.tap(find.byKey(const Key('home-tracking-selector-card')));

    await tester.pumpAndSettle();

    final manageButton = find.byKey(const Key('tracking-manage-button'));

    await tester.ensureVisible(manageButton);

    await tester.pumpAndSettle();

    await tester.tap(manageButton);

    await tester.pumpAndSettle();

    expect(find.text('Administrar seguimientos'), findsOneWidget);

    expect(
      find.text(
        'La eliminación es permanente y también borra '
        'los registros y rutinas asociados.',
      ),
      findsOneWidget,
    );

    final secondOption = find.byKey(const Key('tracking-option-2'));

    await tester.ensureVisible(secondOption);

    await tester.pumpAndSettle();

    await tester.tap(secondOption);

    await tester.pumpAndSettle();

    expect(find.text('1 seleccionado'), findsOneWidget);

    final deleteButton = find.byKey(
      const Key('tracking-delete-selected-button'),
    );

    await tester.ensureVisible(deleteButton);

    await tester.pumpAndSettle();

    await tester.tap(deleteButton);

    await tester.pumpAndSettle();

    expect(find.text('¿Eliminar definitivamente?'), findsOneWidget);

    expect(
      find.text(
        'Se eliminarán este seguimiento y toda la '
        'información asociada, incluidos registros y rutinas. '
        'Esta acción no se puede deshacer.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('tracking-confirm-delete-button')));

    await tester.pumpAndSettle();

    expect(repository.deletedAnonymousIds, contains('seguimiento-dos-interno'));

    expect(viewModel.profiles.length, 1);

    expect(viewModel.activeTrackingLabel, 'Seguimiento 1');

    expect(find.text('Seguimiento eliminado definitivamente.'), findsOneWidget);

    expect(find.textContaining('seguimiento-dos-interno'), findsNothing);
  });

  testWidgets(
    'permite eliminar todos los seguimientos y limpia el contexto de Inicio',
    (tester) async {
      final repository = _FakeTrackingRepository(
        recoveredProfiles: [
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-uno-interno',
            createdAt: DateTime(2026, 9, 3),
            trackingNumber: 1,
          ),
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-dos-interno',
            createdAt: DateTime(2026, 9, 18),
            trackingNumber: 2,
          ),
        ],
      );

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await _pumpHome(tester, viewModel);

      await tester.tap(find.byKey(const Key('home-tracking-selector-card')));

      await tester.pumpAndSettle();

      final manageButton = find.byKey(const Key('tracking-manage-button'));

      await tester.ensureVisible(manageButton);

      await tester.pumpAndSettle();

      await tester.tap(manageButton);

      await tester.pumpAndSettle();

      final selectAllButton = find.byKey(
        const Key('tracking-select-all-button'),
      );

      await tester.ensureVisible(selectAllButton);

      await tester.pumpAndSettle();

      await tester.tap(selectAllButton);

      await tester.pumpAndSettle();

      expect(find.text('2 seleccionados'), findsOneWidget);

      final deleteButton = find.byKey(
        const Key('tracking-delete-selected-button'),
      );

      await tester.ensureVisible(deleteButton);

      await tester.pumpAndSettle();

      await tester.tap(deleteButton);

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tracking-confirm-delete-button')));

      await tester.pumpAndSettle();

      expect(repository.deletedAnonymousIds.length, 2);

      expect(viewModel.profiles, isEmpty);

      expect(viewModel.activeAnonymousId, isNull);

      expect(find.text('Seguimiento'), findsWidgets);

      expect(
        find.text('Toca para crear o seleccionar un seguimiento.'),
        findsOneWidget,
      );

      expect(
        find.text(
          'Selecciona o crea un seguimiento '
          'para comenzar a construir '
          'el panorama del día.',
        ),
        findsOneWidget,
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('sin seguimientos permite crear el primero desde el selector', (
    tester,
  ) async {
    final repository = _FakeTrackingRepository();

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    addTearDown(viewModel.dispose);

    await _pumpHome(tester, viewModel);

    expect(viewModel.profiles, isEmpty);

    expect(
      find.text('Toca para crear o seleccionar un seguimiento.'),
      findsOneWidget,
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byKey(const Key('home-tracking-selector-card')));

    await tester.pumpAndSettle();

    expect(find.text('Tus seguimientos'), findsOneWidget);

    final createButton = find.byKey(const Key('tracking-create-button'));

    await tester.ensureVisible(createButton);

    await tester.pumpAndSettle();

    await tester.tap(createButton);

    await tester.pumpAndSettle();

    expect(viewModel.profiles.length, 1);

    expect(viewModel.activeTrackingLabel, 'Seguimiento 1');

    expect(find.text('Seguimiento 1'), findsWidgets);

    expect(find.textContaining('seguimiento-generado-interno'), findsNothing);
  });

  testWidgets(
    'home comunica el alcance descriptivo sin sobrecargar la pantalla',
    (tester) async {
      final repository = _FakeTrackingRepository(
        recoveredProfiles: [
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-actual',
            createdAt: DateTime(2026, 9, 7),
            trackingNumber: 1,
          ),
        ],
      );

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await _pumpHome(tester, viewModel, largeViewport: true);

      expect(
        find.text(
          'Organiza eventos, rutinas e indicadores '
          'descriptivos de forma privada.',
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('home-descriptive-scope-footer')),
        findsOneWidget,
      );

      expect(
        find.text(
          'Sin diagnósticos, recomendaciones, '
          'predicciones ni interpretaciones clínicas.',
        ),
        findsOneWidget,
      );

      expect(find.text('Uso descriptivo y privado'), findsNothing);

      expect(
        find.byKey(const Key('home-descriptive-scope-message')),
        findsNothing,
      );

      expect(find.textContaining('severidad'), findsNothing);

      expect(find.textContaining('riesgo clínico'), findsNothing);

      expect(find.textContaining('adherencia'), findsNothing);

      expect(find.textContaining('calidad del cuidado'), findsNothing);

      expect(find.textContaining('mejoría'), findsNothing);

      expect(find.textContaining('empeoramiento'), findsNothing);
    },
  );
}

Future<void> _pumpHome(
  WidgetTester tester,
  TrackingViewModel trackingViewModel, {
  bool largeViewport = false,
  DateTime? currentDateTime,
  Set<HomeActivityArea> overviewAreas = const {},
}) async {
  if (largeViewport) {
    tester.view.physicalSize = const Size(1000, 1800);

    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  final homeViewModel = HomeViewModel(
    clock: _FakeHomeClock(currentDateTime ?? DateTime(2026, 10, 12, 10)),
    overviewRepository: _FakeHomeOverviewRepository(areas: overviewAreas),
    timerFactory: (_, _) => _NoopTimer(),
  );

  void synchronizeHomeTracking() {
    unawaited(
      homeViewModel.setActiveTracking(trackingViewModel.activeAnonymousId),
    );
  }

  trackingViewModel.addListener(synchronizeHomeTracking);

  addTearDown(() {
    trackingViewModel.removeListener(synchronizeHomeTracking);

    homeViewModel.dispose();
  });

  synchronizeHomeTracking();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TrackingViewModel>.value(
          value: trackingViewModel,
        ),
        ChangeNotifierProvider<HomeViewModel>.value(value: homeViewModel),
      ],
      child: MaterialApp(
        home: HomePlaceholderView(trackingViewModel: trackingViewModel),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

class _FakeTrackingRepository
    implements TrackingRepository, TrackingDeletionRepository {
  _FakeTrackingRepository({this.recoveredProfiles = const []});

  final List<AnonymousTrackingProfile> recoveredProfiles;

  final List<AnonymousTrackingProfile> persistedProfiles = [];

  final List<String> deletedAnonymousIds = [];

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {
    persistedProfiles.add(profile);
  }

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return List<AnonymousTrackingProfile>.unmodifiable(recoveredProfiles);
  }

  @override
  Future<void> deleteProfile(String anonymousId) async {
    deletedAnonymousIds.add(anonymousId);
  }
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() {
    return 'seguimiento-generado-interno';
  }
}

class _FakeHomeClock implements HomeClock {
  _FakeHomeClock(this.current);

  DateTime current;

  @override
  DateTime now() {
    return current;
  }
}

class _FakeHomeOverviewRepository implements HomeOverviewRepository {
  const _FakeHomeOverviewRepository({this.areas = const {}});

  final Set<HomeActivityArea> areas;

  @override
  Future<HomeDayOverview> recoverDayOverview({
    required String anonymousId,
    required DateTime localDate,
  }) async {
    return HomeDayOverview(date: localDate, areas: areas);
  }
}

class _NoopTimer implements Timer {
  bool _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 0;

  @override
  void cancel() {
    _isActive = false;
  }
}
