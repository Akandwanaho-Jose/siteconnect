import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/app_notification.dart';
import '../constants/firestore_collections.dart';
import 'firestore_repository.dart';

class NotificationsRepository extends FirestoreRepository<AppNotification> {
  NotificationsRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.notifications);

  @override
  AppNotification fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return AppNotification.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(AppNotification model) => model.toMap();

  @override
  String documentId(AppNotification model) => model.id;

  Query<Map<String, dynamic>> notificationsForUser(
    String userId, {
    int limit = 50,
  }) {
    return collection
        .where('recipientUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> unreadForUser(String userId, {int limit = 50}) {
    return collection
        .where('recipientUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }
}
