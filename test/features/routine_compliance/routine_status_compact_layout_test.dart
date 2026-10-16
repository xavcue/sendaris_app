import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/presentation/views/routine_compliance_view.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

class _FakeRepository implements RoutineComplianceRepository {
  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    final now = DateTime.now();

    return [
      RoutineComplianceEntry(
        recordId: 'estado-completado',
        anonymousId: anonymousId,
        routineId: 'rutina-prueba',
        routineName: 'Rutina de prueba',
        date: DateTime(now.year, now.month, now.day),
        status: RoutineStatus.completed,
      ),
      RoutineComplianceEntry(
        recordId: 'estado-interrumpido',
        anonymousId: anonymousId,
        routineId: 'rutina-prueba',
        routineName: 'Rutina de prueba',
        date: DateTime(now.year, now.month, now.day),
        status: RoutineStatus.interrupted,
      ),
    ];
  }
}

void main() {
  testWidgets('la distribución presenta cuatro tarjetas compactas '
      'sin espacios excesivos', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RoutineComplianceView(
          repository: _FakeRepository(),
          anonymousId: 'perfil-a',
        ),
      ),
    );

    await tester.pumpAndSettle();

    final grid = find.byKey(const Key('routine-overview-status-grid'));

    expect(grid, findsOneWidget);

    await tester.ensureVisible(grid);
    await tester.pumpAndSettle();

    final expectedCounts = <RoutineStatus, String>{
      RoutineStatus.completed: '1',
      RoutineStatus.modified: '0',
      RoutineStatus.interrupted: '1',
      RoutineStatus.notCompleted: '0',
    };

    for (final status in RoutineStatus.values) {
      final card = find.byKey(Key('routine-overview-status-${status.name}'));

      expect(card, findsOneWidget);

      expect(tester.getSize(card).height, closeTo(104, 1));

      expect(
        find.descendant(of: card, matching: find.text(status.label)),
        findsOneWidget,
      );

      expect(
        find.descendant(of: card, matching: find.text(expectedCounts[status]!)),
        findsOneWidget,
      );
    }

    expect(find.text('50 %'), findsOneWidget);
  });
}
