enum RoutineStatus {
  completed(code: 'completada', label: 'Completada'),
  modified(code: 'modificada', label: 'Modificada'),
  interrupted(code: 'interrumpida', label: 'Interrumpida'),
  notCompleted(code: 'no_realizada', label: 'No realizada');

  const RoutineStatus({required this.code, required this.label});

  final String code;
  final String label;

  static RoutineStatus fromCode(String code) {
    for (final status in values) {
      if (status.code == code) {
        return status;
      }
    }

    throw FormatException('Estado de rutina no reconocido: $code');
  }
}
