import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/report_comment.dart';
import '../constants/firestore_collections.dart';
import 'firestore_repository.dart';

class ReportCommentsRepository extends FirestoreRepository<ReportComment> {
  ReportCommentsRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.reportComments);

  @override
  ReportComment fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return ReportComment.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(ReportComment model) => model.toMap();

  @override
  String documentId(ReportComment model) => model.id;

  Query<Map<String, dynamic>> commentsForReport(
    String reportId, {
    String? projectId,
    int limit = 100,
  }) {
    var query = collection.where('reportId', isEqualTo: reportId);

    final trimmedProjectId = projectId?.trim() ?? '';
    if (trimmedProjectId.isNotEmpty) {
      query = query.where('projectId', isEqualTo: trimmedProjectId);
    }

    return query.limit(limit);
  }
}
