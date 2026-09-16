enum HistoryRecordType {
  behavior(code: 'conducta', label: 'Conducta'),
  sleep(code: 'sueno', label: 'Sueño'),
  feeding(code: 'alimentacion', label: 'Alimentación'),
  socialInteraction(code: 'interaccionSocial', label: 'Interacción social'),
  dysregulation(code: 'desregulacion', label: 'Desregulación'),
  atypicalSituation(code: 'situacionAtipica', label: 'Otra situación'),
  routineStatus(code: 'estadoRutina', label: 'Estado de rutina');

  const HistoryRecordType({required this.code, required this.label});

  final String code;
  final String label;

  static HistoryRecordType fromCode(String code) {
    for (final type in values) {
      if (type.code == code) {
        return type;
      }
    }

    throw FormatException('Tipo de registro de historial no reconocido: $code');
  }
}
