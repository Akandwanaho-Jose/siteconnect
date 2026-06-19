import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/community_feedback.dart';
import '../constants/firestore_collections.dart';
import '../constants/firestore_enums.dart';
import 'firestore_repository.dart';

class CommunityFeedbackRepository
    extends FirestoreRepository<CommunityFeedback> {
  CommunityFeedbackRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.communityFeedback);

  @override
  CommunityFeedback fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return CommunityFeedback.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(CommunityFeedback model) => model.toMap();

  @override
  String documentId(CommunityFeedback model) => model.id;

  Query<Map<String, dynamic>> feedbackForProject(
    String projectId, {
    int limit = 50,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> feedbackForDistrict(
    String district, {
    int limit = 50,
  }) {
    return collection
        .where('district', isEqualTo: district)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> openFeedback({int limit = 50}) {
    return collection
        .where(
          'status',
          whereIn: [
            FeedbackStatus.received.value,
            FeedbackStatus.assigned.value,
            FeedbackStatus.inReview.value,
          ],
        )
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }
}
