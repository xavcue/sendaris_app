import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/indicators/presentation/views/indicators_view.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  testWidgets(
    'Indicadores muestra las métricas disponibles sin exponer identificadores',
    (tester) async {
      final repository = _FakeTrackingRepository(
        recoveredProfiles: [
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-interno-a',
            createdAt: DateTime.utc(2026, 9, 7),
            trackingNumber: 1,
          ),
        ],
      );

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      await _pumpView(tester, viewModel);

      expect(find.byKey(const Key('sendaris-primary-app-bar')), findsOneWidget);

      expect(
        find.byKey(const Key('sendaris-primary-app-bar-logo')),
        findsOneWidget,
      );

      expect(find.text('Sendaris'), findsOneWidget);

      expect(find.byKey(const Key('indicators-title')), findsOneWidget);

      expect(find.text('Indicadores'), findsOneWidget);

      expect(find.text('Consulta la información registrada'), findsOneWidget);

      expect(find.text('Frecuencias descriptivas'), findsOneWidget);

      expect(find.text('Duraciones y promedios'), findsOneWidget);

      expect(find.text('Cumplimiento de rutinas'), findsOneWidget);

      expect(find.textContaining('seguimiento-interno-a'), findsNothing);

      expect(find.textContaining('UUID'), findsNothing);

      expect(find.textContaining('identificador interno'), findsNothing);

      expect(find.textContaining('perfil activo'), findsNothing);
    },
  );

  testWidgets(
    'sin seguimiento muestra orientación y deshabilita los indicadores',
    (tester) async {
      final repository = _FakeTrackingRepository();

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      await _pumpView(tester, viewModel);

      expect(viewModel.hasActiveProfile, isFalse);

      expect(
        find.byKey(const Key('indicators-no-tracking-message')),
        findsOneWidget,
      );

      expect(
        find.text(
          'Crea o selecciona un seguimiento '
          'para consultar sus indicadores.',
        ),
        findsOneWidget,
      );

      final frequencyOption = find.byKey(
        const Key('indicators-frequency-option'),
      );

      final durationOption = find.byKey(
        const Key('indicators-duration-option'),
      );

      final routineComplianceOption = find.byKey(
        const Key('indicators-routine-compliance-option'),
      );

      expect(frequencyOption, findsOneWidget);

      expect(durationOption, findsOneWidget);

      expect(routineComplianceOption, findsOneWidget);

      final optionInkWells = tester
          .widgetList<InkWell>(
            find.descendant(
              of: find.byType(ListView),
              matching: find.byType(InkWell),
            ),
          )
          .toList();

      expect(optionInkWells, hasLength(3));

      expect(optionInkWells.every((inkWell) => inkWell.onTap == null), isTrue);

      expect(find.textContaining('perfil activo'), findsNothing);
    },
  );
}

Future<void> _pumpView(WidgetTester tester, TrackingViewModel viewModel) async {
  tester.view.physicalSize = const Size(1000, 1800);

  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<TrackingViewModel>.value(
      value: viewModel,
      child: const MaterialApp(home: IndicatorsView()),
    ),
  );

  await tester.pumpAndSettle();
}

class _FakeTrackingRepository implements TrackingRepository {
  _FakeTrackingRepository({this.recoveredProfiles = const []});

  final List<AnonymousTrackingProfile> recoveredProfiles;

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return List.unmodifiable(recoveredProfiles);
  }
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() {
    return 'seguimiento-generado-interno';
  }
}
