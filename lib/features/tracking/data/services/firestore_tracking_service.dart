import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/anonymous_tracking_profile.dart';
import '../firestore/tracking_firestore_paths.dart';
import '../mappers/anonymous_tracking_profile_mapper.dart';
import 'tracking_deletion_remote_service.dart';
import 'tracking_observation_remote_service.dart';
import 'tracking_observation_snapshot_policy.dart';
import 'tracking_remote_service.dart';

class FirestoreTrackingService
    implements
        TrackingRemoteService,
        TrackingDeletionRemoteService,
        TrackingObservationRemoteService {
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
  Stream<List<AnonymousTrackingProfile>> watchProfiles() {
    final uid = _requireAuthenticatedUid();

    final collectionPath = TrackingFirestorePaths.anonymousTrackingCollection(
      uid,
    );

    StreamSubscription<User?>? identitySubscription;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    profilesSubscription;

    late final StreamController<List<AnonymousTrackingProfile>> controller;

    var terminated = false;

    Future<void> cancelSubscriptions() async {
      final identity = identitySubscription;
      final profiles = profilesSubscription;

      identitySubscription = null;
      profilesSubscription = null;

      await profiles?.cancel();
      await identity?.cancel();
    }

    void terminateWithError(Object error, StackTrace stackTrace) {
      if (terminated) {
        return;
      }

      terminated = true;

      if (!controller.isClosed) {
        controller.addError(error, stackTrace);
        unawaited(controller.close());
      }

      unawaited(cancelSubscriptions());
    }

    void invalidateAuthenticationContext() {
      terminateWithError(
        StateError('Authentication changed during tracking observation.'),
        StackTrace.current,
      );
    }

    bool isAuthenticationContextValid() {
      if (terminated) {
        return false;
      }

      if (_firebaseAuth.currentUser?.uid != uid) {
        invalidateAuthenticationContext();
        return false;
      }

      return true;
    }

    controller = StreamController<List<AnonymousTrackingProfile>>(
      onListen: () {
        if (!isAuthenticationContextValid()) {
          return;
        }

        // La escucha está vinculada al UID original.
        // Un cambio A -> B -> A invalida la suscripción anterior.
        identitySubscription = _firebaseAuth.authStateChanges().listen(
          (user) {
            if (user?.uid != uid) {
              invalidateAuthenticationContext();
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            terminateWithError(error, stackTrace);
          },
        );

        if (!isAuthenticationContextValid()) {
          return;
        }

        profilesSubscription = _firestore
            .collection(collectionPath)
            .orderBy('fechaCreacion')
            .snapshots(includeMetadataChanges: true)
            .listen(
              (snapshot) {
                if (!isAuthenticationContextValid()) {
                  return;
                }

                // Solo se aceptan datos confirmados por el
                // servidor y sin escrituras locales pendientes.
                //
                // Esta política evita aplicar instantáneas de
                // caché potencialmente obsoletas.
                final metadata = snapshot.metadata;

                final shouldEmit = TrackingObservationSnapshotPolicy.shouldEmit(
                  isFromCache: metadata.isFromCache,
                  hasPendingWrites: metadata.hasPendingWrites,
                );

                if (!shouldEmit) {
                  return;
                }

                try {
                  final profiles = snapshot.docs
                      .map(
                        (document) =>
                            AnonymousTrackingProfileMapper.fromFirestore(
                              anonymousId: document.id,
                              data: document.data(),
                            ),
                      )
                      .toList(growable: false);

                  if (isAuthenticationContextValid()) {
                    controller.add(profiles);
                  }
                } catch (error, stackTrace) {
                  terminateWithError(error, stackTrace);
                }
              },
              onError: (Object error, StackTrace stackTrace) {
                terminateWithError(error, stackTrace);
              },
              onDone: () {
                if (!controller.isClosed) {
                  unawaited(controller.close());
                }

                unawaited(cancelSubscriptions());
              },
            );
      },
      onCancel: cancelSubscriptions,
    );

    return controller.stream;
  }

  @override
  Future<void> deleteProfile(String anonymousId) async {
    final uid = _requireAuthenticatedUid();

    // El UID original determina todas las rutas.
    // Cualquier cambio de autenticación invalida
    // permanentemente la operación, incluso A -> B -> A.
    var authenticationContextChanged = false;

    final subscription = _firebaseAuth.authStateChanges().listen((user) {
      if (user?.uid != uid) {
        authenticationContextChanged = true;
      }
    });

    void requireOriginalAuthenticationContext() {
      if (authenticationContextChanged ||
          _firebaseAuth.currentUser?.uid != uid) {
        throw StateError('Authentication changed during tracking deletion.');
      }
    }

    try {
      requireOriginalAuthenticationContext();

      final trackingDocument = TrackingFirestorePaths.anonymousTrackingDocument(
        uid: uid,
        anonymousId: anonymousId,
      );

      final recordsCollection =
          TrackingFirestorePaths.trackingRecordsCollection(
            uid: uid,
            anonymousId: anonymousId,
          );

      final routinesCollection = TrackingFirestorePaths.routinesCollection(
        uid: uid,
        anonymousId: anonymousId,
      );

      // Firestore no elimina automáticamente las
      // subcolecciones al eliminar el documento padre.
      await _deleteCollection(
        recordsCollection,
        requireAuthenticationContext: requireOriginalAuthenticationContext,
      );

      requireOriginalAuthenticationContext();

      await _deleteCollection(
        routinesCollection,
        requireAuthenticationContext: requireOriginalAuthenticationContext,
      );

      requireOriginalAuthenticationContext();

      // El documento principal se elimina únicamente
      // después de procesar las subcolecciones.
      await _firestore.doc(trackingDocument).delete();

      requireOriginalAuthenticationContext();

      await _firestore.waitForPendingWrites();

      requireOriginalAuthenticationContext();
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _deleteCollection(
    String collectionPath, {
    required void Function() requireAuthenticationContext,
  }) async {
    while (true) {
      requireAuthenticationContext();

      final snapshot = await _firestore
          .collection(collectionPath)
          .limit(_deleteBatchSize)
          .get(const GetOptions(source: Source.server));

      requireAuthenticationContext();

      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      requireAuthenticationContext();

      await batch.commit();

      requireAuthenticationContext();

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
