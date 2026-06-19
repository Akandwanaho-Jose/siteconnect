import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/announcement.dart';
import '../constants/firestore_collections.dart';
import '../constants/firestore_enums.dart';
import 'firestore_repository.dart';

class AnnouncementsRepository extends FirestoreRepository<Announcement> {
  AnnouncementsRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.announcements);

  @override
  Announcement fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return Announcement.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(Announcement model) => model.toMap();

  @override
  String documentId(Announcement model) => model.id;

  Query<Map<String, dynamic>> recentAnnouncements({int limit = 150}) {
    return collection.orderBy('publishAt', descending: true).limit(limit);
  }

  Future<void> archive(String id) {
    return updateFields(id, {'status': AnnouncementStatus.archived.value});
  }
}
