import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_intensity.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/internal_reports/presentation/widgets/internal_report_event_card.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';

MonthlyCalendarRecord _behavior({
  String recordId = 'conducta-1',
  String owner = 'perfil-a',
  String sourceOwner = 'perfil-a',
  String sourceId = 'conducta-1',
}) {
  final date = DateTime(2026, 10, 15);

  return MonthlyCalendarRecord(
    id: recordId,
    anonymousId: owner,
    date: date,
    eventDateTime: DateTime(2026, 10, 15, 16, 53),
    type: CalendarRecordType.behavior,
    description: 'Agresión o irritabilidad',
    sourceRecord: BehaviorRecord(
      recordId: sourceId,
      anonymousId: sourceOwner,
      date: date,
      category: BehaviorCategory.aggressionIrritability,
      time: '16:53',
      durationMinutes: 12,
      intensity: BehaviorIntensity.low,
      context: 'Durante una actividad cotidiana',
      observation: 'Prueba descriptiva',
      createdAt: date,
      updatedAt: date,
    ),
  );
}

Widget _view(MonthlyCalendarRecord record) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: [
          InternalReportEventCard(record: record, anonymousId: 'perfil-a'),
        ],
      ),
    ),
  );
}

void main() {
  test('HU-16 proyecta los detalles originales de conducta', () {
    final details = InternalReportEventDetails.fromRecord(
      _behavior(),
      anonymousId: 'perfil-a',
    );

    expect(details, isNotNull);
    expect(details!.dateText, '15/10/2026 · 16:53');
    expect(details.description, 'Agresión o irritabilidad');

    expect(details.fields.map((field) => field.label).toList(), [
      'Intensidad',
      'Duración',
      'Contexto',
      'Observación',
    ]);

    expect(details.fields.map((field) => field.value).toList(), [
      'Baja',
      '12 min',
      'Durante una actividad cotidiana',
      'Prueba descriptiva',
    ]);
  });

  testWidgets('HU-16 muestra la tarjeta con información complementaria', (
    tester,
  ) async {
    await tester.pumpWidget(_view(_behavior()));

    expect(
      find.byKey(const Key('internal-report-record-behavior-conducta-1')),
      findsOneWidget,
    );

    expect(find.text('Conducta'), findsOneWidget);
    expect(find.text('Agresión o irritabilidad'), findsOneWidget);
    expect(find.text('Baja'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
    expect(find.text('Durante una actividad cotidiana'), findsOneWidget);
    expect(find.text('Prueba descriptiva'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 representa horarios de sueño', (tester) async {
    final date = DateTime(2026, 10, 15);

    final record = MonthlyCalendarRecord(
      id: 'sueno-1',
      anonymousId: 'perfil-a',
      date: date,
      type: CalendarRecordType.sleep,
      description: 'Duración registrada: 8 h',
      sourceRecord: SleepRecord(
        recordId: 'sueno-1',
        anonymousId: 'perfil-a',
        date: date,
        startTime: '22:00',
        endTime: '06:00',
        durationMinutes: 480,
        createdAt: date,
        updatedAt: date,
      ),
    );

    await tester.pumpWidget(_view(record));

    expect(find.text('Sueño'), findsOneWidget);
    expect(find.text('Duración registrada: 8 h'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('22:00'), findsOneWidget);
    expect(find.text('Fin'), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('HU-16 no incorpora datos de una fuente ajena', () {
    final details = InternalReportEventDetails.fromRecord(
      _behavior(sourceOwner: 'perfil-b'),
      anonymousId: 'perfil-a',
    );

    expect(details, isNotNull);
    expect(details!.description, 'Agresión o irritabilidad');
    expect(details.fields, isEmpty);
  });

  test('HU-16 no incorpora datos de otro identificador', () {
    final details = InternalReportEventDetails.fromRecord(
      _behavior(sourceId: 'conducta-ajena'),
      anonymousId: 'perfil-a',
    );

    expect(details, isNotNull);
    expect(details!.fields, isEmpty);
  });

  testWidgets('HU-16 oculta registros de otro seguimiento', (tester) async {
    await tester.pumpWidget(_view(_behavior(owner: 'perfil-b')));

    expect(find.text('Agresión o irritabilidad'), findsNothing);
    expect(
      find.byKey(const Key('internal-report-record-behavior-conducta-1')),
      findsNothing,
    );
  });

  testWidgets('HU-16 no representa estados de rutina como eventos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _view(
        MonthlyCalendarRecord(
          id: 'estado-1',
          anonymousId: 'perfil-a',
          date: DateTime(2026, 10, 15),
          type: CalendarRecordType.routineStatus,
          description: 'Completada',
        ),
      ),
    );

    expect(find.text('Estado de rutina'), findsNothing);
    expect(find.text('Completada'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 conserva legibilidad en pantalla compacta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_view(_behavior()));

    expect(
      find.byKey(const Key('internal-report-record-behavior-conducta-1')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });
}
