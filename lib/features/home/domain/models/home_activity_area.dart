enum HomeActivityArea {
  behavior(code: 'conducta', label: 'Conducta'),

  sleep(code: 'sueno', label: 'Sueño'),

  feeding(code: 'alimentacion', label: 'Alimentación'),

  socialInteraction(code: 'interaccion_social', label: 'Interacción social'),

  dysregulation(code: 'desregulacion', label: 'Desregulación'),

  otherSituation(code: 'otra_situacion', label: 'Otra situación'),

  routines(code: 'rutinas', label: 'Rutinas');

  const HomeActivityArea({required this.code, required this.label});

  final String code;

  final String label;
}
