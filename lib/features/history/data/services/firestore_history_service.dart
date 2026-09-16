import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../tracking/data/firestore/tracking_firestore_paths.dart';
import '../../domain/models/history_record.dart';
import '../mappers/history_record_mapper.dart';
import 'history_remote_service.dart';

class FirestoreHistoryService implements HistoryRemoteService {
  FirestoreHistoryService(this._firestore, this._firebaseAuth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<List<HistoryRecord>> recoverHistory({
    required String anonymousId,
  }) async {
    final uid = _requireAuthenticatedUid();

    final collectionPath = TrackingFirestorePaths.trackingRecordsCollection(
      uid: uid,
      anonymousId: anonymousId,
    );

    final snapshot = await _firestore
        .collection(collectionPath)
        .orderBy('fechaEvento', descending: true)
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map(
          (document) => HistoryRecordMapper.fromFirestore(
            recordId: document.id,
            anonymousId: anonymousId,
            data: document.data(),
          ),
        )
        .toList(growable: false);
  }

  String _requireAuthenticatedUid() {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before '
        'accessing history records.',
      );
    }

    return user.uid;
  }
}
