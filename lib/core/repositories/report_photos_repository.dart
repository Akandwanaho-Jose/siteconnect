import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/report_photo.dart';
import '../constants/firestore_collections.dart';
import 'firestore_repository.dart';

class ReportPhotosRepository extends FirestoreRepository<ReportPhoto> {
  ReportPhotosRepository({super.firestore})
    : super(collectionPath: FirestoreCollections.reportPhotos);

  @override
  ReportPhoto fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return ReportPhoto.fromFirestore(snapshot);
  }

  @override
  Map<String, dynamic> toMap(ReportPhoto model) => model.toMap();

  @override
  String documentId(ReportPhoto model) => model.id;

  Query<Map<String, dynamic>> photosForReport(
    String reportId, {
    int limit = 50,
  }) {
    return collection
        .where('reportId', isEqualTo: reportId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }

  Query<Map<String, dynamic>> photosForProject(
    String projectId, {
    int limit = 100,
  }) {
    return collection
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
  }
}
