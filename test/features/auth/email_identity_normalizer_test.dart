import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/services/email_identity_normalizer.dart';

void main() {
  group('EmailIdentityNormalizer', () {
    test('elimina espacios exteriores', () {
      expect(
        EmailIdentityNormalizer.normalize('  cuenta@example.com  '),
        'cuenta@example.com',
      );
    });

    test('normaliza mayúsculas del dominio sin alterar el usuario', () {
      expect(
        EmailIdentityNormalizer.normalize('Usuario.Prueba+tag@EXAMPLE.COM'),
        'Usuario.Prueba+tag@example.com',
      );
    });

    test('conserva los puntos del usuario para Gmail', () {
      expect(
        EmailIdentityNormalizer.normalize('nombre.apellido@gmail.com'),
        'nombre.apellido@gmail.com',
      );
    });

    test('conserva alias con signo más para Gmail', () {
      expect(
        EmailIdentityNormalizer.normalize('nombreapellido+sendaris@gmail.com'),
        'nombreapellido+sendaris@gmail.com',
      );
    });

    test('conserva mayúsculas puntos y alias del usuario Gmail', () {
      expect(
        EmailIdentityNormalizer.normalize(
          '  Nombre.Apellido+Sendaris02@GMAIL.COM  ',
        ),
        'Nombre.Apellido+Sendaris02@gmail.com',
      );
    });

    test('conserva googlemail.com como dominio independiente', () {
      expect(
        EmailIdentityNormalizer.normalize('nombre.apellido@googlemail.com'),
        'nombre.apellido@googlemail.com',
      );
    });

    test('conserva alias con signo más para Outlook', () {
      expect(
        EmailIdentityNormalizer.normalize(
          'nombre.apellido+sendaris@outlook.com',
        ),
        'nombre.apellido+sendaris@outlook.com',
      );
    });

    test('conserva alias con signo más para Hotmail', () {
      expect(
        EmailIdentityNormalizer.normalize('usuario+registro@hotmail.com'),
        'usuario+registro@hotmail.com',
      );
    });

    test('conserva alias con signo más para Live', () {
      expect(
        EmailIdentityNormalizer.normalize('usuario+registro@live.com'),
        'usuario+registro@live.com',
      );
    });

    test('conserva alias con signo más para MSN', () {
      expect(
        EmailIdentityNormalizer.normalize('usuario+registro@msn.com'),
        'usuario+registro@msn.com',
      );
    });

    test('conserva puntos y alias en otros proveedores', () {
      expect(
        EmailIdentityNormalizer.normalize('nombre.apellido+prueba@yahoo.com'),
        'nombre.apellido+prueba@yahoo.com',
      );
    });

    test('conserva cuentas corporativas sin alterar el usuario', () {
      expect(
        EmailIdentityNormalizer.normalize('nombre.apellido+prueba@EMPRESA.COM'),
        'nombre.apellido+prueba@empresa.com',
      );
    });

    test('mantiene un correo ya normalizado', () {
      expect(
        EmailIdentityNormalizer.normalize('nombreapellido@gmail.com'),
        'nombreapellido@gmail.com',
      );
    });

    test('no intenta corregir un correo sin arroba', () {
      expect(
        EmailIdentityNormalizer.normalize('  correo-invalido  '),
        'correo-invalido',
      );
    });

    test('no intenta normalizar un correo con varias arrobas', () {
      expect(
        EmailIdentityNormalizer.normalize('usuario@@gmail.com'),
        'usuario@@gmail.com',
      );
    });
  });
}
