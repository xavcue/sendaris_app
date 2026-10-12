import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/models/password_requirements.dart';

void main() {
  group('PasswordRequirements', () {
    test('una contraseña vacía no cumple ningún requisito', () {
      final result = PasswordRequirements.evaluate('');

      expect(result.hasMinimumLength, isFalse);
      expect(result.hasUppercase, isFalse);
      expect(result.hasLowercase, isFalse);
      expect(result.hasNumber, isFalse);
      expect(result.hasSpecialCharacter, isFalse);

      expect(result.fulfilledCount, 0);
      expect(result.isValid, isFalse);
    });

    test('una contraseña válida cumple todos los requisitos', () {
      final result = PasswordRequirements.evaluate('Sendaris2026!');

      expect(result.hasMinimumLength, isTrue);
      expect(result.hasUppercase, isTrue);
      expect(result.hasLowercase, isTrue);
      expect(result.hasNumber, isTrue);
      expect(result.hasSpecialCharacter, isTrue);

      expect(result.fulfilledCount, 5);
      expect(result.isValid, isTrue);
    });

    test('rechaza una contraseña menor a doce caracteres', () {
      final result = PasswordRequirements.evaluate('Abcd1234!');

      expect(result.hasMinimumLength, isFalse);
      expect(result.hasUppercase, isTrue);
      expect(result.hasLowercase, isTrue);
      expect(result.hasNumber, isTrue);
      expect(result.hasSpecialCharacter, isTrue);

      expect(result.isValid, isFalse);
    });

    test('detecta cuando falta una letra mayúscula', () {
      final result = PasswordRequirements.evaluate('sendaris2026!');

      expect(result.hasMinimumLength, isTrue);
      expect(result.hasUppercase, isFalse);
      expect(result.hasLowercase, isTrue);
      expect(result.hasNumber, isTrue);
      expect(result.hasSpecialCharacter, isTrue);

      expect(result.isValid, isFalse);
    });

    test('detecta cuando falta una letra minúscula', () {
      final result = PasswordRequirements.evaluate('SENDARIS2026!');

      expect(result.hasMinimumLength, isTrue);
      expect(result.hasUppercase, isTrue);
      expect(result.hasLowercase, isFalse);
      expect(result.hasNumber, isTrue);
      expect(result.hasSpecialCharacter, isTrue);

      expect(result.isValid, isFalse);
    });

    test('detecta cuando falta un número', () {
      final result = PasswordRequirements.evaluate('SendarisClave!');

      expect(result.hasMinimumLength, isTrue);
      expect(result.hasUppercase, isTrue);
      expect(result.hasLowercase, isTrue);
      expect(result.hasNumber, isFalse);
      expect(result.hasSpecialCharacter, isTrue);

      expect(result.isValid, isFalse);
    });

    test('detecta cuando falta un carácter especial permitido', () {
      final result = PasswordRequirements.evaluate('Sendaris2026A');

      expect(result.hasMinimumLength, isTrue);
      expect(result.hasUppercase, isTrue);
      expect(result.hasLowercase, isTrue);
      expect(result.hasNumber, isTrue);
      expect(result.hasSpecialCharacter, isFalse);

      expect(result.isValid, isFalse);
    });

    test('reconoce los caracteres especiales admitidos por Firebase', () {
      for (final character in PasswordRequirements.allowedSpecialCharacters) {
        final result = PasswordRequirements.evaluate('Sendaris2026$character');

        expect(
          result.hasSpecialCharacter,
          isTrue,
          reason: 'Debe reconocer "$character" como carácter especial.',
        );

        expect(
          result.isValid,
          isTrue,
          reason: 'La contraseña con "$character" debe ser válida.',
        );
      }
    });

    test(
      'un símbolo fuera de la lista documentada no satisface el requisito',
      () {
        final result = PasswordRequirements.evaluate('Sendaris2026-');

        expect(result.hasMinimumLength, isTrue);
        expect(result.hasUppercase, isTrue);
        expect(result.hasLowercase, isTrue);
        expect(result.hasNumber, isTrue);
        expect(result.hasSpecialCharacter, isFalse);

        expect(result.isValid, isFalse);
      },
    );
  });
}
