import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/announcement_comment.dart';
import '../constants/firestore_collections.dart';
import 'firestore_repository.dart';

class AnnouncementCommentsRepository
    extends FirestoreRepository<AnnouncementComment> {
  AnnouncementCommentsRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.announcementComments);

  @override
  AnnouncementComment fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return AnnouncementComment.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(AnnouncementComment model) => model.toMap();

  @override
  String documentId(AnnouncementComment model) => model.id;

  Query<Map<String, dynamic>> commentsForAnnouncement(
    String announcementId, {
    int limit = 100,
  }) {
    return collection
        .where('announcementId', isEqualTo: announcementId)
        .limit(limit);
  }
}
