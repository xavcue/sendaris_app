import '../models/anonymous_tracking_profile.dart';
import 'anonymous_id_generator.dart';

class AnonymousTrackingProfileFactory {
  const AnonymousTrackingProfileFactory(this._idGenerator);

  final AnonymousIdGenerator _idGenerator;

  AnonymousTrackingProfile create({DateTime? createdAt, int? trackingNumber}) {
    if (trackingNumber != null && trackingNumber <= 0) {
      throw ArgumentError.value(
        trackingNumber,
        'trackingNumber',
        'Debe ser mayor que cero.',
      );
    }

    return AnonymousTrackingProfile(
      anonymousId: _idGenerator.generate(),
      createdAt: createdAt ?? DateTime.now().toUtc(),
      trackingNumber: trackingNumber,
    );
  }
}
