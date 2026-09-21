class AnonymousTrackingProfile {
  const AnonymousTrackingProfile({
    required this.anonymousId,
    required this.createdAt,
    this.trackingNumber,
    this.isActive = true,
  });

  final String anonymousId;
  final DateTime createdAt;

  /// Número técnico utilizado únicamente para mostrar etiquetas estables como
  /// "Seguimiento 1", "Seguimiento 2", etc.
  ///
  /// No identifica a la persona y no se muestra como dato técnico.
  final int? trackingNumber;

  final bool isActive;
}
