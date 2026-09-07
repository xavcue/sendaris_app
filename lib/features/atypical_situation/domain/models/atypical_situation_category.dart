enum AtypicalSituationCategory {
  environmentChange(code: 'cambio_entorno', label: 'Cambio de entorno'),

  transitionOrTransfer(
    code: 'transicion_traslado',
    label: 'Transición o traslado',
  ),

  unexpectedEvent(code: 'evento_inesperado', label: 'Evento inesperado'),

  unusualActivity(
    code: 'actividad_no_habitual',
    label: 'Actividad no habitual',
  ),

  scheduleChange(code: 'cambio_horario', label: 'Cambio de horario'),

  externalInterruption(
    code: 'interrupcion_externa',
    label: 'Interrupción externa',
  ),

  other(code: 'otro', label: 'Otro');

  const AtypicalSituationCategory({required this.code, required this.label});

  final String code;

  final String label;

  static AtypicalSituationCategory fromCode(String code) {
    final normalizedCode = code.trim();

    for (final category in values) {
      if (category.code == normalizedCode) {
        return category;
      }
    }

    throw const FormatException('La categoría de la situación no es válida.');
  }
}
