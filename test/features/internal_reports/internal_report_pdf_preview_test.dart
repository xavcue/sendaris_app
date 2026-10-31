import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/internal_reports/presentation/views/internal_report_pdf_preview.dart';

Uint8List _fakePdf() {
  return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37]);
}

Future<void> _pumpPreview(
  WidgetTester tester, {
  required ValueNotifier<bool> allowed,
  required Future<Uint8List> Function() generate,
  bool Function()? authorization,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: InternalReportPdfPreview(
        scopeChanges: allowed,
        isAuthorized: authorization ?? () => allowed.value,
        generatePdf: generate,
        viewerBuilder: (context, bytes) {
          return Center(
            child: Text(
              'PDF privado: ${bytes.length} bytes',
              key: const Key('fake-private-pdf-viewer'),
            ),
          );
        },
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('HU-16 muestra el PDF autorizado en memoria', (tester) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    await _pumpPreview(
      tester,
      allowed: allowed,
      generate: () async => _fakePdf(),
    );

    expect(find.byKey(const Key('fake-private-pdf-viewer')), findsOneWidget);

    expect(
      find.byKey(const Key('internal-report-pdf-preview')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 elimina el documento visible al revocar acceso', (
    tester,
  ) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    await _pumpPreview(
      tester,
      allowed: allowed,
      generate: () async => _fakePdf(),
    );

    expect(find.byKey(const Key('fake-private-pdf-viewer')), findsOneWidget);

    allowed.value = false;
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-private-pdf-viewer')), findsNothing);

    expect(
      find.byKey(const Key('internal-report-pdf-access-ended')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 descarta PDF pendiente si cambia la sesion', (
    tester,
  ) async {
    final allowed = ValueNotifier<bool>(true);
    final pending = Completer<Uint8List>();

    addTearDown(allowed.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: InternalReportPdfPreview(
          scopeChanges: allowed,
          isAuthorized: () => allowed.value,
          generatePdf: () => pending.future,
          viewerBuilder: (context, bytes) {
            return const Text('PDF anterior', key: Key('stale-private-pdf'));
          },
        ),
      ),
    );

    await tester.pump();

    expect(
      find.byKey(const Key('internal-report-pdf-loading')),
      findsOneWidget,
    );

    allowed.value = false;
    await tester.pumpAndSettle();

    pending.complete(_fakePdf());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stale-private-pdf')), findsNothing);

    expect(
      find.byKey(const Key('internal-report-pdf-access-ended')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 no revela detalles internos cuando falla', (tester) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    await _pumpPreview(
      tester,
      allowed: allowed,
      generate: () async {
        throw StateError('Identificador confidencial de prueba');
      },
    );

    expect(find.byKey(const Key('internal-report-pdf-error')), findsOneWidget);

    expect(find.textContaining('Identificador confidencial'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 rechaza bytes sin cabecera PDF', (tester) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    await _pumpPreview(
      tester,
      allowed: allowed,
      generate: () async => Uint8List.fromList([1, 2, 3, 4, 5]),
    );

    expect(find.byKey(const Key('internal-report-pdf-error')), findsOneWidget);

    expect(find.byKey(const Key('fake-private-pdf-viewer')), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 niega acceso cuando falla la autorizacion', (
    tester,
  ) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    var generated = false;

    await _pumpPreview(
      tester,
      allowed: allowed,
      authorization: () {
        throw StateError('Sesion no disponible');
      },
      generate: () async {
        generated = true;
        return _fakePdf();
      },
    );

    expect(generated, isFalse);

    expect(
      find.byKey(const Key('internal-report-pdf-access-ended')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });
}
