import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HU-18 - Prevención de divulgación externa', () {
    test(
      'no existen dependencias destinadas a compartir o enviar información',
      () async {
        final pubspec = await File('pubspec.yaml').readAsString();

        const forbiddenDependencies = <String>[
          'share_plus:',
          'flutter_email_sender:',
          'mailer:',
          'flutter_sms:',
          'sms_advanced:',
        ];

        for (final dependency in forbiddenDependencies) {
          expect(
            pubspec,
            isNot(contains(dependency)),
            reason:
                'HU-18 no permite dependencias orientadas a divulgar información: '
                '$dependency',
          );
        }
      },
    );

    test(
      'el código de la aplicación no importa capacidades de divulgación',
      () async {
        final dartFiles = await _dartFilesInsideLib();

        const forbiddenImports = <String>[
          'package:share_plus/',
          'package:flutter_email_sender/',
          'package:mailer/',
          'package:flutter_sms/',
          'package:sms_advanced/',
        ];

        for (final file in dartFiles) {
          final content = await file.readAsString();

          for (final forbiddenImport in forbiddenImports) {
            expect(
              content,
              isNot(contains(forbiddenImport)),
              reason:
                  'Se detectó una capacidad de divulgación prohibida por HU-18 '
                  'en ${file.path}: $forbiddenImport',
            );
          }
        }
      },
    );

    test(
      'el código no contiene llamadas conocidas para compartir información',
      () async {
        final dartFiles = await _dartFilesInsideLib();

        const forbiddenCalls = <String>[
          'Share.share(',
          'SharePlus.instance.share(',
          'FlutterEmailSender.send(',
        ];

        for (final file in dartFiles) {
          final content = await file.readAsString();

          for (final forbiddenCall in forbiddenCalls) {
            expect(
              content,
              isNot(contains(forbiddenCall)),
              reason:
                  'Se detectó una operación de divulgación prohibida por HU-18 '
                  'en ${file.path}: $forbiddenCall',
            );
          }
        }
      },
    );
  });
}

Future<List<File>> _dartFilesInsideLib() async {
  final files = <File>[];

  await for (final entity in Directory('lib').list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity);
    }
  }

  return files;
}
