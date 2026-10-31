import 'dart:async';
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
  required InternalPdfSaveCallback save,
}) {
  return MaterialApp(
    home: Scaffold(
      body: InternalReportPdfOpenButton(
        scopeChanges: allowed,
        isAuthorized: () => allowed.value,
        generatePdf: generate,
        savePdf: save,
        viewerBuilder: (context, bytes) {
          return Text(
            'Vista privada: ${bytes.length}',
            key: const Key('fake-pdf-preview'),
          );
        },
      ),
    ),
  );
}

Future<void> _openDownloadDialog(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('internal-report-pdf-download-button')),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  expect(
    find.byKey(const Key('internal-report-pdf-download-warning')),
    findsOneWidget,
  );
}

Future<void> _confirmDownload(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('internal-report-pdf-download-confirm')),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('HU-16 guarda el PDF únicamente después de la confirmación', (
    tester,
  ) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    var generationCount = 0;
    var saveCount = 0;
    List<int>? deliveredBytes;

    await tester.pumpWidget(
      _app(
        allowed: allowed,
        generate: () async {
          generationCount++;
          return _fakePdf();
        },
        save: (bytes) async {
          saveCount++;
          deliveredBytes = List<int>.of(bytes);
          return 'content://documentos/reporte';
        },
      ),
    );

    // Ninguna operación se ejecuta solo por mostrar la pantalla.
    expect(generationCount, 0);
    expect(saveCount, 0);

    await _openDownloadDialog(tester);

    // Mostrar la advertencia tampoco genera ni guarda el reporte.
    expect(generationCount, 0);
    expect(saveCount, 0);

    expect(
      find.textContaining('ya no estará protegido por el acceso de Sendaris'),
      findsOneWidget,
    );

    await _confirmDownload(tester);
    await tester.pumpAndSettle();

    expect(generationCount, 1);
    expect(saveCount, 1);
    expect(deliveredBytes, _fakePdf());

    expect(
      find.text('PDF guardado en la ubicación seleccionada.'),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 deshabilita vista previa y descarga sin autorización', (
    tester,
  ) async {
    final allowed = ValueNotifier<bool>(false);
    addTearDown(allowed.dispose);

    var generated = false;
    var saved = false;

    await tester.pumpWidget(
      _app(
        allowed: allowed,
        generate: () async {
          generated = true;
          return _fakePdf();
        },
        save: (bytes) async {
          saved = true;
          return 'content://documentos/reporte';
        },
      ),
    );

    final preview = tester.widget<OutlinedButton>(
      find.byKey(const Key('internal-report-pdf-open-button')),
    );

    final download = tester.widget<OutlinedButton>(
      find.byKey(const Key('internal-report-pdf-download-button')),
    );

    expect(preview.onPressed, isNull);
    expect(download.onPressed, isNull);
    expect(generated, isFalse);
    expect(saved, isFalse);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 cancelar la advertencia no genera ni guarda el PDF', (
    tester,
  ) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    var generationCount = 0;
    var saveCount = 0;

    await tester.pumpWidget(
      _app(
        allowed: allowed,
        generate: () async {
          generationCount++;
          return _fakePdf();
        },
        save: (bytes) async {
          saveCount++;
          return 'content://documentos/reporte';
        },
      ),
    );

    await _openDownloadDialog(tester);

    await tester.tap(
      find.byKey(const Key('internal-report-pdf-download-cancel')),
    );

    await tester.pumpAndSettle();

    expect(generationCount, 0);
    expect(saveCount, 0);

    expect(
      find.text('PDF guardado en la ubicación seleccionada.'),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 descarta el PDF pendiente al revocarse el acceso', (
    tester,
  ) async {
    final allowed = ValueNotifier<bool>(true);
    final pending = Completer<Uint8List>();
    addTearDown(allowed.dispose);

    var saveCount = 0;

    await tester.pumpWidget(
      _app(
        allowed: allowed,
        generate: () => pending.future,
        save: (bytes) async {
          saveCount++;
          return 'content://documentos/reporte';
        },
      ),
    );

    await _openDownloadDialog(tester);
    await _confirmDownload(tester);

    expect(
      find.byKey(const Key('internal-report-pdf-download-progress')),
      findsOneWidget,
    );

    // Cambio de sesión o de seguimiento durante la generación.
    allowed.value = false;
    await tester.pump();

    pending.complete(_fakePdf());
    await tester.pumpAndSettle();

    expect(saveCount, 0);

    final download = tester.widget<OutlinedButton>(
      find.byKey(const Key('internal-report-pdf-download-button')),
    );

    expect(download.onPressed, isNull);

    expect(
      find.text('PDF guardado en la ubicación seleccionada.'),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 rechaza bytes que no corresponden a un PDF', (
    tester,
  ) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    var saveCount = 0;

    await tester.pumpWidget(
      _app(
        allowed: allowed,
        generate: () async {
          return Uint8List.fromList([1, 2, 3, 4, 5]);
        },
        save: (bytes) async {
          saveCount++;
          return 'content://documentos/reporte';
        },
      ),
    );

    await _openDownloadDialog(tester);
    await _confirmDownload(tester);
    await tester.pumpAndSettle();

    expect(saveCount, 0);

    expect(find.text('No fue posible guardar el reporte PDF.'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 cancelar el selector no anuncia una descarga exitosa', (
    tester,
  ) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    var saveCount = 0;

    await tester.pumpWidget(
      _app(
        allowed: allowed,
        generate: () async => _fakePdf(),
        save: (bytes) async {
          saveCount++;
          return null;
        },
      ),
    );

    await _openDownloadDialog(tester);
    await _confirmDownload(tester);
    await tester.pumpAndSettle();

    expect(saveCount, 1);

    expect(
      find.text('PDF guardado en la ubicación seleccionada.'),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 no anuncia éxito si se revoca acceso durante guardado', (
    tester,
  ) async {
    final allowed = ValueNotifier<bool>(true);
    final pendingSave = Completer<String?>();
    addTearDown(allowed.dispose);

    var saveCount = 0;

    await tester.pumpWidget(
      _app(
        allowed: allowed,
        generate: () async => _fakePdf(),
        save: (bytes) {
          saveCount++;
          return pendingSave.future;
        },
      ),
    );

    await _openDownloadDialog(tester);
    await _confirmDownload(tester);

    expect(saveCount, 1);

    // El selector nativo ya ha recibido los bytes.
    // No se puede revocar una copia externa ya guardada.
    allowed.value = false;

    pendingSave.complete('content://documentos/reporte');
    await tester.pumpAndSettle();

    expect(
      find.text('PDF guardado en la ubicación seleccionada.'),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 oculta información interna cuando falla el guardado', (
    tester,
  ) async {
    final allowed = ValueNotifier<bool>(true);
    addTearDown(allowed.dispose);

    await tester.pumpWidget(
      _app(
        allowed: allowed,
        generate: () async => _fakePdf(),
        save: (bytes) async {
          throw StateError('identificador-confidencial-de-prueba');
        },
      ),
    );

    await _openDownloadDialog(tester);
    await _confirmDownload(tester);
    await tester.pumpAndSettle();

    expect(find.text('No fue posible guardar el reporte PDF.'), findsOneWidget);

    expect(
      find.textContaining('identificador-confidencial-de-prueba'),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });
}
