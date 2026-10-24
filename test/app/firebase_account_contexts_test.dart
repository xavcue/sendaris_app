import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';

void main() {
  group('FirebaseAccountIdentityPolicy', () {
    test('identifica la cuenta A en el contexto principal', () {
      final result = FirebaseAccountIdentityPolicy.locate(
        expectedUserId: 'uid-a',
        primaryUserId: 'uid-a',
        secondaryUserId: 'uid-b',
      );

      expect(result, FirebaseAccountMatch.primary);
    });

    test('identifica la cuenta B en el contexto secundario', () {
      final result = FirebaseAccountIdentityPolicy.locate(
        expectedUserId: 'uid-b',
        primaryUserId: 'uid-a',
        secondaryUserId: 'uid-b',
      );

      expect(result, FirebaseAccountMatch.secondary);
    });

    test('conserva A cuando B cierra su sesión', () {
      final result = FirebaseAccountIdentityPolicy.locate(
        expectedUserId: 'uid-a',
        primaryUserId: 'uid-a',
        secondaryUserId: null,
      );

      expect(result, FirebaseAccountMatch.primary);
    });

    test('no confunde la identidad A con B', () {
      final result = FirebaseAccountIdentityPolicy.locate(
        expectedUserId: 'uid-c',
        primaryUserId: 'uid-a',
        secondaryUserId: 'uid-b',
      );

      expect(result, FirebaseAccountMatch.notFound);
    });

    test('no selecciona una sesión inexistente', () {
      final result = FirebaseAccountIdentityPolicy.locate(
        expectedUserId: 'uid-a',
        primaryUserId: null,
        secondaryUserId: null,
      );

      expect(result, FirebaseAccountMatch.notFound);
    });

    test('rechaza un UID presente en ambos contextos', () {
      final result = FirebaseAccountIdentityPolicy.locate(
        expectedUserId: 'uid-a',
        primaryUserId: 'uid-a',
        secondaryUserId: 'uid-a',
      );

      expect(result, FirebaseAccountMatch.conflict);
    });

    test('rechaza un UID esperado vacío', () {
      final result = FirebaseAccountIdentityPolicy.locate(
        expectedUserId: '',
        primaryUserId: 'uid-a',
        secondaryUserId: 'uid-b',
      );

      expect(result, FirebaseAccountMatch.invalid);
    });

    test('rechaza identidades con espacios externos', () {
      final result = FirebaseAccountIdentityPolicy.locate(
        expectedUserId: ' uid-a ',
        primaryUserId: 'uid-a',
        secondaryUserId: 'uid-b',
      );

      expect(result, FirebaseAccountMatch.invalid);
    });

    test('rechaza una identidad secundaria inconsistente', () {
      final result = FirebaseAccountIdentityPolicy.locate(
        expectedUserId: 'uid-a',
        primaryUserId: 'uid-a',
        secondaryUserId: ' uid-b',
      );

      expect(result, FirebaseAccountMatch.invalid);
    });

    test('permite encontrar la cuenta del contexto secundario '
        'sin sesión principal', () {
      final result = FirebaseAccountIdentityPolicy.locate(
        expectedUserId: 'uid-b',
        primaryUserId: null,
        secondaryUserId: 'uid-b',
      );

      expect(result, FirebaseAccountMatch.secondary);
    });
  });
}
