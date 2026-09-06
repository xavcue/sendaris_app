import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/app.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_repository.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_factory.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_id_generator.dart';
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

    final behaviorRepository = FakeBehaviorRepository();

    const behaviorRecordFactory = BehaviorRecordFactory(
      FakeBehaviorRecordIdGenerator(),
    );

    await tester.pumpWidget(
      SendarisApp(
        authRepository: authRepository,
        trackingRepository: trackingRepository,
        trackingProfileFactory: profileFactory,
        behaviorRepository: behaviorRepository,
        behaviorRecordFactory: behaviorRecordFactory,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sendaris'), findsOneWidget);

    expect(find.text('Acceso seguro'), findsOneWidget);

    expect(find.text('Iniciar sesión'), findsOneWidget);

    expect(find.text('Resumen de hoy'), findsNothing);

    expect(find.text('Acciones rápidas'), findsNothing);

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

class FakeBehaviorRepository implements BehaviorRepository {
  @override
  Future<void> saveBehavior(BehaviorRecord record) async {}

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    return [];
  }
}

class FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  @override
  String generate() {
    return '550e8400-e29b-41d4-a716-446655440000';
  }
}

class FakeBehaviorRecordIdGenerator implements BehaviorRecordIdGenerator {
  const FakeBehaviorRecordIdGenerator();

  @override
  String generate() {
    return 'registro-widget-test';
  }
}
