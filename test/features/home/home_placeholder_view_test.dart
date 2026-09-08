import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/home/presentation/views/home_placeholder_view.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  testWidgets(
    'home usa lenguaje orientado al usuario y no muestra el identificador interno',
    (tester) async {
      final repository = _FakeTrackingRepository(
        recoveredProfiles: [
          AnonymousTrackingProfile(
            anonymousId: 'ID-INTERNO-NO-DEBE-MOSTRARSE',
            createdAt: DateTime.utc(2026, 9, 7),
          ),
        ],
      );

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<TrackingViewModel>.value(
          value: viewModel,
          child: MaterialApp(
            home: HomePlaceholderView(trackingViewModel: viewModel),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Resumen de hoy'), findsOneWidget);

      expect(find.text('Perfil activo'), findsOneWidget);

      expect(find.text('Perfil listo'), findsOneWidget);

      expect(
        find.text('Puedes comenzar a registrar información.'),
        findsOneWidget,
      );

      expect(find.textContaining('ID-INTERNO'), findsNothing);

      expect(find.textContaining('Seguimiento listo'), findsNothing);

      expect(find.textContaining('ámbito anónimo'), findsNothing);

      expect(find.text('Perfil seleccionado'), findsNothing);

      expect(find.text('Todo listo para registrar'), findsNothing);
    },
  );
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
