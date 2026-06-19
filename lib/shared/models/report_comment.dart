import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/user_roles.dart';
import '../../core/firestore/firestore_model_utils.dart';

class ReportComment {
  const ReportComment({
    required this.id,
    required this.reportId,
    required this.projectId,
    required this.body,
    required this.createdBy,
    required this.authorName,
    required this.authorRole,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String reportId;
  final String projectId;
  final String body;
  final String createdBy;
  final String authorName;
  final UserRole authorRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ReportComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return ReportComment.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory ReportComment.fromMap(Map<String, dynamic> data, {String? id}) {
    final createdAt = FirestoreModelUtils.readDate(data['createdAt']);
    return ReportComment(
      id: id ?? data['id'] as String? ?? '',
      reportId: data['reportId'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorRole: UserRole.fromValue(data['authorRole'] as String?),
      createdAt: createdAt,
      updatedAt:
          FirestoreModelUtils.readOptionalDate(data['updatedAt']) ?? createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportId': reportId,
      'projectId': projectId,
      'body': body,
      'createdBy': createdBy,
      'authorName': authorName,
      'authorRole': authorRole.value,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
    };
  }
}
