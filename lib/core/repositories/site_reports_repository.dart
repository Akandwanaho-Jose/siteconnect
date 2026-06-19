import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/site_report.dart';
import '../constants/firestore_collections.dart';
import '../constants/firestore_enums.dart';
import 'firestore_repository.dart';

class SiteReportsRepository extends FirestoreRepository<SiteReport> {
  SiteReportsRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.siteReports);

  @override
  SiteReport fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return SiteReport.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(SiteReport model) => model.toMap();

  @override
  String documentId(SiteReport model) => model.id;

  Query<Map<String, dynamic>> reportsForProject(
    String projectId, {
    int limit = 50,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .orderBy('reportDate', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> reportsForProjectWindow(
    String projectId, {
    DateTime? startDate,
    DateTime? endDateExclusive,
    int limit = 120,
  }) {
    Query<Map<String, dynamic>> query = collection.where(
      'projectId',
      isEqualTo: projectId,
    );

    if (startDate != null) {
      query = query.where(
        'reportDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDateExclusive != null) {
      query = query.where(
        'reportDate',
        isLessThan: Timestamp.fromDate(endDateExclusive),
      );
    }

    return query.orderBy('reportDate', descending: true).limit(limit);
  }

  Query<Map<String, dynamic>> reportsWindow({
    DateTime? startDate,
    DateTime? endDateExclusive,
    int limit = 200,
  }) {
    Query<Map<String, dynamic>> query = collection;

    if (startDate != null) {
      query = query.where(
        'reportDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDateExclusive != null) {
      query = query.where(
        'reportDate',
        isLessThan: Timestamp.fromDate(endDateExclusive),
      );
    }

    return query.orderBy('reportDate', descending: true).limit(limit);
  }

  Query<Map<String, dynamic>> reportsForProjectSummary(
    String projectId, {
    int limit = 50,
  }) {
    return collection.where('projectId', isEqualTo: projectId).limit(limit);
  }

  Query<Map<String, dynamic>> reportsByAuthor(String userId, {int limit = 50}) {
    return collection
        .where('createdBy', isEqualTo: userId)
        .orderBy('reportDate', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> reportsByAuthorSummary(
    String userId, {
    int limit = 100,
  }) {
    return collection.where('createdBy', isEqualTo: userId).limit(limit);
  }

  Query<Map<String, dynamic>> reportsByStatus(
    ReportStatus status, {
    int limit = 100,
  }) {
    return collection.where('status', isEqualTo: status.value).limit(limit);
  }

  Query<Map<String, dynamic>> submittedReportsForProject(
    String projectId, {
    int limit = 50,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .where('status', isEqualTo: ReportStatus.submitted.value)
        .orderBy('reportDate', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> submittedReports({int limit = 50}) {
    return collection
        .where('status', isEqualTo: ReportStatus.submitted.value)
        .orderBy('reportDate', descending: true)
        .limit(limit);
  }

  Future<void> receiveReport({
    required SiteReport report,
    required String receivedBy,
    String? comment,
  }) {
    final fields = <String, dynamic>{
      'status': ReportStatus.received.value,
      'reviewFeedback': comment,
    };

    if (report.receivedAt == null) {
      fields['receivedAt'] = FieldValue.serverTimestamp();
    }

    if ((report.receivedBy ?? '').trim().isEmpty) {
      fields['receivedBy'] = receivedBy;
    }

    return updateFields(report.id, fields);
  }

  Future<void> commentOnReport({
    required String reportId,
    required String? comment,
  }) {
    return updateFields(reportId, {'reviewFeedback': comment});
  }
}
