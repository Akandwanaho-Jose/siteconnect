import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_enums.dart';
import '../../core/firestore/firestore_model_utils.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.projectId,
    this.relatedCollection,
    this.relatedDocumentId,
  });

  final String id;
  final String recipientUserId;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final String? createdBy;
  final String? projectId;
  final String? relatedCollection;
  final String? relatedDocumentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return AppNotification.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory AppNotification.fromMap(Map<String, dynamic> data, {String? id}) {
    return AppNotification(
      id: id ?? data['id'] as String? ?? '',
      recipientUserId: data['recipientUserId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: NotificationType.fromValue(data['type'] as String?),
      isRead: FirestoreModelUtils.readBool(data['isRead']),
      createdBy: data['createdBy'] as String?,
      projectId: data['projectId'] as String?,
      relatedCollection: data['relatedCollection'] as String?,
      relatedDocumentId: data['relatedDocumentId'] as String?,
      createdAt: FirestoreModelUtils.readDate(data['createdAt']),
      updatedAt: FirestoreModelUtils.readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipientUserId': recipientUserId,
      'title': title,
      'body': body,
      'type': type.value,
      'isRead': isRead,
      'createdBy': createdBy,
      'projectId': projectId,
      'relatedCollection': relatedCollection,
      'relatedDocumentId': relatedDocumentId,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
    };
  }
}
