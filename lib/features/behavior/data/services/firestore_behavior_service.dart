import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../tracking/data/firestore/tracking_firestore_paths.dart';
import '../../domain/models/behavior_record.dart';
import '../mappers/behavior_record_mapper.dart';
import 'behavior_remote_service.dart';

class FirestoreBehaviorService implements BehaviorRemoteService {
  FirestoreBehaviorService(this._firestore, this._firebaseAuth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {
    final uid = _requireAuthenticatedUid();

    final path = TrackingFirestorePaths.trackingRecordDocument(
      uid: uid,
      anonymousId: record.anonymousId,
      recordId: record.recordId,
    );

    await _firestore
        .doc(path)
        .set(
          BehaviorRecordMapper.toFirestore(record: record, operationUid: uid),
        );

    await _firestore.waitForPendingWrites();
  }

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    final uid = _requireAuthenticatedUid();

    final collectionPath = TrackingFirestorePaths.trackingRecordsCollection(
      uid: uid,
      anonymousId: anonymousId,
    );

    final snapshot = await _firestore
        .collection(collectionPath)
        .where('tipoRegistro', isEqualTo: BehaviorRecordMapper.recordType)
        .orderBy('fechaEvento', descending: true)
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map(
          (document) => BehaviorRecordMapper.fromFirestore(
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
        'accessing behavior records.',
      );
    }

    return user.uid;
  }
}
