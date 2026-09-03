import '../models/anonymous_tracking_profile.dart';
import 'anonymous_id_generator.dart';

class AnonymousTrackingProfileFactory {
  const AnonymousTrackingProfileFactory(this._idGenerator);

  final AnonymousIdGenerator _idGenerator;

  AnonymousTrackingProfile create({DateTime? createdAt}) {
    return AnonymousTrackingProfile(
      anonymousId: _idGenerator.generate(),
      createdAt: createdAt ?? DateTime.now().toUtc(),
    );
  }
}
