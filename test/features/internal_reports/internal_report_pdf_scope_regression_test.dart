import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/internal_reports/presentation/widgets/internal_report_pdf_open_button.dart';

Uint8List _pdfBytes() {
  return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x37]);
}

Widget _buildDownload({
  required ValueNotifier<bool> authorization,
  required Future<Uint8List> Function() generatePdf,
  required InternalPdfSaveCallback savePdf,
}) {
  return MaterialApp(
    home: Scaffold(
      body: InternalReportPdfOpenButton(
        trackingNumber: 1,
        scopeChanges: authorization,
        isAuthorized: () => authorization.value,
        generatePdf: generatePdf,
        savePdf: savePdf,
      ),
    ),
  );
}

Future<void> _startDownload(WidgetTester tester) async {
  final download = find.byKey(const Key('internal-report-pdf-download-button'));

  await tester.tap(download);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));

  expect(
    find.byKey(const Key('internal-report-pdf-download-warning')),
    findsOneWidget,
  );

  await tester.tap(
    find.byKey(const Key('internal-report-pdf-download-confirm')),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('HU-16 no reanuda una descarga antigua tras cambio A-B-A', (
    tester,
  ) async {
    final authorization = ValueNotifier<bool>(true);
    final pendingGeneration = Completer<Uint8List>();

    addTearDown(authorization.dispose);

    var generationCount = 0;
    var saveCount = 0;

    await tester.pumpWidget(
      _buildDownload(
        authorization: authorization,
        generatePdf: () {
          generationCount++;
          return pendingGeneration.future;
        },
        savePdf: (bytes) async {
          saveCount++;
          return 'content://documentos/reporte';
        },
      ),
    );

    await _startDownload(tester);

    expect(generationCount, 1);
    expect(saveCount, 0);

    expect(
      find.byKey(const Key('internal-report-pdf-download-progress')),
      findsOneWidget,
    );

    // A pierde autorización al cambiar al seguimiento B.
    authorization.value = false;
    await tester.pump();

    // El usuario regresa a A antes de que finalice la
    // generación original. Esto no debe recuperar
    // el permiso de la operación anterior.
    authorization.value = true;
    await tester.pump();

    pendingGeneration.complete(_pdfBytes());

    await tester.pump();
    await tester.pumpAndSettle();

    // La operación anterior debe descartarse.
    expect(saveCount, 0);

    expect(
      find.text('PDF guardado en la ubicación seleccionada.'),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 no entrega bytes después de cerrar el componente', (
    tester,
  ) async {
    final authorization = ValueNotifier<bool>(true);
    final pendingGeneration = Completer<Uint8List>();

    addTearDown(authorization.dispose);

    var saveCount = 0;

    await tester.pumpWidget(
      _buildDownload(
        authorization: authorization,
        generatePdf: () => pendingGeneration.future,
        savePdf: (bytes) async {
          saveCount++;
          return 'content://documentos/reporte';
        },
      ),
    );

    await _startDownload(tester);

    // Simula que la navegación retira la pantalla
    // de reportes mientras se genera el documento.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );

    pendingGeneration.complete(_pdfBytes());

    await tester.pumpAndSettle();

    expect(saveCount, 0);

    expect(
      find.byKey(const Key('internal-report-pdf-download-button')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 no genera el PDF si se revoca acceso en la advertencia', (
    tester,
  ) async {
    final authorization = ValueNotifier<bool>(true);

    addTearDown(authorization.dispose);

    var generationCount = 0;
    var saveCount = 0;

    await tester.pumpWidget(
      _buildDownload(
        authorization: authorization,
        generatePdf: () async {
          generationCount++;
          return _pdfBytes();
        },
        savePdf: (bytes) async {
          saveCount++;
          return 'content://documentos/reporte';
        },
      ),
    );

    await tester.tap(
      find.byKey(const Key('internal-report-pdf-download-button')),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const Key('internal-report-pdf-download-warning')),
      findsOneWidget,
    );

    // El acceso desaparece antes de confirmar.
    authorization.value = false;
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('internal-report-pdf-download-confirm')),
    );

    await tester.pumpAndSettle();

    expect(generationCount, 0);
    expect(saveCount, 0);

    final downloadButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('internal-report-pdf-download-button')),
    );

    expect(downloadButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
