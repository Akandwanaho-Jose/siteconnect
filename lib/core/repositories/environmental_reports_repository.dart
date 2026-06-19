import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/environmental_report.dart';
import '../constants/firestore_collections.dart';
import '../constants/firestore_enums.dart';
import 'firestore_repository.dart';

class EnvironmentalReportsRepository
    extends FirestoreRepository<EnvironmentalReport> {
  EnvironmentalReportsRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.environmentalReports);

  @override
  EnvironmentalReport fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return EnvironmentalReport.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(EnvironmentalReport model) => model.toMap();

  @override
  String documentId(EnvironmentalReport model) => model.id;

  Query<Map<String, dynamic>> reportsForProject(
    String projectId, {
    int limit = 50,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .orderBy('reportDate', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> openHighRiskReports({int limit = 50}) {
    return collection
        .where(
          'severity',
          whereIn: [RiskSeverity.high.value, RiskSeverity.critical.value],
        )
        .where(
          'status',
          whereIn: [ReportStatus.draft.value, ReportStatus.submitted.value],
        )
        .orderBy('reportDate', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> reportsByCategory(
    String projectId,
    EnvironmentalCategory category, {
    int limit = 50,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .where('category', isEqualTo: category.value)
        .orderBy('reportDate', descending: true)
        .limit(limit);
  }
}
