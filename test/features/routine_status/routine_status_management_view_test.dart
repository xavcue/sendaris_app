import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/routine/domain/exceptions/routine_failure.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine_status/domain/exceptions/routine_status_failure.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_management_repository.dart';
import 'package:sendaris/features/routine_status/presentation/viewmodels/routine_status_management_view_model.dart';
import 'package:sendaris/features/routine_status/presentation/views/routine_status_management_view.dart';

void main() {
  group('RoutineStatusManagementView', () {
    testWidgets(
      'muestra las rutinas agrupadas sin repetir los estados en la pantalla inicial',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 1;

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repository = _FakeRoutineStatusManagementRepository()
          ..records = [
            _record(
              recordId: 'mochila-01',
              routineId: 'rutina-mochila',
              date: DateTime(2026, 10, 1),
              status: RoutineStatus.modified,
              observation: 'Registro más reciente.',
            ),
            _record(
              recordId: 'lectura-01',
              routineId: 'rutina-lectura',
              date: DateTime(2026, 9, 30),
            ),
            _record(
              recordId: 'mochila-02',
              routineId: 'rutina-mochila',
              date: DateTime(2026, 9, 22),
              status: RoutineStatus.notCompleted,
            ),
          ];

        final routineRepository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: 'rutina-mochila',
              anonymousId: 'seguimiento-actual',
              name: 'Preparar mochila',
            ),
            Routine(
              routineId: 'rutina-lectura',
              anonymousId: 'seguimiento-actual',
              name: 'Rutina de lectura',
            ),
          ],
        );

        await _pumpView(
          tester,
          repository: repository,
          routineRepository: routineRepository,
        );

        expect(find.text('Gestión de estados de rutina'), findsOneWidget);

        expect(
          find.text('Consulta los estados registrados organizados por rutina.'),
          findsOneWidget,
        );

        expect(
          find.text(
            'Selecciona una rutina para revisar sus registros, '
            'consultarlos, editarlos o eliminarlos.',
          ),
          findsOneWidget,
        );

        expect(find.text('Rutinas con estados'), findsOneWidget);

        expect(
          find.byKey(const Key('routine-status-routine-group-rutina-mochila')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-status-routine-group-rutina-lectura')),
          findsOneWidget,
        );

        expect(find.text('Preparar mochila'), findsOneWidget);

        expect(find.text('Rutina de lectura'), findsOneWidget);

        expect(find.text('2 estados registrados'), findsOneWidget);

        expect(find.text('1 estado registrado'), findsOneWidget);

        expect(find.text('Último: 01 oct 2026'), findsOneWidget);

        expect(find.text('Último: 30 sep 2026'), findsOneWidget);

        expect(find.text('Modificada'), findsOneWidget);

        expect(
          find.byKey(const Key('routine-status-record-mochila-01')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('routine-status-filter-toggle-button')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('routine-status-new-button')),
          findsOneWidget,
        );

        final countFinder = find.byKey(
          const Key('routine-status-routine-count'),
        );

        expect(countFinder, findsOneWidget);

        expect(
          find.descendant(of: countFinder, matching: find.text('2')),
          findsOneWidget,
        );

        final countContainer = tester.widget<Container>(countFinder);

        final decoration = countContainer.decoration! as BoxDecoration;

        final countContext = tester.element(countFinder);

        final colorScheme = Theme.of(countContext).colorScheme;

        expect(
          decoration.color,
          colorScheme.primaryContainer.withValues(alpha: 0.62),
        );
      },
    );

    testWidgets('al tocar una rutina muestra únicamente sus estados', (
      tester,
    ) async {
      final repository = _FakeRoutineStatusManagementRepository()
        ..records = [
          _record(
            recordId: 'mochila-01',
            routineId: 'rutina-mochila',
            date: DateTime(2026, 10, 1),
            status: RoutineStatus.modified,
            observation: 'Registro uno.',
          ),
          _record(
            recordId: 'lectura-01',
            routineId: 'rutina-lectura',
            date: DateTime(2026, 9, 30),
          ),
          _record(
            recordId: 'mochila-02',
            routineId: 'rutina-mochila',
            date: DateTime(2026, 9, 22),
            status: RoutineStatus.notCompleted,
          ),
        ];

      final routineRepository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-mochila',
            anonymousId: 'seguimiento-actual',
            name: 'Preparar mochila',
          ),
          Routine(
            routineId: 'rutina-lectura',
            anonymousId: 'seguimiento-actual',
            name: 'Rutina de lectura',
          ),
        ],
      );

      await _pumpView(
        tester,
        repository: repository,
        routineRepository: routineRepository,
      );

      await _selectRoutine(tester, 'rutina-mochila');

      expect(
        find.byKey(const Key('routine-status-selected-routine')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-selected-routine-name')),
        findsOneWidget,
      );

      expect(find.text('Estados de la rutina'), findsOneWidget);

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(find.text('2 estados registrados'), findsOneWidget);

      expect(
        find.byKey(const Key('routine-status-record-mochila-01')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-record-mochila-02')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-record-lectura-01')),
        findsNothing,
      );

      expect(find.byKey(const Key('routine-status-new-button')), findsNothing);

      expect(
        find.byKey(const Key('routine-status-context-back-button')),
        findsOneWidget,
      );

      expect(find.text('Todas las rutinas'), findsNothing);

      expect(find.text('01 oct 2026'), findsOneWidget);

      expect(find.text('22 sep 2026'), findsOneWidget);

      expect(find.text('Registro uno.'), findsNothing);

      expect(find.text('Observación: Registro uno.'), findsOneWidget);
    });

    testWidgets(
      'la única flecha de regreso vuelve desde los estados a las rutinas agrupadas',
      (tester) async {
        final repository = _FakeRoutineStatusManagementRepository()
          ..records = [
            _record(
              recordId: 'estado-1',
              routineId: 'rutina-1',
              date: DateTime(2026, 10, 1),
            ),
          ];

        final routineRepository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: 'rutina-1',
              anonymousId: 'seguimiento-actual',
              name: 'Preparar mochila',
            ),
          ],
        );

        await _pumpView(
          tester,
          repository: repository,
          routineRepository: routineRepository,
        );

        await _selectRoutine(tester, 'rutina-1');

        expect(
          find.byKey(const Key('routine-status-selected-routine-list')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-status-context-back-button')),
          findsOneWidget,
        );

        expect(find.text('Todas las rutinas'), findsNothing);

        await tester.tap(
          find.byKey(const Key('routine-status-context-back-button')),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('routine-status-management-list')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-status-routine-group-rutina-1')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-status-record-estado-1')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('routine-status-context-back-button')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('routine-status-new-button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'el Atrás del sistema vuelve primero desde los estados a las rutinas agrupadas',
      (tester) async {
        final repository = _FakeRoutineStatusManagementRepository()
          ..records = [
            _record(
              recordId: 'estado-1',
              routineId: 'rutina-1',
              date: DateTime(2026, 10, 1),
            ),
          ];

        final routineRepository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: 'rutina-1',
              anonymousId: 'seguimiento-actual',
              name: 'Preparar mochila',
            ),
          ],
        );

        await _pumpView(
          tester,
          repository: repository,
          routineRepository: routineRepository,
        );

        await _selectRoutine(tester, 'rutina-1');

        expect(
          find.byKey(const Key('routine-status-selected-routine-list')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-status-management-list')),
          findsNothing,
        );

        await tester.binding.handlePopRoute();

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('routine-status-management-list')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-status-selected-routine-list')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('routine-status-routine-group-rutina-1')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-status-new-button')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-status-context-back-button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'el filtro solo aparece dentro de una rutina y comienza contraído',
      (tester) async {
        final repository = _FakeRoutineStatusManagementRepository()
          ..records = [
            _record(
              recordId: 'estado-1',
              routineId: 'rutina-1',
              date: DateTime(2026, 10, 1),
            ),
          ];

        final routineRepository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: 'rutina-1',
              anonymousId: 'seguimiento-actual',
              name: 'Preparar mochila',
            ),
          ],
        );

        await _pumpView(
          tester,
          repository: repository,
          routineRepository: routineRepository,
        );

        expect(
          find.byKey(const Key('routine-status-filter-toggle-button')),
          findsNothing,
        );

        await _selectRoutine(tester, 'rutina-1');

        expect(
          find.byKey(const Key('routine-status-filter-toggle-button')),
          findsOneWidget,
        );

        expect(find.text('Filtrar'), findsOneWidget);

        expect(
          find.byKey(const Key('routine-status-date-filter-card')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('routine-status-filter-toggle-button')),
        );

        await tester.pumpAndSettle();

        expect(find.text('Ocultar filtro'), findsOneWidget);

        expect(
          find.byKey(const Key('routine-status-date-filter-card')),
          findsOneWidget,
        );

        expect(find.text('Periodo'), findsOneWidget);

        expect(find.text('Desde'), findsOneWidget);

        expect(find.text('Hasta'), findsOneWidget);

        expect(find.text('Sin seleccionar'), findsNWidgets(2));
      },
    );

    testWidgets(
      'aplica filtro inclusivo dentro de la rutina y conserva Filtro activo al contraer',
      (tester) async {
        final repository = _FakeRoutineStatusManagementRepository()
          ..records = [
            _record(
              recordId: 'estado-22',
              routineId: 'rutina-1',
              date: DateTime(2026, 9, 22),
            ),
            _record(
              recordId: 'estado-21',
              routineId: 'rutina-1',
              date: DateTime(2026, 9, 21),
            ),
            _record(
              recordId: 'otra-rutina',
              routineId: 'rutina-2',
              date: DateTime(2026, 9, 22),
            ),
          ];

        final routineRepository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: 'rutina-1',
              anonymousId: 'seguimiento-actual',
              name: 'Preparar mochila',
            ),
            Routine(
              routineId: 'rutina-2',
              anonymousId: 'seguimiento-actual',
              name: 'Rutina de lectura',
            ),
          ],
        );

        await _pumpView(
          tester,
          repository: repository,
          routineRepository: routineRepository,
        );

        await _selectRoutine(tester, 'rutina-1');

        await tester.tap(
          find.byKey(const Key('routine-status-filter-toggle-button')),
        );

        await tester.pumpAndSettle();

        final viewModel = _readViewModel(tester);

        viewModel.setPendingStartDate(DateTime(2026, 9, 22));

        viewModel.setPendingEndDate(DateTime(2026, 9, 22));

        await tester.pump();

        await tester.tap(
          find.byKey(const Key('routine-status-apply-date-filter')),
        );

        await tester.pumpAndSettle();

        expect(viewModel.hasActiveDateFilter, isTrue);

        expect(
          viewModel.filteredSelectedRoutineItems
              .map((item) => item.record.recordId)
              .toList(),
          ['estado-22'],
        );

        expect(viewModel.filteredSelectedRoutineRecordCount, 1);

        final selectedRoutineList = find.byKey(
          const Key('routine-status-selected-routine-list'),
        );

        await tester.scrollUntilVisible(
          find.byKey(const Key('routine-status-record-estado-22')),
          250,
          scrollable: find.descendant(
            of: selectedRoutineList,
            matching: find.byType(Scrollable),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('routine-status-record-estado-22')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-status-record-estado-21')),
          findsNothing,
        );

        expect(find.text('1 de 2'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.byKey(const Key('routine-status-filter-toggle-button')),
          -250,
          scrollable: find.descendant(
            of: selectedRoutineList,
            matching: find.byType(Scrollable),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('routine-status-filter-toggle-button')),
        );

        await tester.pumpAndSettle();

        expect(find.text('Filtro activo'), findsOneWidget);

        expect(
          find.byKey(const Key('routine-status-date-filter-card')),
          findsNothing,
        );

        expect(viewModel.hasActiveDateFilter, isTrue);

        expect(viewModel.filteredSelectedRoutineRecordCount, 1);
      },
    );

    testWidgets('muestra validación cuando Desde es posterior a Hasta', (
      tester,
    ) async {
      final repository = _FakeRoutineStatusManagementRepository()
        ..records = [
          _record(
            recordId: 'estado-1',
            routineId: 'rutina-1',
            date: DateTime(2026, 9, 22),
          ),
        ];

      final routineRepository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-1',
            anonymousId: 'seguimiento-actual',
            name: 'Preparar mochila',
          ),
        ],
      );

      await _pumpView(
        tester,
        repository: repository,
        routineRepository: routineRepository,
      );

      await _selectRoutine(tester, 'rutina-1');

      await tester.tap(
        find.byKey(const Key('routine-status-filter-toggle-button')),
      );

      await tester.pumpAndSettle();

      final viewModel = _readViewModel(tester);

      viewModel.setPendingStartDate(DateTime(2026, 9, 23));

      viewModel.setPendingEndDate(DateTime(2026, 9, 22));

      await tester.pump();

      await tester.tap(
        find.byKey(const Key('routine-status-apply-date-filter')),
      );

      await tester.pump();

      expect(
        find.byKey(const Key('routine-status-date-filter-error')),
        findsOneWidget,
      );

      expect(
        find.text(
          'La fecha inicial no puede ser posterior '
          'a la fecha final.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('muestra estado sin resultados y permite quitar el filtro', (
      tester,
    ) async {
      final repository = _FakeRoutineStatusManagementRepository()
        ..records = [
          _record(
            recordId: 'estado-1',
            routineId: 'rutina-1',
            date: DateTime(2026, 9, 22),
          ),
        ];

      final routineRepository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-1',
            anonymousId: 'seguimiento-actual',
            name: 'Preparar mochila',
          ),
        ],
      );

      await _pumpView(
        tester,
        repository: repository,
        routineRepository: routineRepository,
      );

      await _selectRoutine(tester, 'rutina-1');

      final viewModel = _readViewModel(tester);

      viewModel.setPendingStartDate(DateTime(2026, 10, 10));

      viewModel.setPendingEndDate(DateTime(2026, 10, 10));

      expect(viewModel.applyDateFilter(), isTrue);

      await tester.pump();

      expect(
        find.byKey(const Key('routine-status-no-filter-results')),
        findsOneWidget,
      );

      expect(
        find.text('No hay estados de esta rutina en este periodo'),
        findsOneWidget,
      );

      final clearButton = find.widgetWithText(TextButton, 'Quitar filtro');

      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);

      await tester.pump();

      expect(
        find.byKey(const Key('routine-status-no-filter-results')),
        findsNothing,
      );

      expect(
        find.byKey(const Key('routine-status-record-estado-1')),
        findsOneWidget,
      );
    });

    testWidgets('Registrar estado abre la ruta nueva y recarga al volver', (
      tester,
    ) async {
      final repository = _FakeRoutineStatusManagementRepository()
        ..records = [
          _record(
            recordId: 'estado-1',
            routineId: 'rutina-1',
            date: DateTime(2026, 10, 1),
          ),
        ];

      final routineRepository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-1',
            anonymousId: 'seguimiento-actual',
            name: 'Preparar mochila',
          ),
        ],
      );

      await _pumpView(
        tester,
        repository: repository,
        routineRepository: routineRepository,
      );

      expect(repository.recoveryRequests, 1);

      await tester.tap(find.byKey(const Key('routine-status-new-button')));

      await tester.pumpAndSettle();

      expect(find.text('Destino Registrar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('destination-back-button')));

      await tester.pumpAndSettle();

      expect(repository.recoveryRequests, 2);

      expect(
        find.byKey(const Key('routine-status-routine-group-rutina-1')),
        findsOneWidget,
      );
    });

    testWidgets(
      'tocar un estado dentro de una rutina abre la ruta de detalle',
      (tester) async {
        final repository = _FakeRoutineStatusManagementRepository()
          ..records = [
            _record(
              recordId: 'estado-1',
              routineId: 'rutina-1',
              date: DateTime(2026, 10, 1),
            ),
          ];

        final routineRepository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: 'rutina-1',
              anonymousId: 'seguimiento-actual',
              name: 'Preparar mochila',
            ),
          ],
        );

        await _pumpView(
          tester,
          repository: repository,
          routineRepository: routineRepository,
        );

        await _selectRoutine(tester, 'rutina-1');

        await tester.tap(find.byKey(const Key('routine-status-open-estado-1')));

        await tester.pumpAndSettle();

        expect(find.text('Detalle estado-1'), findsOneWidget);
      },
    );

    testWidgets('el menú ofrece Editar y Eliminar y Editar recarga al volver', (
      tester,
    ) async {
      final repository = _FakeRoutineStatusManagementRepository()
        ..records = [
          _record(
            recordId: 'estado-1',
            routineId: 'rutina-1',
            date: DateTime(2026, 10, 1),
          ),
        ];

      final routineRepository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-1',
            anonymousId: 'seguimiento-actual',
            name: 'Preparar mochila',
          ),
        ],
      );

      await _pumpView(
        tester,
        repository: repository,
        routineRepository: routineRepository,
      );

      await _selectRoutine(tester, 'rutina-1');

      expect(repository.recoveryRequests, 1);

      await tester.tap(find.byKey(const Key('routine-status-menu-estado-1')));

      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);

      expect(find.text('Eliminar'), findsOneWidget);

      await tester.tap(find.text('Editar'));

      await tester.pumpAndSettle();

      expect(find.text('Editar estado-1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('destination-back-button')));

      await tester.pumpAndSettle();

      expect(repository.recoveryRequests, 2);

      expect(
        find.byKey(const Key('routine-status-selected-routine-list')),
        findsOneWidget,
      );
    });

    testWidgets(
      'eliminar confirma, muestra progreso, retira el registro y muestra éxito',
      (tester) async {
        final gate = Completer<void>();

        final repository = _FakeRoutineStatusManagementRepository()
          ..records = [
            _record(
              recordId: 'estado-eliminar',
              routineId: 'rutina-1',
              date: DateTime(2026, 10, 1),
            ),
            _record(
              recordId: 'estado-conservar',
              routineId: 'rutina-1',
              date: DateTime(2026, 9, 22),
            ),
          ]
          ..deleteGate = gate;

        final routineRepository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: 'rutina-1',
              anonymousId: 'seguimiento-actual',
              name: 'Preparar mochila',
            ),
          ],
        );

        await _pumpView(
          tester,
          repository: repository,
          routineRepository: routineRepository,
        );

        await _selectRoutine(tester, 'rutina-1');

        await tester.tap(
          find.byKey(const Key('routine-status-menu-estado-eliminar')),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Eliminar'));

        await tester.pumpAndSettle();

        expect(find.text('¿Eliminar estado de rutina?'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('confirm-delete-routine-status')),
        );

        await tester.pump();

        final deletingCard = find.byKey(
          const Key('routine-status-record-estado-eliminar'),
        );

        expect(deletingCard, findsOneWidget);

        expect(
          find.descendant(
            of: deletingCard,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        gate.complete();

        await tester.pumpAndSettle();

        expect(repository.deletedRecords, [
          (anonymousId: 'seguimiento-actual', recordId: 'estado-eliminar'),
        ]);

        expect(
          find.byKey(const Key('routine-status-record-estado-eliminar')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('routine-status-record-estado-conservar')),
          findsOneWidget,
        );

        expect(
          find.text('Estado de rutina eliminado correctamente.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'si eliminar falla conserva el registro y muestra error controlado',
      (tester) async {
        final repository = _FakeRoutineStatusManagementRepository()
          ..records = [
            _record(
              recordId: 'estado-1',
              routineId: 'rutina-1',
              date: DateTime(2026, 10, 1),
            ),
          ]
          ..deleteFailure = const RoutineStatusFailure(
            'No fue posible eliminar el estado de la rutina.',
          );

        final routineRepository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: 'rutina-1',
              anonymousId: 'seguimiento-actual',
              name: 'Preparar mochila',
            ),
          ],
        );

        await _pumpView(
          tester,
          repository: repository,
          routineRepository: routineRepository,
        );

        await _selectRoutine(tester, 'rutina-1');

        await tester.tap(find.byKey(const Key('routine-status-menu-estado-1')));

        await tester.pumpAndSettle();

        await tester.tap(find.text('Eliminar'));

        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('confirm-delete-routine-status')),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('routine-status-record-estado-1')),
          findsOneWidget,
        );

        expect(
          find.text('No fue posible eliminar el estado de la rutina.'),
          findsOneWidget,
        );

        expect(repository.deletedRecords, isEmpty);
      },
    );

    testWidgets(
      'muestra error inicial y permite reintentar hasta obtener las rutinas agrupadas',
      (tester) async {
        final repository = _FakeRoutineStatusManagementRepository()
          ..recoveryFailure = const RoutineStatusFailure('Error controlado.');

        final routineRepository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: 'rutina-1',
              anonymousId: 'seguimiento-actual',
              name: 'Preparar mochila',
            ),
          ],
        );

        await _pumpView(
          tester,
          repository: repository,
          routineRepository: routineRepository,
        );

        expect(
          find.byKey(const Key('routine-status-management-error')),
          findsOneWidget,
        );

        expect(
          find.text('No pudimos cargar los estados de rutina'),
          findsOneWidget,
        );

        expect(find.text('Error controlado.'), findsOneWidget);

        repository
          ..recoveryFailure = null
          ..records = [
            _record(
              recordId: 'estado-1',
              routineId: 'rutina-1',
              date: DateTime(2026, 10, 1),
            ),
          ];

        await tester.tap(find.byKey(const Key('routine-status-retry-button')));

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('routine-status-management-error')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('routine-status-routine-group-rutina-1')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-status-record-estado-1')),
          findsNothing,
        );
      },
    );

    testWidgets('muestra estado vacío y conserva el botón de registro', (
      tester,
    ) async {
      final repository = _FakeRoutineStatusManagementRepository();

      final routineRepository = _FakeRoutineRepository();

      await _pumpView(
        tester,
        repository: repository,
        routineRepository: routineRepository,
      );

      expect(
        find.byKey(const Key('routine-status-empty-state')),
        findsOneWidget,
      );

      expect(find.text('Aún no hay estados de rutina'), findsOneWidget);

      expect(
        find.text(
          'Cuando registres estados, las rutinas aparecerán agrupadas aquí.',
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-new-button')),
        findsOneWidget,
      );
    });

    testWidgets(
      'conserva un grupo para un estado cuya rutina ya no está disponible',
      (tester) async {
        final repository = _FakeRoutineStatusManagementRepository()
          ..records = [
            _record(
              recordId: 'estado-huerfano',
              routineId: 'rutina-eliminada',
              date: DateTime(2026, 10, 1),
            ),
          ];

        final routineRepository = _FakeRoutineRepository();

        await _pumpView(
          tester,
          repository: repository,
          routineRepository: routineRepository,
        );

        expect(
          find.byKey(
            const Key('routine-status-routine-group-rutina-eliminada'),
          ),
          findsOneWidget,
        );

        expect(find.text('Rutina no disponible'), findsOneWidget);

        expect(find.text('1 estado registrado'), findsOneWidget);

        await _selectRoutine(tester, 'rutina-eliminada');

        expect(
          find.byKey(const Key('routine-status-record-estado-huerfano')),
          findsOneWidget,
        );

        expect(find.text('Rutina no disponible'), findsOneWidget);
      },
    );

    testWidgets(
      'al eliminar el último estado de una rutina vuelve automáticamente a la agrupación',
      (tester) async {
        final repository = _FakeRoutineStatusManagementRepository()
          ..records = [
            _record(
              recordId: 'ultimo-estado',
              routineId: 'rutina-1',
              date: DateTime(2026, 10, 1),
            ),
            _record(
              recordId: 'estado-otra-rutina',
              routineId: 'rutina-2',
              date: DateTime(2026, 9, 30),
            ),
          ];

        final routineRepository = _FakeRoutineRepository(
          routines: const [
            Routine(
              routineId: 'rutina-1',
              anonymousId: 'seguimiento-actual',
              name: 'Preparar mochila',
            ),
            Routine(
              routineId: 'rutina-2',
              anonymousId: 'seguimiento-actual',
              name: 'Rutina de lectura',
            ),
          ],
        );

        await _pumpView(
          tester,
          repository: repository,
          routineRepository: routineRepository,
        );

        await _selectRoutine(tester, 'rutina-1');

        await tester.tap(
          find.byKey(const Key('routine-status-menu-ultimo-estado')),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Eliminar'));

        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('confirm-delete-routine-status')),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('routine-status-management-list')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('routine-status-selected-routine-list')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('routine-status-routine-group-rutina-1')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('routine-status-routine-group-rutina-2')),
          findsOneWidget,
        );
      },
    );
  });
}

Future<void> _pumpView(
  WidgetTester tester, {
  required _FakeRoutineStatusManagementRepository repository,
  required _FakeRoutineRepository routineRepository,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.routineStatus,
    routes: [
      GoRoute(
        path: AppRoutes.routineStatus,
        builder: (context, state) {
          return RoutineStatusManagementView(
            repository: repository,
            routineRepository: routineRepository,
            anonymousId: 'seguimiento-actual',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.routineStatusNew,
        builder: (context, state) {
          return const _DestinationView(title: 'Destino Registrar');
        },
      ),
      GoRoute(
        path: AppRoutes.routineStatusDetail,
        builder: (context, state) {
          final record = state.extra as RoutineStatusRecord;

          return _DestinationView(title: 'Detalle ${record.recordId}');
        },
      ),
      GoRoute(
        path: AppRoutes.routineStatusEdit,
        builder: (context, state) {
          final record = state.extra as RoutineStatusRecord;

          return _DestinationView(title: 'Editar ${record.recordId}');
        },
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));

  await tester.pumpAndSettle();
}

Future<void> _selectRoutine(WidgetTester tester, String routineId) async {
  await tester.tap(
    find.byKey(
      Key(
        'routine-status-open-routine-'
        '$routineId',
      ),
    ),
  );

  await tester.pumpAndSettle();
}

RoutineStatusManagementViewModel _readViewModel(WidgetTester tester) {
  final context = tester.element(
    find.byKey(const Key('routine-status-management-view')),
  );

  return Provider.of<RoutineStatusManagementViewModel>(context, listen: false);
}

RoutineStatusRecord _record({
  required String recordId,
  required String routineId,
  required DateTime date,
  String anonymousId = 'seguimiento-actual',
  RoutineStatus status = RoutineStatus.completed,
  String? observation,
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 9, 20, 18);

  return RoutineStatusRecord(
    recordId: recordId,
    anonymousId: anonymousId,
    routineId: routineId,
    date: date,
    status: status,
    observation: observation,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _DestinationView extends StatelessWidget {
  const _DestinationView({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: FilledButton(
          key: const Key('destination-back-button'),
          onPressed: () {
            context.pop();
          },
          child: const Text('Volver'),
        ),
      ),
    );
  }
}

class _FakeRoutineStatusManagementRepository
    implements RoutineStatusManagementRepository {
  List<RoutineStatusRecord> records = [];

  RoutineStatusFailure? recoveryFailure;

  RoutineStatusFailure? deleteFailure;

  Completer<void>? deleteGate;

  int recoveryRequests = 0;

  final List<({String anonymousId, String recordId})> deletedRecords = [];

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    recoveryRequests += 1;

    final failure = recoveryFailure;

    if (failure != null) {
      throw failure;
    }

    return List<RoutineStatusRecord>.from(records);
  }

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<void> updateRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<void> deleteRoutineStatus({
    required String anonymousId,
    required String recordId,
  }) async {
    final gate = deleteGate;

    if (gate != null) {
      await gate.future;
    }

    final failure = deleteFailure;

    if (failure != null) {
      throw failure;
    }

    deletedRecords.add((anonymousId: anonymousId, recordId: recordId));

    records = records
        .where((record) => record.recordId != recordId)
        .toList(growable: false);
  }
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository({this.routines = const []});

  List<Routine> routines;

  RoutineFailure? recoveryFailure;

  int recoveryRequests = 0;

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    recoveryRequests += 1;

    final failure = recoveryFailure;

    if (failure != null) {
      throw failure;
    }

    return List<Routine>.from(routines);
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
