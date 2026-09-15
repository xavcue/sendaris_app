enum DysregulationIntensity {
  low(code: 'baja', label: 'Baja'),
  medium(code: 'media', label: 'Media'),
  high(code: 'alta', label: 'Alta');

  const DysregulationIntensity({required this.code, required this.label});

  final String code;
  final String label;

  static DysregulationIntensity fromCode(String code) {
    for (final intensity in values) {
      if (intensity.code == code) {
        return intensity;
      }
    }

    throw FormatException(
      'Intensidad descriptiva de desregulación no reconocida: $code',
    );
  }
}
