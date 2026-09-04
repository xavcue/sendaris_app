import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/app.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';

void main() {
  testWidgets('un usuario sin sesión es dirigido a la pantalla de acceso', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository();

    final trackingRepository = FakeTrackingRepository();

    final profileFactory = AnonymousTrackingProfileFactory(
      FakeAnonymousIdGenerator(),
    );

    await tester.pumpWidget(
      SendarisApp(
        authRepository: authRepository,
        trackingRepository: trackingRepository,
        trackingProfileFactory: profileFactory,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Acceso seguro'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Sesión autenticada'), findsNothing);

    await authRepository.dispose();
  });
}

class FakeAuthRepository implements AuthRepository {
  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  @override
  bool get isAuthenticated => false;

  @override
  Stream<bool> get authStateChanges => _controller.stream;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  Future<void> dispose() {
    return _controller.close();
  }
}

class FakeTrackingRepository implements TrackingRepository {
  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return [];
  }
}

class FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  @override
  String generate() {
    return '550e8400-e29b-41d4-a716-446655440000';
  }
}
