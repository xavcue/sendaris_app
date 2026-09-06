abstract final class RoutineStatusRecordValidator {
  static Map<String, String> validate({
    required String anonymousId,
    required String routineId,
  }) {
    final errors = <String, String>{};

    if (anonymousId.trim().isEmpty) {
      errors['anonymousId'] = 'El seguimiento anónimo es obligatorio.';
    }

    if (routineId.trim().isEmpty) {
      errors['routineId'] = 'La rutina seleccionada es obligatoria.';
    }

    return errors;
  }
}
