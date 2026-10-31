import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../atypical_situation/domain/models/atypical_situation_record.dart';
import '../../../behavior/domain/models/behavior_record.dart';
import '../../../duration/domain/models/duration_metric_type.dart';
import '../../../duration/presentation/widgets/duration_summary_cards.dart';
import '../../../dysregulation/domain/models/dysregulation_record.dart';
import '../../../feeding/domain/models/feeding_record.dart';
import '../../../frequency/domain/models/monthly_calendar_record.dart';
import '../../../routine_status/domain/models/routine_status.dart';
import '../../../routine_status/domain/models/routine_status_record.dart';
import '../../../sleep/domain/models/sleep_record.dart';
import '../../../social_interaction/domain/models/social_interaction_record.dart';
import '../../domain/models/internal_report.dart';
import '../models/internal_report_display_data.dart';
import '../models/internal_report_routine_details.dart';

/// Genera un PDF para consulta interna del seguimiento.
///
/// Mantiene separados los detalles de acontecimientos y los estados
/// de rutina, conservando los totales generales del reporte.
///
/// No realiza consultas, almacenamiento, impresión ni envío.
class InternalReportPdfService {
  const InternalReportPdfService();

  static const _ink = PdfColor(0.10, 0.19, 0.20);
  static const _teal = PdfColor(0.10, 0.48, 0.44);
  static const _muted = PdfColor(0.39, 0.46, 0.47);
  static const _soft = PdfColor(0.94, 0.98, 0.97);
  static const _track = PdfColor(0.88, 0.93, 0.92);
  static const _border = PdfColor(0.84, 0.89, 0.88);
  static const _stripe = PdfColor(0.97, 0.98, 0.98);

  static const _behavior = PdfColor(0.90, 0.48, 0.45);
  static const _sleep = PdfColor(0.51, 0.58, 0.82);
  static const _feeding = PdfColor(0.89, 0.68, 0.38);
  static const _social = PdfColor(0.49, 0.68, 0.82);
  static const _dysregulation = PdfColor(0.63, 0.55, 0.80);
  static const _atypical = PdfColor(0.75, 0.61, 0.49);
  static const _routine = PdfColor(0.41, 0.74, 0.67);

  Future<Uint8List> generate(
    InternalReport report, {
    int? trackingNumber,
  }) async {
    _validateReport(report);

    if (trackingNumber != null && trackingNumber <= 0) {
      throw ArgumentError.value(
        trackingNumber,
        'trackingNumber',
        'El número de seguimiento debe ser positivo.',
      );
    }

    final trackingLabel = trackingNumber == null
        ? 'Seguimiento anónimo'
        : 'Seguimiento $trackingNumber';

    final display = InternalReportDisplayData.fromReport(report);
    final routineDetails = InternalReportRoutineDetails.fromReport(report);

    // El historial general conserva todos los registros.
    // La tabla específica de eventos excluye estados de rutina,
    // porque estos ya tienen su propia sección.
    final eventRows = display.rows
        .where((row) => row.type != CalendarRecordType.routineStatus)
        .toList(growable: false);

    final fontBytes = await rootBundle.load(
      'assets/fonts/Manrope-VariableFont_wght.ttf',
    );

    final logoBytes = await rootBundle.load(
      'assets/branding/sendaris_app_icon.png',
    );

    final font = pw.Font.ttf(fontBytes);

    final logo = pw.MemoryImage(
      logoBytes.buffer.asUint8List(
        logoBytes.offsetInBytes,
        logoBytes.lengthInBytes,
      ),
    );

    final theme = pw.ThemeData.withFont(base: font, bold: font);

    final document = pw.Document(
      title: 'Sendaris - Reporte interno',
      author: 'Sendaris',
      creator: 'Sendaris Android',
      subject: 'Resumen descriptivo del seguimiento',
    );

    // SECCIÓN 1: panorama general.
    //
    // Los 13 registros del ejemplo incluyen eventos y estados
    // de rutina. No se modifican los cálculos existentes.
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        theme: theme,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _cover(display, logo, trackingLabel),
            _gap(12),
            _heading('Panorama del periodo'),
            _gap(9),
            _kpiGrid(display),
            _gap(14),
            _heading('Distribución de registros'),
            _gap(4),
            _text(
              'Cantidad y proporción de cada categoría registrada '
              'en el periodo.',
              11,
              color: _muted,
            ),
            _gap(9),
            _categoryChart(display),
            _gap(10),
            _notice(
              'El panorama incluye acontecimientos y estados de '
              'rutina. Sus detalles se presentan por separado '
              'en las siguientes secciones.',
            ),
            pw.Spacer(),
            _footer(context),
          ],
        ),
      ),
    );

    // SECCIÓN 2: acontecimientos inmediatamente después
    // de la distribución de registros.
    //
    // Excluye completamente los estados de rutina de esta tabla.
    // MultiPage conserva la paginación de eventos extensos.
    if (eventRows.isNotEmpty) {
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
          maxPages: 200,
          theme: theme,
          header: (context) =>
              _smallHeader(logo, 'DETALLE DE EVENTOS', trackingLabel),
          footer: _footer,
          build: (context) => [
            _gap(18),
            _heading('Detalle de eventos registrados'),
            _gap(8),
            _text(
              '$trackingLabel · ${eventRows.length} '
              '${eventRows.length == 1 ? 'evento' : 'eventos'}',
              12,
              color: _teal,
              bold: true,
            ),
            _gap(5),
            _text('Periodo: ${display.periodLabel}', 11, color: _muted),
            _gap(5),
            _text(
              'Acontecimientos ordenados desde el más reciente. '
              'Los estados de rutina se presentan en su propia sección.',
              10,
              color: _muted,
            ),
            _gap(14),
            _recordsTable(eventRows, report.anonymousId),
            _gap(10),
            _text(
              'Se muestran únicamente los campos complementarios '
              'disponibles de cada acontecimiento.',
              9,
              color: _muted,
            ),
          ],
        ),
      );
    }

    // SECCIÓN 3: cumplimiento y detalle nominal de rutinas.
    //
    // Se crea únicamente si existen estados de rutina.
    // Conserva juntos el porcentaje, el gráfico y la tabla.
    if (!routineDetails.isEmpty) {
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
          maxPages: 200,
          theme: theme,
          header: (context) =>
              _smallHeader(logo, 'CUMPLIMIENTO DE RUTINAS', trackingLabel),
          footer: _footer,
          build: (context) => [
            _gap(16),
            _heading('Cumplimiento de rutinas'),
            _gap(9),
            _routinePanel(report, display),
            _gap(14),
            _heading('Rutinas registradas en el periodo'),
            _gap(6),
            _text(
              '${routineDetails.total} estados de rutina. '
              'Cada fila identifica la fecha, el nombre, el estado '
              'y las observaciones disponibles.',
              10,
              color: _muted,
            ),
            _gap(9),
            _routineDetailsTable(report, routineDetails),
            _gap(11),
            _notice(
              'Una rutina puede tener varios estados registrados '
              'en fechas distintas. El cumplimiento describe esos '
              'estados y no constituye una evaluación clínica.',
            ),
          ],
        ),
      );
    }

    // SECCIÓN 4: promedios y gráficos de duraciones.
    if (report.durations.hasAnyData) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
          theme: theme,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _smallHeader(logo, 'DURACIONES', trackingLabel),
              _gap(18),
              _heading('Duraciones registradas'),
              _gap(5),
              _text(
                'Sueño en horas y minutos; conducta y desregulación '
                'emocional en minutos.',
                11,
                color: _muted,
              ),
              _gap(11),
              for (final type in DurationMetricType.values) ...[
                _durationPanel(report, type),
                if (type != DurationMetricType.values.last) _gap(10),
              ],
              _gap(10),
              _notice(
                'Los promedios incluyen únicamente duraciones válidas. '
                'Las barras comparan registros mostrados dentro '
                'de la misma categoría.',
              ),
              pw.Spacer(),
              _footer(context),
            ],
          ),
        ),
      );
    }

    return document.save();
  }

  static pw.Widget _cover(
    InternalReportDisplayData display,
    pw.MemoryImage logo,
    String trackingLabel,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Image(logo, width: 42, height: 42, fit: pw.BoxFit.contain),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _text('SENDARIS', 17, color: _teal, bold: true),
                _text('Seguimiento descriptivo', 9, color: _muted),
              ],
            ),
            pw.Spacer(),
            pw.Container(
              color: _soft,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              child: _text('USO INTERNO', 9, color: _teal, bold: true),
            ),
          ],
        ),
        _gap(9),
        _text('Reporte interno del seguimiento', 21, bold: true),
        _gap(5),
        _text(trackingLabel, 13, color: _teal, bold: true),
        _gap(3),
        _text('Periodo: ${display.periodLabel}', 10, color: _muted),
        _gap(2),
        _text(
          'Generado: '
          '${InternalReportDisplayData.formatDate(DateTime.now())}',
          10,
          color: _muted,
        ),
        _gap(8),
        pw.Divider(color: _teal, thickness: 1.2),
      ],
    );
  }

  static pw.Widget _smallHeader(
    pw.MemoryImage logo,
    String section,
    String trackingLabel,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Image(logo, width: 34, height: 34, fit: pw.BoxFit.contain),
            pw.SizedBox(width: 9),
            _text('SENDARIS', 14, color: _teal, bold: true),
            pw.Spacer(),
            _text('$section · $trackingLabel', 9, color: _muted, bold: true),
          ],
        ),
        _gap(9),
        pw.Divider(color: _border, thickness: 0.7),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(color: _border, thickness: 0.7),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _text('Sendaris · Consulta interna', 8.5, color: _muted),
            _text('Página ${context.pageNumber}', 8.5, color: _muted),
          ],
        ),
      ],
    );
  }

  static pw.Text _text(
    String value,
    double size, {
    PdfColor color = _ink,
    bool bold = false,
  }) {
    return pw.Text(
      value,
      style: pw.TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : null,
      ),
    );
  }

  static pw.Widget _heading(String title) {
    return _text(title, 18, bold: true);
  }

  static pw.Widget _gap(double height) {
    return pw.SizedBox(height: height);
  }

  static pw.Widget _panel(
    pw.Widget child, {
    bool tinted = false,
    double padding = 12,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(padding),
      decoration: pw.BoxDecoration(
        color: tinted ? _soft : PdfColors.white,
        border: pw.Border.all(color: _border, width: 0.8),
      ),
      child: child,
    );
  }

  static pw.Widget _notice(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      color: _soft,
      child: _text(message, 10, color: _muted),
    );
  }

  static pw.Widget _kpiGrid(InternalReportDisplayData data) {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              child: _kpi(
                'REGISTROS DEL PERIODO',
                '${data.totalRecords}',
                'Acontecimientos y estados registrados',
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _kpi(
                'DÍAS CON REGISTROS',
                '${data.daysWithRecords}',
                'De ${data.totalDays} días',
              ),
            ),
          ],
        ),
        _gap(10),
        pw.Row(
          children: [
            pw.Expanded(
              child: _kpi(
                'COBERTURA DE REGISTROS',
                data.coverageText,
                '${data.daysWithRecords} de ${data.totalDays} días',
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: _kpi(
                'CUMPLIMIENTO DE RUTINAS',
                data.complianceText,
                '${data.completedRoutineCount} de '
                    '${data.routineStatusCount} estados completados',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _kpi(String label, String value, String detail) {
    return pw.Container(
      height: 82,
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: _soft,
        border: pw.Border.all(color: _border, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _text(label, 9, color: _muted, bold: true),
          _text(value, 24, color: _teal, bold: true),
          _text(detail, 9, color: _muted),
        ],
      ),
    );
  }

  static pw.Widget _categoryChart(InternalReportDisplayData data) {
    if (data.categories.isEmpty) {
      return _panel(
        _text('Sin registros para representar.', 12, color: _muted),
      );
    }

    return _panel(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final category in data.categories) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _text(category.label, 11.5, bold: true),
                _text(
                  '${category.count} · ${category.percentageText}',
                  10.5,
                  bold: true,
                ),
              ],
            ),
            _gap(3),
            _bar(category.fraction, _recordColor(category.type), height: 11),
            _gap(5),
          ],
          _gap(2),
          _text(
            'Las barras representan las categorías respecto al total '
            'de ${data.totalRecords} registros del periodo (100 %).',
            9,
            color: _muted,
          ),
        ],
      ),
    );
  }

  static pw.Widget _routinePanel(
    InternalReport report,
    InternalReportDisplayData data,
  ) {
    final total = data.routineStatusCount;

    return _panel(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _text('ESTADOS DE RUTINA DEL PERIODO', 10, color: _muted, bold: true),
          _gap(8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _text(data.complianceText, 28, color: _teal, bold: true),
              pw.Spacer(),
              _text(
                '${data.completedRoutineCount} de $total completadas',
                12,
                bold: true,
              ),
            ],
          ),
          _gap(10),
          if (total == 0)
            pw.Container(height: 18, color: _track)
          else
            pw.SizedBox(
              height: 18,
              child: pw.Row(
                children: [
                  for (final status in RoutineStatus.values)
                    if (report.routines.countForStatus(status) > 0)
                      pw.Expanded(
                        flex: report.routines.countForStatus(status),
                        child: pw.Container(
                          height: 18,
                          color: _routineColor(status),
                        ),
                      ),
                ],
              ),
            ),
          _gap(10),
          _text('Desglose de estados registrados:', 10.5, bold: true),
          _gap(8),
          pw.Row(
            children: [
              pw.Expanded(
                child: _routineItem(report, RoutineStatus.completed, total),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _routineItem(report, RoutineStatus.modified, total),
              ),
            ],
          ),
          _gap(8),
          pw.Row(
            children: [
              pw.Expanded(
                child: _routineItem(report, RoutineStatus.interrupted, total),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _routineItem(report, RoutineStatus.notCompleted, total),
              ),
            ],
          ),
          _gap(10),
          _text(
            'Cálculo: estados completados ÷ total de estados '
            'registrados × 100. La barra muestra la distribución '
            'de los estados del periodo.',
            10,
            color: _muted,
          ),
        ],
      ),
    );
  }

  static pw.Widget _routineItem(
    InternalReport report,
    RoutineStatus status,
    int total,
  ) {
    final count = report.routines.countForStatus(status);
    final percentage = total == 0 ? 0.0 : count / total * 100;

    return pw.Container(
      height: 54,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border, width: 0.7),
      ),
      child: pw.Row(
        children: [
          pw.Container(width: 9, height: 22, color: _routineColor(status)),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _text(status.label, 10, bold: true),
                _text(
                  '$count · '
                  '${InternalReportDisplayData.formatPercentage(percentage)}',
                  9.5,
                  color: _muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _durationPanel(
    InternalReport report,
    DurationMetricType type,
  ) {
    final observations =
        report.durations
            .resultFor(type)
            .observations
            .where(
              (observation) =>
                  observation.durationMinutes != null &&
                  type.isValidDuration(observation.durationMinutes),
            )
            .toList()
          ..sort((first, second) => second.date.compareTo(first.date));

    final recent = observations.take(2).toList();
    final average = report.averageMinutesFor(type);

    final maximum = recent.fold<int>(0, (value, observation) {
      final minutes = observation.durationMinutes!;
      return minutes > value ? minutes : value;
    });

    return _panel(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _text('Duración promedio: ${type.label}', 12.5, bold: true),
          _gap(6),
          _text(
            average == null
                ? 'Sin datos'
                : DurationSummaryCards.formatDuration(type, average),
            22,
            color: _teal,
            bold: true,
          ),
          _gap(3),
          _text(
            'Promedio calculado con '
            '${report.validDurationsFor(type)} duraciones válidas',
            9.5,
            color: _muted,
          ),
          _gap(8),
          if (recent.isNotEmpty) ...[
            _text('Registros recientes:', 9.5, bold: true),
            _gap(6),
            for (final observation in recent) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _text(
                    InternalReportDisplayData.formatDate(observation.date),
                    9.5,
                    color: _muted,
                  ),
                  _text(
                    DurationSummaryCards.formatDuration(
                      type,
                      observation.durationMinutes!.toDouble(),
                    ),
                    10,
                    bold: true,
                  ),
                ],
              ),
              _gap(3),
              _bar(
                maximum == 0 ? 0 : observation.durationMinutes! / maximum,
                _durationColor(type),
                height: 10,
              ),
              _gap(5),
            ],
          ] else
            _text(
              'Sin duraciones válidas para representar.',
              10,
              color: _muted,
            ),
        ],
      ),
    );
  }

  /// Historial de acontecimientos, sin estados de rutina.
  static pw.Widget _recordsTable(
    List<InternalReportRecordDisplay> events,
    String anonymousId,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: ['Fecha', 'Categoría', 'Información registrada'],
      data: [
        for (final row in events)
          [
            row.dateText,
            row.categoryLabel,
            _eventDescription(row.record, anonymousId),
          ],
      ],
      headerDecoration: const pw.BoxDecoration(color: _soft),
      oddRowDecoration: const pw.BoxDecoration(color: _stripe),
      border: const pw.TableBorder(
        top: pw.BorderSide(color: _border, width: 0.7),
        bottom: pw.BorderSide(color: _border, width: 0.7),
        horizontalInside: pw.BorderSide(color: _border, width: 0.5),
      ),
      headerStyle: pw.TextStyle(
        color: _ink,
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(color: _ink, fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      columnWidths: {
        0: const pw.FixedColumnWidth(108),
        1: const pw.FixedColumnWidth(116),
        2: const pw.FlexColumnWidth(),
      },
    );
  }

  /// Tabla exclusiva de estados de rutina.
  static pw.Widget _routineDetailsTable(
    InternalReport report,
    InternalReportRoutineDetails details,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: ['Fecha', 'Rutina y observación', 'Estado'],
      data: [
        for (final entry in details.entries)
          [
            entry.dateLabel,
            _routineDescription(report, entry),
            entry.statusLabel,
          ],
      ],
      headerDecoration: const pw.BoxDecoration(color: _soft),
      oddRowDecoration: const pw.BoxDecoration(color: _stripe),
      border: const pw.TableBorder(
        top: pw.BorderSide(color: _border, width: 0.7),
        bottom: pw.BorderSide(color: _border, width: 0.7),
        horizontalInside: pw.BorderSide(color: _border, width: 0.5),
      ),
      headerStyle: pw.TextStyle(
        color: _ink,
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(color: _ink, fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      columnWidths: {
        0: const pw.FixedColumnWidth(90),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(100),
      },
    );
  }

  static String _routineDescription(
    InternalReport report,
    InternalReportRoutineEntry entry,
  ) {
    for (final record in report.records) {
      if (record.type != CalendarRecordType.routineStatus ||
          record.id != entry.recordId ||
          record.anonymousId != report.anonymousId) {
        continue;
      }

      final source = record.sourceRecord;

      if (source is! RoutineStatusRecord ||
          source.recordId != record.id ||
          source.anonymousId != report.anonymousId ||
          !_sameDay(source.date, entry.date)) {
        continue;
      }

      final observation = _cleanOptional(source.observation);

      if (observation != null) {
        return '${entry.routineName}\nObservación: $observation';
      }

      break;
    }

    return entry.routineName;
  }

  /// Presenta los campos adicionales disponibles de un evento.
  ///
  /// Comprueba ID y seguimiento antes de leer el registro original.
  static String _eventDescription(
    MonthlyCalendarRecord record,
    String anonymousId,
  ) {
    final lines = <String>[_description(record.description)];

    final source = record.sourceRecord;

    if (record.anonymousId != anonymousId) {
      return lines.first;
    }

    if (source is BehaviorRecord &&
        source.anonymousId == anonymousId &&
        source.recordId == record.id) {
      if (source.intensity != null) {
        lines.add('Intensidad: ${source.intensity!.label}');
      }

      if (source.durationMinutes != null) {
        lines.add('Duración: ${source.durationMinutes} min');
      }

      _addField(lines, 'Contexto', source.context);
      _addField(lines, 'Observación', source.observation);
    } else if (source is SleepRecord &&
        source.anonymousId == anonymousId &&
        source.recordId == record.id) {
      lines.add('Inicio: ${source.startTime}');
      lines.add('Fin: ${source.endTime}');

      _addField(lines, 'Observación', source.observation);
    } else if (source is FeedingRecord &&
        source.anonymousId == anonymousId &&
        source.recordId == record.id) {
      _addField(lines, 'Observación', source.observation);
    } else if (source is SocialInteractionRecord &&
        source.anonymousId == anonymousId &&
        source.recordId == record.id) {
      _addField(lines, 'Contexto', source.context);
      _addField(lines, 'Observación', source.observation);
    } else if (source is DysregulationRecord &&
        source.anonymousId == anonymousId &&
        source.recordId == record.id) {
      if (source.intensity != null) {
        lines.add('Intensidad: ${source.intensity!.label}');
      }

      if (source.durationMinutes != null) {
        lines.add('Duración: ${source.durationMinutes} min');
      }

      _addField(lines, 'Contexto', source.context);
      _addField(lines, 'Observación', source.observation);
    } else if (source is AtypicalSituationRecord &&
        source.anonymousId == anonymousId &&
        source.recordId == record.id) {
      _addField(lines, 'Observación', source.observation);
    }

    return lines.join('\n');
  }

  static void _addField(List<String> lines, String label, String? value) {
    final cleaned = _cleanOptional(value);

    if (cleaned != null) {
      lines.add('$label: $cleaned');
    }
  }

  static String? _cleanOptional(String? text) {
    final cleaned = text?.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  static pw.Widget _bar(double fraction, PdfColor color, {double height = 11}) {
    const scale = 10000;

    final filled = (fraction.clamp(0.0, 1.0) * scale).round();

    final remaining = scale - filled;

    return pw.SizedBox(
      height: height,
      child: pw.Row(
        children: [
          if (filled > 0)
            pw.Expanded(
              flex: filled,
              child: pw.Container(height: height, color: color),
            ),
          if (remaining > 0)
            pw.Expanded(
              flex: remaining,
              child: pw.Container(height: height, color: _track),
            ),
        ],
      ),
    );
  }

  static PdfColor _recordColor(CalendarRecordType type) {
    return switch (type) {
      CalendarRecordType.behavior => _behavior,
      CalendarRecordType.sleep => _sleep,
      CalendarRecordType.feeding => _feeding,
      CalendarRecordType.socialInteraction => _social,
      CalendarRecordType.dysregulation => _dysregulation,
      CalendarRecordType.atypicalSituation => _atypical,
      CalendarRecordType.routineStatus => _routine,
    };
  }

  static PdfColor _durationColor(DurationMetricType type) {
    return switch (type) {
      DurationMetricType.sleep => _sleep,
      DurationMetricType.behavior => _behavior,
      DurationMetricType.dysregulation => _dysregulation,
    };
  }

  static PdfColor _routineColor(RoutineStatus status) {
    return switch (status) {
      RoutineStatus.completed => _teal,
      RoutineStatus.modified => _sleep,
      RoutineStatus.interrupted => _feeding,
      RoutineStatus.notCompleted => _behavior,
    };
  }

  static String _description(String description) {
    final text = description.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text.isEmpty ? 'Sin descripción' : text;
  }

  static bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static void _validateReport(InternalReport report) {
    final id = report.anonymousId.trim();

    if (id.isEmpty ||
        report.coverage.anonymousId != id ||
        report.durations.anonymousId != id ||
        report.routines.anonymousId != id) {
      throw StateError('El reporte contiene información de otro seguimiento.');
    }

    if (!_sameDay(report.coverage.startDate, report.period.startDate) ||
        !_sameDay(report.coverage.endDate, report.period.endDate) ||
        !_sameDay(report.durations.startDate, report.period.startDate) ||
        !_sameDay(report.durations.endDate, report.period.endDate) ||
        !_sameDay(report.routines.startDate, report.period.startDate) ||
        !_sameDay(report.routines.endDate, report.period.endDate)) {
      throw StateError(
        'Los indicadores no corresponden al periodo del reporte.',
      );
    }

    for (final record in report.records) {
      final date = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );

      if (record.anonymousId != id ||
          date.isBefore(report.period.startDate) ||
          date.isAfter(report.period.endDate)) {
        throw StateError('El reporte incluye registros fuera de su alcance.');
      }
    }
  }
}
