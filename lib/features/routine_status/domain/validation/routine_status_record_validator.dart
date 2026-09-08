abstract final class RoutineStatusRecordValidator {
  static Map<String, String> validate({
    required String anonymousId,
    required String routineId,
  }) {
    final errors = <String, String>{};

    if (anonymousId.trim().isEmpty) {
      errors['anonymousId'] = 'No hay un perfil activo disponible.';
    }

    if (routineId.trim().isEmpty) {
      errors['routineId'] = 'Selecciona una rutina para continuar.';
    }

    return errors;
  }
}
