import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/home/presentation/views/home_placeholder_view.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_deletion_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  testWidgets(
    'home muestra el seguimiento actual sin exponer el identificador interno',
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

      await _pumpHome(tester, viewModel);

      expect(find.text('Resumen de hoy'), findsOneWidget);

      expect(find.text('Seguimiento actual'), findsOneWidget);

      expect(find.text('Seguimiento 1'), findsOneWidget);

      expect(
        find.text('Toca para cambiar, crear o administrar seguimientos.'),
        findsOneWidget,
      );

      expect(find.textContaining('ID-INTERNO'), findsNothing);

      expect(find.text('Perfil activo'), findsNothing);

      expect(find.text('Perfil listo'), findsNothing);

      expect(find.text('Seguimiento inactivo'), findsNothing);
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

      expect(find.text('Resumen de hoy'), findsOneWidget);
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

    expect(find.text('Cancelar'), findsOneWidget);

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

  testWidgets('permite seleccionar y eliminar todos los seguimientos', (
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

    final selectAllButton = find.byKey(const Key('tracking-select-all-button'));

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

    expect(
      find.text(
        'Se eliminarán los seguimientos seleccionados y toda la '
        'información asociada, incluidos registros y rutinas. '
        'Esta acción no se puede deshacer.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('tracking-confirm-delete-button')));

    await tester.pumpAndSettle();

    expect(repository.deletedAnonymousIds.length, 2);

    expect(viewModel.profiles, isEmpty);

    expect(viewModel.activeAnonymousId, isNull);

    expect(find.text('Aún no tienes seguimientos'), findsOneWidget);

    expect(find.text('Crea un seguimiento para comenzar.'), findsOneWidget);

    expect(
      find.byKey(const Key('home-empty-create-tracking-button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'estado vacío permite crear el primer seguimiento sin recrearlo automáticamente',
    (tester) async {
      final repository = _FakeTrackingRepository();

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await _pumpHome(tester, viewModel);

      expect(viewModel.profiles, isEmpty);

      expect(find.text('Aún no tienes seguimientos'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('home-empty-create-tracking-button')),
      );

      await tester.pumpAndSettle();

      expect(viewModel.profiles.length, 1);

      expect(viewModel.activeTrackingLabel, 'Seguimiento 1');

      expect(find.text('Seguimiento 1'), findsOneWidget);

      expect(find.textContaining('seguimiento-generado-interno'), findsNothing);
    },
  );

  testWidgets(
    'home muestra acceso a frecuencias descriptivas para el seguimiento actual',
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

      final frequencyAction = find.byKey(const Key('home-frequency-action'));

      await tester.scrollUntilVisible(frequencyAction, 250);

      expect(frequencyAction, findsOneWidget);

      expect(find.text('Frecuencias descriptivas'), findsOneWidget);

      expect(
        find.text('Cuenta registros por periodo y categoría.'),
        findsOneWidget,
      );

      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);

      expect(find.textContaining('diagnóstico'), findsNothing);

      expect(find.textContaining('severidad'), findsNothing);

      expect(find.textContaining('riesgo'), findsNothing);
    },
  );

  testWidgets(
    'home muestra acceso a duraciones y promedios para el seguimiento actual',
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

      final durationAction = find.byKey(const Key('home-duration-action'));

      await tester.scrollUntilVisible(durationAction, 250);

      expect(durationAction, findsOneWidget);

      expect(find.text('Duraciones y promedios'), findsOneWidget);

      expect(
        find.text('Consulta duraciones válidas y promedios por periodo.'),
        findsOneWidget,
      );

      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

      expect(find.textContaining('diagnóstico'), findsNothing);

      expect(find.textContaining('severidad'), findsNothing);

      expect(find.textContaining('riesgo clínico'), findsNothing);

      expect(find.textContaining('tratamiento'), findsNothing);
    },
  );

  testWidgets(
    'home muestra acceso a cumplimiento de rutinas con lenguaje sencillo',
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

      final complianceAction = find.byKey(
        const Key('home-routine-compliance-action'),
      );

      await tester.scrollUntilVisible(complianceAction, 250);

      expect(complianceAction, findsOneWidget);

      expect(find.text('Cumplimiento de rutinas'), findsOneWidget);

      expect(
        find.text(
          'Revisa cuántos registros de rutina '
          'se completaron en un periodo.',
        ),
        findsOneWidget,
      );

      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);

      expect(find.textContaining('ocurrencias'), findsNothing);

      expect(find.textContaining('programadas, completadas'), findsNothing);

      expect(find.textContaining('adaptación'), findsNothing);

      expect(find.textContaining('bienestar'), findsNothing);

      expect(find.textContaining('adherencia'), findsNothing);

      expect(find.textContaining('calidad del cuidado'), findsNothing);

      expect(find.textContaining('evaluación clínica'), findsNothing);
    },
  );
}

Future<void> _pumpHome(
  WidgetTester tester,
  TrackingViewModel viewModel, {
  bool largeViewport = false,
}) async {
  if (largeViewport) {
    tester.view.physicalSize = const Size(1000, 1800);

    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();

      tester.view.resetDevicePixelRatio();
    });
  }

  await tester.pumpWidget(
    ChangeNotifierProvider<TrackingViewModel>.value(
      value: viewModel,
      child: MaterialApp(
        home: HomePlaceholderView(trackingViewModel: viewModel),
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
    return List.unmodifiable(recoveredProfiles);
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
