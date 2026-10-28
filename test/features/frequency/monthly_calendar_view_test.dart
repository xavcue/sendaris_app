import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/frequency/data/repositories/composite_monthly_calendar_repository.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/views/monthly_calendar_view.dart';

class _FakeRepository implements MonthlyCalendarRepository {
  final Map<String, Completer<MonthlyCalendarIndex>> completers = {};

  @override
  Future<MonthlyCalendarIndex> recover({required String anonymousId}) {
    return completers
        .putIfAbsent(anonymousId, () => Completer<MonthlyCalendarIndex>())
        .future;
  }
}

MonthlyCalendarIndex _index(String anonymousId, DateTime day, int count) {
  return MonthlyCalendarIndex(
    anonymousId: anonymousId,
    records: [
      for (var i = 0; i < count; i++)
        MonthlyCalendarRecord(
          id: '$anonymousId-$i',
          anonymousId: anonymousId,
          date: day,
          type: CalendarRecordType.behavior,
          description: 'Registro de prueba',
        ),
    ],
  );
}

void main() {
  testWidgets('muestra el calendario y mantiene filtros contraídos', (
    tester,
  ) async {
    final now = DateTime.now();
    final repository = _FakeRepository();

    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyCalendarView(repository: repository, anonymousId: 'a'),
      ),
    );

    repository.completers['a']!.complete(_index('a', now, 2));

    await tester.pumpAndSettle();

    expect(find.textContaining('2 registros en'), findsOneWidget);

    expect(find.byKey(const Key('monthly-calendar-day-1')), findsOneWidget);

    expect(
      find.byKey(const Key('monthly-calendar-filter-toggle')),
      findsOneWidget,
    );

    // Al iniciar, los filtros deben permanecer contraídos.
    expect(
      find.byKey(const Key('monthly-calendar-type-behavior')),
      findsNothing,
    );

    expect(find.text('Consulta avanzada de frecuencias'), findsNothing);

    // Expandir los filtros sin modificar los registros.
    await tester.tap(find.byKey(const Key('monthly-calendar-filter-toggle')));

    await tester.pumpAndSettle();

    final mainScrollable = find.byType(Scrollable).first;

    // Los filtros ahora se encuentran debajo de los
    // registros del día y de la tarjeta de cobertura.
    // La prueba debe desplazarse hasta ellos.
    await tester.scrollUntilVisible(
      find.byKey(const Key('monthly-calendar-start-date-button')),
      200,
      scrollable: mainScrollable,
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('monthly-calendar-start-date-button')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('monthly-calendar-end-date-button')),
      findsOneWidget,
    );

    // Desplazarse hasta los filtros de tipos.
    await tester.scrollUntilVisible(
      find.byKey(const Key('monthly-calendar-type-behavior')),
      200,
      scrollable: mainScrollable,
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('monthly-calendar-type-behavior')),
      findsOneWidget,
    );

    // La expansión de filtros no modifica el conteo.
    expect(find.textContaining('2 registros en'), findsOneWidget);
  });

  testWidgets('descarta respuestas antiguas al cambiar de seguimiento', (
    tester,
  ) async {
    final now = DateTime.now();
    final repository = _FakeRepository();

    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyCalendarView(repository: repository, anonymousId: 'a'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyCalendarView(repository: repository, anonymousId: 'b'),
      ),
    );

    repository.completers['b']!.complete(_index('b', now, 1));

    await tester.pumpAndSettle();

    expect(find.textContaining('1 registro en'), findsOneWidget);

    repository.completers['a']!.complete(_index('a', now, 5));

    await tester.pumpAndSettle();

    expect(find.textContaining('5 registros en'), findsNothing);

    expect(find.textContaining('1 registro en'), findsOneWidget);
  });

  testWidgets('envía el registro original a la ruta de detalle', (
    tester,
  ) async {
    final now = DateTime.now();
    final repository = _FakeRepository();

    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return MonthlyCalendarView(
              repository: repository,
              anonymousId: 'a',
            );
          },
        ),
        GoRoute(
          path: AppRoutes.behaviorDetail,
          builder: (context, state) {
            return Scaffold(
              appBar: AppBar(title: const Text('Detalle de conducta')),
              body: Center(child: Text('${state.extra}')),
            );
          },
        ),
      ],
    );

    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    repository.completers['a']!.complete(
      MonthlyCalendarIndex(
        anonymousId: 'a',
        records: [
          MonthlyCalendarRecord(
            id: 'registro-1',
            anonymousId: 'a',
            date: now,
            type: CalendarRecordType.behavior,
            description: 'Conducta registrada',
            sourceRecord: 'registro-original',
          ),
        ],
      ),
    );

    await tester.pumpAndSettle();

    final recordFinder = find.byKey(
      const Key('monthly-calendar-record-behavior-registro-1'),
    );

    await tester.ensureVisible(recordFinder);
    await tester.pumpAndSettle();

    await tester.tap(recordFinder);
    await tester.pumpAndSettle();

    expect(find.text('Detalle de conducta'), findsOneWidget);

    expect(find.text('registro-original'), findsOneWidget);
  });
}
