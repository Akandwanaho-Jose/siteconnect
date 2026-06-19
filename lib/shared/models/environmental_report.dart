import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_enums.dart';
import '../../core/firestore/firestore_model_utils.dart';

class EnvironmentalReport {
  const EnvironmentalReport({
    required this.id,
    required this.projectId,
    required this.category,
    required this.severity,
    required this.status,
    required this.description,
    required this.reportDate,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.mitigationAction,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String projectId;
  final EnvironmentalCategory category;
  final RiskSeverity severity;
  final ReportStatus status;
  final String description;
  final String? mitigationAction;
  final DateTime reportDate;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  factory EnvironmentalReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return EnvironmentalReport.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory EnvironmentalReport.fromMap(Map<String, dynamic> data, {String? id}) {
    return EnvironmentalReport(
      id: id ?? data['id'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      category: EnvironmentalCategory.fromValue(data['category'] as String?),
      severity: RiskSeverity.fromValue(data['severity'] as String?),
      status: ReportStatus.fromValue(data['status'] as String?),
      description: data['description'] as String? ?? '',
      mitigationAction: data['mitigationAction'] as String?,
      reportDate: FirestoreModelUtils.readDate(data['reportDate']),
      latitude: FirestoreModelUtils.readOptionalDouble(data['latitude']),
      longitude: FirestoreModelUtils.readOptionalDouble(data['longitude']),
      createdAt: FirestoreModelUtils.readDate(data['createdAt']),
      updatedAt: FirestoreModelUtils.readDate(data['updatedAt']),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'category': category.value,
      'severity': severity.value,
      'status': status.value,
      'description': description,
      'mitigationAction': mitigationAction,
      'reportDate': FirestoreModelUtils.timestamp(reportDate),
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
      'createdBy': createdBy,
    };
  }
}
