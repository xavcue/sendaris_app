import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/anonymous_tracking_profile.dart';
import '../firestore/tracking_firestore_paths.dart';
import '../mappers/anonymous_tracking_profile_mapper.dart';
import 'tracking_deletion_remote_service.dart';
import 'tracking_remote_service.dart';

class FirestoreTrackingService
    implements TrackingRemoteService, TrackingDeletionRemoteService {
  FirestoreTrackingService(this._firestore, this._firebaseAuth);

  static const int _deleteBatchSize = 400;

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

  @override
  Future<void> deleteProfile(String anonymousId) async {
    final uid = _requireAuthenticatedUid();

    final trackingDocument = TrackingFirestorePaths.anonymousTrackingDocument(
      uid: uid,
      anonymousId: anonymousId,
    );

    final recordsCollection = TrackingFirestorePaths.trackingRecordsCollection(
      uid: uid,
      anonymousId: anonymousId,
    );

    final routinesCollection = TrackingFirestorePaths.routinesCollection(
      uid: uid,
      anonymousId: anonymousId,
    );

    // Firestore no elimina subcolecciones automáticamente al borrar
    // el documento padre. Primero eliminamos los documentos que
    // actualmente pertenecen al seguimiento.
    await _deleteCollection(recordsCollection);

    await _deleteCollection(routinesCollection);

    // El documento principal se elimina únicamente después de que sus
    // colecciones funcionales se hayan eliminado correctamente.
    await _firestore.doc(trackingDocument).delete();

    await _firestore.waitForPendingWrites();
  }

  Future<void> _deleteCollection(String collectionPath) async {
    while (true) {
      final snapshot = await _firestore
          .collection(collectionPath)
          .limit(_deleteBatchSize)
          .get(const GetOptions(source: Source.server));

      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      await batch.commit();

      if (snapshot.docs.length < _deleteBatchSize) {
        return;
      }
    }
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
