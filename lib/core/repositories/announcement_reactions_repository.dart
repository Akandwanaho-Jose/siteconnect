import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/announcement_reaction.dart';
import '../constants/firestore_collections.dart';
import '../constants/firestore_enums.dart';
import 'firestore_repository.dart';

class AnnouncementReactionsRepository
    extends FirestoreRepository<AnnouncementReaction> {
  AnnouncementReactionsRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.announcementReactions);

  @override
  AnnouncementReaction fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return AnnouncementReaction.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(AnnouncementReaction model) => model.toMap();

  @override
  String documentId(AnnouncementReaction model) => model.id;

  Query<Map<String, dynamic>> reactionsForAnnouncement(
    String announcementId, {
    int limit = 500,
  }) {
    return collection
        .where('announcementId', isEqualTo: announcementId)
        .limit(limit);
  }

  String reactionDocumentId({
    required String announcementId,
    required String userId,
    required AnnouncementReactionType type,
  }) {
    return '${announcementId}_${userId}_${type.value}';
  }

  Future<void> toggleReaction(AnnouncementReaction reaction) async {
    final snapshot = await doc(reaction.id).get();
    if (snapshot.exists) {
      await deleteById(reaction.id);
      return;
    }

    await save(reaction);
  }
}
