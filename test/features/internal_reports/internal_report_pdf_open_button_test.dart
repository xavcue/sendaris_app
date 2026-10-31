import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/internal_reports/presentation/widgets/internal_report_pdf_open_button.dart';

Uint8List _fakePdf() {
  return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37]);
}

Widget _app({
  required ValueNotifier<bool> allowed,
  required Future<Uint8List> Function() generate,
}) {
  return MaterialApp(
    home: Scaffold(
      body: InternalReportPdfOpenButton(
        scopeChanges: allowed,
        isAuthorized: () => allowed.value,
        generatePdf: generate,
        viewerBuilder: (context, bytes) {
          return Center(
            child: Text(
              'PDF de prueba: ${bytes.length}',
              key: const Key('test-pdf-content'),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets('HU-16 abre el PDF solo con autorizacion', (tester) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    var generations = 0;

    await tester.pumpWidget(
      _app(
        allowed: allowed,
        generate: () async {
          generations++;
          return _fakePdf();
        },
      ),
    );

    await tester.tap(find.byKey(const Key('internal-report-pdf-open-button')));

    await tester.pumpAndSettle();

    expect(generations, 1);

    expect(
      find.byKey(const Key('internal-report-pdf-preview')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('test-pdf-content')), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 deshabilita el boton sin autorizacion', (tester) async {
    final allowed = ValueNotifier<bool>(false);
    addTearDown(allowed.dispose);

    var generated = false;

    await tester.pumpWidget(
      _app(
        allowed: allowed,
        generate: () async {
          generated = true;
          return _fakePdf();
        },
      ),
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('internal-report-pdf-open-button')),
    );

    expect(button.onPressed, isNull);
    expect(generated, isFalse);

    expect(find.byKey(const Key('internal-report-pdf-preview')), findsNothing);
  });

  testWidgets('HU-16 cierra el PDF cuando se revoca acceso', (tester) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    await tester.pumpWidget(
      _app(allowed: allowed, generate: () async => _fakePdf()),
    );

    await tester.tap(find.byKey(const Key('internal-report-pdf-open-button')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-pdf-content')), findsOneWidget);

    allowed.value = false;

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-pdf-content')), findsNothing);

    expect(find.byKey(const Key('internal-report-pdf-preview')), findsNothing);

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('internal-report-pdf-open-button')),
    );

    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 oculta errores internos del generador', (tester) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    await tester.pumpWidget(
      _app(
        allowed: allowed,
        generate: () async {
          throw StateError('dato-confidencial-de-prueba');
        },
      ),
    );

    await tester.tap(find.byKey(const Key('internal-report-pdf-open-button')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('internal-report-pdf-error')), findsOneWidget);

    expect(find.textContaining('dato-confidencial-de-prueba'), findsNothing);

    expect(tester.takeException(), isNull);
  });
}
