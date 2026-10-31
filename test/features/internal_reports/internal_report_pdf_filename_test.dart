import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/internal_reports/presentation/widgets/internal_report_pdf_open_button.dart';

void main() {
  group('HU-16 - Nombre del PDF descargado', () {
    test('incluye el número del seguimiento activo', () {
      expect(
        InternalReportPdfOpenButton.fileNameForTracking(1),
        'Sendaris_Reporte_Seguimiento_1.pdf',
      );

      expect(
        InternalReportPdfOpenButton.fileNameForTracking(2),
        'Sendaris_Reporte_Seguimiento_2.pdf',
      );

      expect(
        InternalReportPdfOpenButton.fileNameForTracking(10),
        'Sendaris_Reporte_Seguimiento_10.pdf',
      );
    });

    test('utiliza un nombre genérico si no existe número válido', () {
      expect(
        InternalReportPdfOpenButton.fileNameForTracking(null),
        'Sendaris_Reporte_Interno.pdf',
      );

      expect(
        InternalReportPdfOpenButton.fileNameForTracking(0),
        'Sendaris_Reporte_Interno.pdf',
      );

      expect(
        InternalReportPdfOpenButton.fileNameForTracking(-1),
        'Sendaris_Reporte_Interno.pdf',
      );
    });

    testWidgets('actualiza el nombre al cambiar el seguimiento', (
      tester,
    ) async {
      final authorized = ValueNotifier<bool>(true);
      addTearDown(authorized.dispose);

      Widget buildForTracking(int? trackingNumber) {
        return MaterialApp(
          home: Scaffold(
            body: InternalReportPdfOpenButton(
              trackingNumber: trackingNumber,
              scopeChanges: authorized,
              isAuthorized: () => authorized.value,
              generatePdf: () async {
                return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);
              },
              savePdf: (bytes) async => null,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildForTracking(1));

      var button = tester.widget<InternalReportPdfOpenButton>(
        find.byType(InternalReportPdfOpenButton),
      );

      expect(button.downloadFileName, 'Sendaris_Reporte_Seguimiento_1.pdf');

      await tester.pumpWidget(buildForTracking(3));

      button = tester.widget<InternalReportPdfOpenButton>(
        find.byType(InternalReportPdfOpenButton),
      );

      expect(button.downloadFileName, 'Sendaris_Reporte_Seguimiento_3.pdf');

      await tester.pumpWidget(buildForTracking(null));

      button = tester.widget<InternalReportPdfOpenButton>(
        find.byType(InternalReportPdfOpenButton),
      );

      expect(button.downloadFileName, 'Sendaris_Reporte_Interno.pdf');

      expect(tester.takeException(), isNull);
    });
  });
}
