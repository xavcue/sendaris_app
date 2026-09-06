import '../../domain/models/routine.dart';
import '../../domain/validation/routine_validator.dart';

abstract final class RoutineMapper {
  static const Set<String> allowedFields = {
    'nombre',
    'descripcion',
    'horaProgramada',
    'recurrencia',
    'activa',
  };

  static Map<String, dynamic> toFirestore(Routine routine) {
    final data = <String, dynamic>{
      'nombre': routine.name,
      'activa': routine.isActive,
    };

    final description = routine.description;

    if (description != null) {
      data['descripcion'] = description;
    }

    final scheduledTime = routine.scheduledTime;

    if (scheduledTime != null) {
      data['horaProgramada'] = scheduledTime;
    }

    final recurrence = routine.recurrence;

    if (recurrence != null) {
      data['recurrencia'] = recurrence;
    }

    return data;
  }

  static Routine fromFirestore({
    required String routineId,
    required String anonymousId,
    required Map<String, dynamic> data,
  }) {
    final keys = data.keys.toSet();

    if (!keys.contains('nombre') ||
        !keys.contains('activa') ||
        !allowedFields.containsAll(keys)) {
      throw const FormatException(
        'La rutina contiene una estructura no permitida.',
      );
    }

    final rawName = data['nombre'];
    final rawDescription = data['descripcion'];
    final rawScheduledTime = data['horaProgramada'];
    final rawRecurrence = data['recurrencia'];
    final rawIsActive = data['activa'];

    if (rawName is! String || rawName.trim().isEmpty) {
      throw const FormatException('El nombre de la rutina no es válido.');
    }

    if (rawDescription != null &&
        (rawDescription is! String || rawDescription.trim().isEmpty)) {
      throw const FormatException('La descripción de la rutina no es válida.');
    }

    if (rawScheduledTime != null && rawScheduledTime is! String) {
      throw const FormatException(
        'La hora programada de la rutina no es válida.',
      );
    }

    if (rawRecurrence != null && rawRecurrence is! String) {
      throw const FormatException('La recurrencia de la rutina no es válida.');
    }

    if (rawIsActive is! bool) {
      throw const FormatException('El estado de la rutina no es válido.');
    }

    final scheduledTime = rawScheduledTime as String?;

    final recurrence = rawRecurrence as String?;

    final validationErrors = RoutineValidator.validate(
      anonymousId: anonymousId,
      name: rawName,
      scheduledTime: scheduledTime,
      recurrence: recurrence,
    );

    if (validationErrors.isNotEmpty) {
      throw const FormatException(
        'La rutina recuperada contiene datos no válidos.',
      );
    }

    return Routine(
      routineId: routineId,
      anonymousId: anonymousId,
      name: rawName.trim(),
      description: (rawDescription as String?)?.trim(),
      scheduledTime: scheduledTime,
      recurrence: recurrence,
      isActive: rawIsActive,
    );
  }
}
