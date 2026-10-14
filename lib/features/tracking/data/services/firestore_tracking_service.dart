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

    // El UID original determina todas las rutas.
    //
    // Ademas, cualquier cambio de autenticacion invalida
    // permanentemente esta operacion, incluso si ocurre
    // una secuencia A -> B -> A.
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

      // Firestore no elimina automaticamente las
      // subcolecciones cuando se borra el documento padre.
      //
      // Se verifica el contexto antes y despues de
      // cada consulta y de cada lote de eliminacion.
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

      // El documento principal solo se elimina cuando
      // terminaron las subcolecciones y la sesion
      // original continua siendo valida.
      await _firestore.doc(trackingDocument).delete();

      requireOriginalAuthenticationContext();

      await _firestore.waitForPendingWrites();

      requireOriginalAuthenticationContext();
    } finally {
      // La escucha de cambios de autenticacion solo
      // existe durante esta operacion.
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

      // Una consulta iniciada por A puede terminar
      // despues de que se haya autenticado B.
      //
      // En ese caso no se inicia ningun borrado.
      requireAuthenticationContext();

      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      // No confirmar el lote si ya cambio la sesion.
      requireAuthenticationContext();

      await batch.commit();

      // Una vez confirmado un lote, no puede deshacerse.
      // Esta comprobacion evita comenzar el siguiente.
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
