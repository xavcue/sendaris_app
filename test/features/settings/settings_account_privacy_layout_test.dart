import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sendaris/app/theme/theme_mode_controller.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/settings/presentation/views/settings_view.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  testWidgets('Ajustes presenta la cuenta y privacidad antes de apariencia', (
    tester,
  ) async {
    await _configureLargeScreen(tester);

    final repository = _FakeSettingsAuthRepository(
      email: 'prueba@sendaris.test',
    );

    final authViewModel = AuthViewModel(repository);
    final trackingViewModel = TrackingViewModel(
      _EmptyTrackingRepository(),
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );
    final themeController = ThemeModeController();

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      authViewModel.dispose();
      trackingViewModel.dispose();
      themeController.dispose();

      await repository.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
          ChangeNotifierProvider<TrackingViewModel>.value(
            value: trackingViewModel,
          ),
          ChangeNotifierProvider<ThemeModeController>.value(
            value: themeController,
          ),
        ],
        child: const MaterialApp(home: SettingsView()),
      ),
    );

    await tester.pumpAndSettle();

    final account = find.byKey(const Key('settings-current-account-card'));
    final privacy = find.byKey(const Key('settings-privacy-card'));
    final appearance = find.byKey(const Key('settings-appearance-card'));
    final deleteAccount = find.byKey(const Key('settings-delete-account-card'));
    final signOut = find.byKey(const Key('settings-sign-out-action'));

    expect(account, findsOneWidget);
    expect(privacy, findsOneWidget);
    expect(appearance, findsOneWidget);
    expect(deleteAccount, findsOneWidget);
    expect(signOut, findsOneWidget);

    expect(find.text('CUENTA ACTUAL'), findsOneWidget);
    expect(find.text('PRIVACIDAD'), findsOneWidget);
    expect(find.text('APARIENCIA'), findsOneWidget);

    expect(find.text('prueba@sendaris.test'), findsOneWidget);
    expect(find.byKey(const Key('settings-account-email')), findsOneWidget);

    expect(find.text('Seguimientos anónimos'), findsOneWidget);

    expect(
      find.text(
        'Los seguimientos no solicitan '
        'nombres ni identificadores '
        'personales del niño.',
      ),
      findsOneWidget,
    );

    expect(
      find.text(
        'La información de cada seguimiento '
        'se mantiene separada.',
      ),
      findsOneWidget,
    );

    expect(find.textContaining('UUID'), findsNothing);
    expect(find.textContaining('identificador interno'), findsNothing);

    final accountY = tester.getTopLeft(account).dy;
    final privacyY = tester.getTopLeft(privacy).dy;
    final appearanceY = tester.getTopLeft(appearance).dy;
    final deleteY = tester.getTopLeft(deleteAccount).dy;
    final signOutY = tester.getTopLeft(signOut).dy;

    expect(accountY, lessThan(privacyY));
    expect(privacyY, lessThan(appearanceY));
    expect(appearanceY, lessThan(deleteY));
    expect(deleteY, lessThan(signOutY));

    expect(tester.takeException(), isNull);
  });

  testWidgets('sin sesión disponible muestra privacidad y apariencia', (
    tester,
  ) async {
    await _configureLargeScreen(tester);

    final themeController = ThemeModeController();

    addTearDown(themeController.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeModeController>.value(
        value: themeController,
        child: const MaterialApp(home: SettingsView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('PRIVACIDAD'), findsOneWidget);
    expect(find.text('APARIENCIA'), findsOneWidget);

    expect(find.byKey(const Key('settings-privacy-card')), findsOneWidget);

    expect(
      find.byKey(const Key('settings-current-account-card')),
      findsNothing,
    );

    expect(find.byKey(const Key('settings-sign-out-action')), findsNothing);

    expect(
      find.byKey(const Key('settings-delete-account-action')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });
}

Future<void> _configureLargeScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1100, 2600);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _FakeSettingsAuthRepository
    implements AuthRepository, AuthEmailVerificationRepository {
  _FakeSettingsAuthRepository({required this.email});

  final String email;

  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  @override
  bool get isAuthenticated => true;

  @override
  Stream<bool> get authStateChanges => _controller.stream;

  @override
  String? get currentUserEmail => email;

  @override
  bool get isCurrentUserEmailVerified => true;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async => true;

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _EmptyTrackingRepository implements TrackingRepository {
  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return [];
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() => 'seguimiento-prueba';
}
