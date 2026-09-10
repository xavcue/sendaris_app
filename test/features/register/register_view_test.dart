import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/register/presentation/views/register_view.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  testWidgets('pantalla de registro utiliza nombres claros para el usuario', (
    tester,
  ) async {
    final repository = _FakeTrackingRepository(
      recoveredProfiles: [
        AnonymousTrackingProfile(
          anonymousId: 'anonimo-test',
          createdAt: DateTime.utc(2026, 9, 7),
        ),
      ],
    );

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    addTearDown(viewModel.dispose);

    await viewModel.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<TrackingViewModel>.value(
        value: viewModel,
        child: const MaterialApp(home: RegisterView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Nuevo registro'), findsOneWidget);

    expect(find.text('¿Qué quieres registrar?'), findsOneWidget);

    expect(find.text('Registrar seguimiento'), findsNothing);

    final sleepOption = find.byKey(const Key('register-sleep-option'));

    await tester.scrollUntilVisible(
      sleepOption,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(sleepOption, findsOneWidget);

    expect(find.text('Sueño'), findsOneWidget);

    expect(find.text('Registrar periodo de sueño'), findsOneWidget);

    final atypicalOption = find.byKey(
      const Key('register-atypical-situation-option'),
    );

    await tester.scrollUntilVisible(
      atypicalOption,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(atypicalOption, findsOneWidget);

    expect(find.text('Otra situación'), findsOneWidget);

    expect(find.text('Registrar otro acontecimiento'), findsOneWidget);

    expect(find.textContaining('seguimiento anónimo'), findsNothing);

    expect(find.textContaining('identificador interno'), findsNothing);
  });
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
    return 'perfil-generado';
  }
}
