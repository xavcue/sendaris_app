enum BehaviorIntensity {
  low(code: 'baja', label: 'Baja'),
  medium(code: 'media', label: 'Media'),
  high(code: 'alta', label: 'Alta');

  const BehaviorIntensity({required this.code, required this.label});

  final String code;
  final String label;

  static BehaviorIntensity fromCode(String code) {
    for (final intensity in values) {
      if (intensity.code == code) {
        return intensity;
      }
    }

    throw FormatException('Intensidad descriptiva no reconocida: $code');
  }
}
