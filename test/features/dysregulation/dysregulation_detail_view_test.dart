import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/presentation/views/dysregulation_detail_view.dart';

void main() {
  group('DysregulationDetailView', () {
    testWidgets(
      'muestra todos los datos funcionales sin exponer identificadores',
      (tester) async {
        await _pumpView(tester, _record());

        expect(find.text('Detalle de desregulación'), findsOneWidget);

        expect(find.text('Registro de desregulación'), findsOneWidget);

        expect(find.text('Episodio de desregulación'), findsOneWidget);

        expect(find.text('22 sep 2026 · 14:30'), findsOneWidget);

        expect(find.text('Fecha'), findsOneWidget);

        expect(find.text('22 sep 2026'), findsOneWidget);

        expect(find.text('Hora'), findsOneWidget);

        expect(find.text('14:30'), findsOneWidget);

        expect(find.text('Duración'), findsOneWidget);

        expect(find.text('12 min'), findsOneWidget);

        expect(find.text('Intensidad descriptiva'), findsOneWidget);

        expect(find.text('Media'), findsOneWidget);

        expect(find.text('Contexto general'), findsOneWidget);

        expect(find.text('Actividad cotidiana'), findsOneWidget);

        expect(find.text('Observación'), findsOneWidget);

        expect(find.text('Registro ficticio descriptivo.'), findsOneWidget);

        expect(find.text('desregulacion-1'), findsNothing);

        expect(find.text('seguimiento-actual'), findsNothing);

        expect(find.textContaining('UUID'), findsNothing);

        expect(find.textContaining('identificador'), findsNothing);
      },
    );

    testWidgets(
      'muestra valores descriptivos cuando los campos opcionales no existen',
      (tester) async {
        await _pumpView(
          tester,
          _record(
            time: null,
            durationMinutes: null,
            intensity: null,
            context: null,
            observation: null,
          ),
        );

        expect(find.text('Sin hora'), findsOneWidget);

        expect(find.text('Sin duración'), findsOneWidget);

        expect(find.text('Sin intensidad'), findsOneWidget);

        expect(find.text('Sin contexto'), findsOneWidget);

        expect(find.text('Sin observación'), findsOneWidget);
      },
    );

    testWidgets('muestra correctamente una duración igual a cero', (
      tester,
    ) async {
      await _pumpView(tester, _record(durationMinutes: 0));

      expect(find.text('0 min'), findsOneWidget);

      expect(find.text('Sin duración'), findsNothing);
    });
  });
}

Future<void> _pumpView(WidgetTester tester, DysregulationRecord record) async {
  await tester.binding.setSurfaceSize(const Size(900, 1800));

  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(home: DysregulationDetailView(record: record)),
  );

  await tester.pumpAndSettle();
}

DysregulationRecord _record({
  String? time = '14:30',
  int? durationMinutes = 12,
  DysregulationIntensity? intensity = DysregulationIntensity.medium,
  String? context = 'Actividad cotidiana',
  String? observation = 'Registro ficticio descriptivo.',
}) {
  return DysregulationRecord(
    recordId: 'desregulacion-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    time: time,
    durationMinutes: durationMinutes,
    intensity: intensity,
    context: context,
    observation: observation,
    createdAt: DateTime.utc(2026, 9, 22, 18),
    updatedAt: DateTime.utc(2026, 9, 22, 18),
  );
}
