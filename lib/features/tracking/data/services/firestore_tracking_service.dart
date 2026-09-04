import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/anonymous_tracking_profile.dart';
import '../firestore/tracking_firestore_paths.dart';
import '../mappers/anonymous_tracking_profile_mapper.dart';
import 'tracking_remote_service.dart';

class FirestoreTrackingService implements TrackingRemoteService {
  FirestoreTrackingService(this._firestore, this._firebaseAuth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {
    final uid = _requireAuthenticatedUid();

    final path = TrackingFirestorePaths.anonymousTrackingDocument(
      uid: uid,
      anonymousId: profile.anonymousId,
    );

    await _firestore
        .doc(path)
        .set(AnonymousTrackingProfileMapper.toFirestore(profile));

    await _firestore.waitForPendingWrites();
  }

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    final uid = _requireAuthenticatedUid();

    final collectionPath = TrackingFirestorePaths.anonymousTrackingCollection(
      uid,
    );

    final snapshot = await _firestore
        .collection(collectionPath)
        .orderBy('fechaCreacion')
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map(
          (document) => AnonymousTrackingProfileMapper.fromFirestore(
            anonymousId: document.id,
            data: document.data(),
          ),
        )
        .toList(growable: false);
  }

  String _requireAuthenticatedUid() {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before accessing tracking data.',
      );
    }

    return user.uid;
  }
}
