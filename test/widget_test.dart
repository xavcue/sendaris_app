import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/app.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';

void main() {
  testWidgets('un usuario sin sesión es dirigido a la pantalla de acceso', (
    tester,
  ) async {
    final repository = FakeAuthRepository();

    await tester.pumpWidget(SendarisApp(authRepository: repository));

    await tester.pumpAndSettle();

    expect(find.text('Acceso seguro'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Sesión autenticada'), findsNothing);

    await repository.dispose();
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
