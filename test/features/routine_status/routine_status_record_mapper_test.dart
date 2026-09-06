import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_status/data/mappers/routine_status_record_mapper.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';

void main() {
  group('RoutineStatusRecordMapper', () {
    test('convierte un estado válido a la estructura Firestore', () {
      final record = RoutineStatusRecord(
        recordId: 'registro-test',
        anonymousId: 'anonimo-test',
        routineId: 'rutina-test',
        date: DateTime(2026, 9, 6),
        status: RoutineStatus.completed,
        observation: 'Actividad realizada',
        createdAt: DateTime.utc(2026, 9, 6, 18),
        updatedAt: DateTime.utc(2026, 9, 6, 18),
      );

      final data = RoutineStatusRecordMapper.toFirestore(
        record: record,
        operationUid: 'usuario-test',
      );

      expect(data['tipoRegistro'], 'estadoRutina');

      expect(data['uidOperacion'], 'usuario-test');

      final statusData = Map<String, dynamic>.from(data['datos'] as Map);

      expect(statusData['idRutina'], 'rutina-test');

      expect(statusData['estado'], 'completada');

      expect(statusData['observacion'], 'Actividad realizada');

      expect(data.containsKey('anonymousId'), isFalse);

      expect(data.containsKey('recordId'), isFalse);
    });

    test('omite observación cuando no aplica', () {
      final record = RoutineStatusRecord(
        recordId: 'registro-test',
        anonymousId: 'anonimo-test',
        routineId: 'rutina-test',
        date: DateTime(2026, 9, 6),
        status: RoutineStatus.modified,
        createdAt: DateTime.utc(2026, 9, 6),
        updatedAt: DateTime.utc(2026, 9, 6),
      );

      final data = RoutineStatusRecordMapper.toFirestore(
        record: record,
        operationUid: 'usuario-test',
      );

      final statusData = Map<String, dynamic>.from(data['datos'] as Map);

      expect(statusData.containsKey('observacion'), isFalse);
    });

    test('reconstruye un estado válido desde Firestore', () {
      final date = Timestamp.fromDate(DateTime.utc(2026, 9, 6));

      final createdAt = Timestamp.fromDate(DateTime.utc(2026, 9, 6, 18));

      final record = RoutineStatusRecordMapper.fromFirestore(
        recordId: 'registro-test',
        anonymousId: 'anonimo-test',
        data: {
          'tipoRegistro': 'estadoRutina',
          'fechaEvento': date,
          'fechaCreacion': createdAt,
          'fechaActualizacion': createdAt,
          'uidOperacion': 'usuario-test',
          'datos': {
            'fecha': date,
            'idRutina': 'rutina-test',
            'estado': 'interrumpida',
            'observacion': 'Cambio de actividad',
          },
        },
      );

      expect(record.routineId, 'rutina-test');

      expect(record.status, RoutineStatus.interrupted);

      expect(record.observation, 'Cambio de actividad');
    });

    test('rechaza un estado fuera del catálogo', () {
      final date = Timestamp.fromDate(DateTime.utc(2026, 9, 6));

      expect(
        () => RoutineStatusRecordMapper.fromFirestore(
          recordId: 'registro-test',
          anonymousId: 'anonimo-test',
          data: {
            'tipoRegistro': 'estadoRutina',
            'fechaEvento': date,
            'fechaCreacion': date,
            'fechaActualizacion': date,
            'uidOperacion': 'usuario-test',
            'datos': {
              'fecha': date,
              'idRutina': 'rutina-test',
              'estado': 'invalido',
            },
          },
        ),
        throwsFormatException,
      );
    });

    test('rechaza campos adicionales no permitidos', () {
      final date = Timestamp.fromDate(DateTime.utc(2026, 9, 6));

      expect(
        () => RoutineStatusRecordMapper.fromFirestore(
          recordId: 'registro-test',
          anonymousId: 'anonimo-test',
          data: {
            'tipoRegistro': 'estadoRutina',
            'fechaEvento': date,
            'fechaCreacion': date,
            'fechaActualizacion': date,
            'uidOperacion': 'usuario-test',
            'datos': {
              'fecha': date,
              'idRutina': 'rutina-test',
              'estado': 'completada',
              'nombreNino': 'Dato no permitido',
            },
          },
        ),
        throwsFormatException,
      );
    });
  });
}
