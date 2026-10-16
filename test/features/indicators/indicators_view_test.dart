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
  testWidgets('Indicadores mantiene el estilo de navegación '
      'y los nombres actualizados', (tester) async {
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

    expect(viewModel.hasActiveProfile, isTrue);

    expect(find.byKey(const Key('indicators-view')), findsOneWidget);

    expect(find.byKey(const Key('sendaris-primary-app-bar')), findsOneWidget);

    expect(
      find.byKey(const Key('sendaris-primary-app-bar-logo')),
      findsOneWidget,
    );

    expect(find.text('Sendaris'), findsOneWidget);

    expect(find.byKey(const Key('indicators-title')), findsOneWidget);

    expect(find.text('Indicadores'), findsOneWidget);

    expect(find.text('Consulta la información registrada'), findsOneWidget);

    expect(find.text('Calendario de registros'), findsOneWidget);

    expect(find.text('Resumen de duraciones'), findsOneWidget);

    expect(find.text('Resumen de cumplimiento de rutinas'), findsOneWidget);

    expect(find.text('Cumplimiento de rutinas'), findsNothing);

    expect(find.text('INDICADORES DISPONIBLES'), findsNothing);

    expect(find.text('Frecuencias descriptivas'), findsNothing);

    expect(
      find.descendant(
        of: find.byKey(const Key('indicators-frequency-option')),
        matching: find.byIcon(Icons.event_note_rounded),
      ),
      findsOneWidget,
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('indicators-duration-option')),
        matching: find.byIcon(Icons.schedule_rounded),
      ),
      findsOneWidget,
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('indicators-routine-compliance-option')),
        matching: find.byIcon(Icons.fact_check_outlined),
      ),
      findsOneWidget,
    );

    expect(find.textContaining('seguimiento-interno-a'), findsNothing);

    expect(find.textContaining('UUID'), findsNothing);

    expect(find.textContaining('identificador interno'), findsNothing);

    expect(find.textContaining('perfil activo'), findsNothing);
  });

  testWidgets('las tres tarjetas mantienen dimensiones '
      'y navegación visual uniforme', (tester) async {
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

    const optionKeys = [
      Key('indicators-frequency-option'),
      Key('indicators-duration-option'),
      Key('indicators-routine-compliance-option'),
    ];

    for (final key in optionKeys) {
      final option = find.byKey(key);

      expect(option, findsOneWidget);

      expect(
        find.descendant(
          of: option,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedBox && widget.constraints.minHeight == 126,
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: option,
          matching: find.byIcon(Icons.arrow_forward_rounded),
        ),
        findsOneWidget,
      );

      final inkWell = tester.widget<InkWell>(
        find.descendant(of: option, matching: find.byType(InkWell)),
      );

      expect(inkWell.onTap, isNotNull);
    }
  });

  testWidgets('sin seguimiento muestra orientación '
      'y deshabilita los indicadores', (tester) async {
    final repository = _FakeTrackingRepository();

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    addTearDown(viewModel.dispose);

    await viewModel.initialize();
    await _pumpView(tester, viewModel);

    expect(viewModel.hasActiveProfile, isFalse);

    final emptyMessage = find.byKey(
      const Key('indicators-no-tracking-message'),
    );

    expect(emptyMessage, findsOneWidget);

    expect(
      find.text(
        'Crea o selecciona un seguimiento '
        'desde Inicio para consultar sus indicadores.',
      ),
      findsOneWidget,
    );

    const optionKeys = [
      Key('indicators-frequency-option'),
      Key('indicators-duration-option'),
      Key('indicators-routine-compliance-option'),
    ];

    for (final key in optionKeys) {
      final option = find.byKey(key);

      expect(option, findsOneWidget);

      final inkWell = tester.widget<InkWell>(
        find.descendant(of: option, matching: find.byType(InkWell)),
      );

      expect(inkWell.onTap, isNull);

      expect(
        find.descendant(
          of: option,
          matching: find.byIcon(Icons.arrow_forward_rounded),
        ),
        findsNothing,
      );
    }

    expect(
      tester.getTopLeft(emptyMessage).dy,
      lessThan(tester.getTopLeft(find.byKey(optionKeys.first)).dy),
    );

    expect(find.textContaining('perfil activo'), findsNothing);
  });
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
