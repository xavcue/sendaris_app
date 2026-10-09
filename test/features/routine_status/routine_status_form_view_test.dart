import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_management_repository.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_factory.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_id_generator.dart';
import 'package:sendaris/features/routine_status/presentation/views/routine_status_form_view.dart';

void main() {
  testWidgets('muestra un selector compacto con las rutinas disponibles', (
    tester,
  ) async {
    final repository = _FakeRoutineStatusRepository();

    await _pumpView(
      tester,
      statusRepository: repository,
      routines: const [
        Routine(
          routineId: 'rutina-mochila',
          anonymousId: 'anonimo-test',
          name: 'Preparar mochila',
          scheduledTime: '18:00',
        ),
        Routine(
          routineId: 'rutina-lectura',
          anonymousId: 'anonimo-test',
          name: 'Rutina de lectura',
          scheduledTime: '20:00',
        ),
      ],
    );

    expect(find.byKey(const Key('routine-status-create-view')), findsOneWidget);

    expect(find.text('Registrar estado de rutina'), findsOneWidget);

    expect(find.text('Registro de estado de rutina'), findsOneWidget);

    expect(
      find.byKey(const Key('routine-status-routine-picker')),
      findsOneWidget,
    );

    expect(find.text('Preparar mochila'), findsNothing);

    expect(find.text('Rutina de lectura'), findsNothing);

    expect(find.text('Sin seleccionar'), findsNWidgets(2));

    expect(find.text('Obligatorio'), findsNWidgets(3));

    await tester.tap(find.byKey(const Key('routine-status-routine-picker')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('routine-selector-title')), findsOneWidget);

    expect(find.text('Preparar mochila'), findsOneWidget);

    expect(find.text('Rutina de lectura'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('routine-selector-option-rutina-mochila')),
    );

    await tester.pumpAndSettle();

    expect(find.text('Preparar mochila'), findsOneWidget);

    expect(find.text('18:00'), findsOneWidget);

    expect(find.text('Rutina de lectura'), findsNothing);
  });

  testWidgets('permite buscar una rutina por nombre', (tester) async {
    final repository = _FakeRoutineStatusRepository();

    await _pumpView(
      tester,
      statusRepository: repository,
      routines: const [
        Routine(
          routineId: 'rutina-desayuno',
          anonymousId: 'anonimo-test',
          name: 'Preparar desayuno',
          scheduledTime: '07:30',
        ),
        Routine(
          routineId: 'rutina-lectura',
          anonymousId: 'anonimo-test',
          name: 'Rutina de lectura',
          scheduledTime: '20:00',
        ),
        Routine(
          routineId: 'rutina-mochila',
          anonymousId: 'anonimo-test',
          name: 'Preparar mochila',
          scheduledTime: '18:00',
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('routine-status-routine-picker')));

    await tester.pumpAndSettle();

    final searchField = find.byKey(const Key('routine-selector-search-field'));

    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'lectura');

    await tester.pump();

    expect(find.text('Rutina de lectura'), findsOneWidget);

    expect(find.text('Preparar desayuno'), findsNothing);

    expect(find.text('Preparar mochila'), findsNothing);

    await tester.tap(
      find.byKey(const Key('routine-selector-option-rutina-lectura')),
    );

    await tester.pumpAndSettle();

    expect(find.text('Rutina de lectura'), findsOneWidget);

    expect(find.text('20:00'), findsOneWidget);
  });

  testWidgets('muestra estado vacío cuando la búsqueda no encuentra rutinas', (
    tester,
  ) async {
    final repository = _FakeRoutineStatusRepository();

    await _pumpView(
      tester,
      statusRepository: repository,
      routines: const [
        Routine(
          routineId: 'rutina-test',
          anonymousId: 'anonimo-test',
          name: 'Preparar mochila',
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('routine-status-routine-picker')));

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('routine-selector-search-field')),
      'inexistente',
    );

    await tester.pump();

    expect(
      find.byKey(const Key('routine-selector-empty-state')),
      findsOneWidget,
    );

    expect(find.text('No se encontraron rutinas'), findsOneWidget);
  });

  testWidgets('muestra mensaje cuando no existen rutinas disponibles', (
    tester,
  ) async {
    final repository = _FakeRoutineStatusRepository();

    await _pumpView(tester, statusRepository: repository);

    expect(find.byKey(const Key('routine-status-no-routines')), findsOneWidget);

    expect(
      find.text(
        'No hay rutinas disponibles. '
        'Crea una rutina antes de '
        'registrar su estado.',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('routine-status-save-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pump();

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('routine-status-save-button')),
    );

    expect(saveButton.onPressed, isNull);
  });

  testWidgets('los estados no muestran check y pueden deseleccionarse', (
    tester,
  ) async {
    final repository = _FakeRoutineStatusRepository();

    await _pumpView(
      tester,
      statusRepository: repository,
      routines: const [
        Routine(
          routineId: 'rutina-test',
          anonymousId: 'anonimo-test',
          name: 'Preparar mochila',
        ),
      ],
    );

    final statusChip = find.byKey(const Key('routine-status-completada'));

    await tester.scrollUntilVisible(
      statusChip,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pump();

    var chip = tester.widget<ChoiceChip>(statusChip);

    expect(chip.selected, isFalse);

    expect(chip.showCheckmark, isFalse);

    await tester.tap(statusChip);

    await tester.pump();

    chip = tester.widget<ChoiceChip>(statusChip);

    expect(chip.selected, isTrue);

    expect(chip.showCheckmark, isFalse);

    await tester.tap(statusChip);

    await tester.pump();

    chip = tester.widget<ChoiceChip>(statusChip);

    expect(chip.selected, isFalse);
  });

  testWidgets('muestra errores obligatorios temporalmente', (tester) async {
    final repository = _FakeRoutineStatusRepository();

    await _pumpView(
      tester,
      statusRepository: repository,
      routines: const [
        Routine(
          routineId: 'rutina-test',
          anonymousId: 'anonimo-test',
          name: 'Preparar mochila',
        ),
      ],
    );

    final saveButton = find.byKey(const Key('routine-status-save-button'));

    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pump();

    await tester.tap(saveButton);

    await tester.pump();

    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Selecciona una rutina.'), findsOneWidget);

    expect(find.text('Selecciona una fecha.'), findsOneWidget);

    expect(find.text('Selecciona el estado de la rutina.'), findsOneWidget);

    expect(repository.savedRecords, isEmpty);

    await tester.pump(const Duration(seconds: 5));

    await tester.pump();

    expect(find.text('Selecciona una rutina.'), findsNothing);

    expect(find.text('Selecciona una fecha.'), findsNothing);

    expect(find.text('Selecciona el estado de la rutina.'), findsNothing);
  });

  testWidgets('la observación se presenta como información opcional', (
    tester,
  ) async {
    final repository = _FakeRoutineStatusRepository();

    await _pumpView(
      tester,
      statusRepository: repository,
      routines: const [
        Routine(
          routineId: 'rutina-test',
          anonymousId: 'anonimo-test',
          name: 'Preparar mochila',
        ),
      ],
    );

    final observation = find.byKey(
      const Key('routine-status-observation-field'),
    );

    await tester.scrollUntilVisible(
      observation,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pump();

    expect(observation, findsOneWidget);

    expect(find.text('Observación (opcional)'), findsOneWidget);

    expect(
      find.text(
        'Añade información descriptiva '
        'complementaria solo si es necesaria.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'guarda correctamente usando una rutina seleccionada desde el modal',
    (tester) async {
      final repository = _FakeRoutineStatusRepository();

      await _pumpView(
        tester,
        statusRepository: repository,
        routines: const [
          Routine(
            routineId: 'rutina-test',
            anonymousId: 'anonimo-test',
            name: 'Preparar mochila',
            scheduledTime: '18:00',
          ),
        ],
      );

      await tester.tap(find.byKey(const Key('routine-status-routine-picker')));

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('routine-selector-option-rutina-test')),
      );

      await tester.pumpAndSettle();

      final datePicker = find.byKey(const Key('routine-status-date-picker'));

      await tester.tap(datePicker);

      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Seleccionar').last);

      await tester.pumpAndSettle();

      final completedChip = find.byKey(const Key('routine-status-completada'));

      await tester.scrollUntilVisible(
        completedChip,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(completedChip);

      await tester.pump();

      final observation = find.byKey(
        const Key('routine-status-observation-field'),
      );

      await tester.scrollUntilVisible(
        observation,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.enterText(observation, 'Registro ficticio descriptivo.');

      final saveButton = find.byKey(const Key('routine-status-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(saveButton);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 400));

      expect(repository.savedRecords, hasLength(1));

      final record = repository.savedRecords.single;

      expect(record.routineId, 'rutina-test');

      expect(record.status, RoutineStatus.completed);

      expect(record.observation, 'Registro ficticio descriptivo.');

      expect(find.text('Destino Registrar'), findsOneWidget);

      expect(
        find.text('Estado de rutina guardado correctamente.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('precarga rutina fecha estado y observación al editar', (
    tester,
  ) async {
    final initialRecord = _record(
      recordId: 'estado-editar',
      routineId: 'rutina-test',
      date: DateTime(2026, 9, 20),
      status: RoutineStatus.modified,
      observation: 'Horario ajustado.',
    );

    final repository = _FakeRoutineStatusRepository()
      ..existingRecords = [initialRecord];

    await _pumpView(
      tester,
      statusRepository: repository,
      initialRecord: initialRecord,
      routines: const [
        Routine(
          routineId: 'rutina-test',
          anonymousId: 'anonimo-test',
          name: 'Preparar mochila',
          scheduledTime: '18:00',
        ),
        Routine(
          routineId: 'rutina-2',
          anonymousId: 'anonimo-test',
          name: 'Rutina de lectura',
        ),
      ],
    );

    expect(find.byKey(const Key('routine-status-edit-view')), findsOneWidget);

    expect(find.text('Editar registro de estado de rutina'), findsOneWidget);

    expect(
      find.text('Actualizar registro de estado de rutina'),
      findsOneWidget,
    );

    expect(find.text('Preparar mochila'), findsOneWidget);

    expect(find.text('20 sep 2026'), findsOneWidget);

    final modifiedChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('routine-status-modificada')),
    );

    expect(modifiedChip.selected, isTrue);

    expect(modifiedChip.showCheckmark, isFalse);

    final observationFinder = find.byKey(
      const Key('routine-status-observation-field'),
    );

    await tester.scrollUntilVisible(
      observationFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pump();

    final observationField = tester.widget<TextField>(observationFinder);

    expect(observationField.controller?.text, 'Horario ajustado.');

    await tester.scrollUntilVisible(
      find.byKey(const Key('routine-status-save-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pump();

    expect(find.text('Guardar cambios'), findsOneWidget);
  });

  testWidgets('actualiza un estado existente sin crear un registro nuevo', (
    tester,
  ) async {
    final initialRecord = _record(
      recordId: 'estado-editar',
      routineId: 'rutina-test',
      date: DateTime(2026, 9, 20),
      status: RoutineStatus.completed,
      observation: 'Observación original.',
      createdAt: DateTime.utc(2026, 9, 20, 12),
    );

    final repository = _FakeRoutineStatusRepository()
      ..existingRecords = [initialRecord];

    await _pumpView(
      tester,
      statusRepository: repository,
      initialRecord: initialRecord,
      routines: const [
        Routine(
          routineId: 'rutina-test',
          anonymousId: 'anonimo-test',
          name: 'Preparar mochila',
          scheduledTime: '18:00',
        ),
      ],
    );

    final observation = find.byKey(
      const Key('routine-status-observation-field'),
    );

    await tester.scrollUntilVisible(
      observation,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.enterText(observation, 'Observación actualizada.');

    final saveButton = find.byKey(const Key('routine-status-save-button'));

    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(saveButton);

    await tester.pump();

    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.savedRecords, isEmpty);

    expect(repository.updatedRecords, hasLength(1));

    final updated = repository.updatedRecords.single;

    expect(updated.recordId, initialRecord.recordId);

    expect(updated.anonymousId, initialRecord.anonymousId);

    expect(updated.createdAt, initialRecord.createdAt);

    expect(updated.routineId, 'rutina-test');

    expect(updated.date, DateTime(2026, 9, 20));

    expect(updated.status, RoutineStatus.completed);

    expect(updated.observation, 'Observación actualizada.');

    expect(find.text('Destino Registrar'), findsOneWidget);

    expect(
      find.text('Estado de rutina actualizado correctamente.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpView(
  WidgetTester tester, {
  required _FakeRoutineStatusRepository statusRepository,
  List<Routine> routines = const [],
  RoutineStatusRecord? initialRecord,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-routine-status-form'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RoutineStatusFormView(
                        routineRepository: _FakeRoutineRepository(routines),
                        routineStatusRepository: statusRepository,
                        recordFactory: const RoutineStatusRecordFactory(
                          _FakeRoutineStatusRecordIdGenerator(),
                        ),
                        anonymousId: 'anonimo-test',
                        initialRecord: initialRecord,
                      ),
                    ),
                  );
                },
                child: const Text('Destino Registrar'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.byKey(const Key('open-routine-status-form')));

  await tester.pumpAndSettle();
}

RoutineStatusRecord _record({
  required String recordId,
  required String routineId,
  required DateTime date,
  RoutineStatus status = RoutineStatus.completed,
  String? observation,
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 9, 20, 12);

  return RoutineStatusRecord(
    recordId: recordId,
    anonymousId: 'anonimo-test',
    routineId: routineId,
    date: date,
    status: status,
    observation: observation,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository(this.routines);

  final List<Routine> routines;

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return routines;
  }

  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deleteRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}

class _FakeRoutineStatusRepository
    implements RoutineStatusManagementRepository {
  final List<RoutineStatusRecord> savedRecords = [];

  final List<RoutineStatusRecord> updatedRecords = [];

  List<RoutineStatusRecord> existingRecords = [];

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    return List.unmodifiable(existingRecords);
  }

  @override
  Future<void> updateRoutineStatus(RoutineStatusRecord record) async {
    updatedRecords.add(record);
  }

  @override
  Future<void> deleteRoutineStatus({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeRoutineStatusRecordIdGenerator
    implements RoutineStatusRecordIdGenerator {
  const _FakeRoutineStatusRecordIdGenerator();

  @override
  String generate() {
    return 'routine-status-test-id';
  }
}
