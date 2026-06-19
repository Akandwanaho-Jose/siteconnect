import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_enums.dart';
import '../../core/constants/user_roles.dart';
import '../../core/firestore/firestore_model_utils.dart';

class SiteReport {
  const SiteReport({
    required this.id,
    required this.projectId,
    required this.title,
    required this.summary,
    required this.reportDate,
    required this.progressPercent,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.authorRole = UserRole.unknown,
    this.submittedAt,
    this.pdfStoragePath,
    this.pdfDownloadUrl,
    this.pdfFileName,
    this.pdfGeneratedAt,
    this.pdfVersion = 0,
    this.pdfFileSizeBytes,
    this.reviewFeedback,
    this.receivedAt,
    this.receivedBy,
    this.weather,
    this.workCompleted,
    this.labourOnSite,
    this.equipmentOnSite,
    this.materialsUsed,
    this.qualityObservations,
    this.safetyObservations,
    this.delaysBlockers,
    this.instructionsReceived,
    this.inspectionNotes,
    this.visitorNotes,
    this.nextPlannedWork,
    this.issuesRisks,
    this.siteConditions,
    this.latitude,
    this.longitude,
    this.locationAccuracyMeters,
  });

  final String id;
  final String projectId;
  final String title;
  final String summary;
  final DateTime reportDate;
  final int progressPercent;
  final ReportStatus status;
  final UserRole authorRole;
  final DateTime? submittedAt;
  final String? pdfStoragePath;
  final String? pdfDownloadUrl;
  final String? pdfFileName;
  final DateTime? pdfGeneratedAt;
  final int pdfVersion;
  final int? pdfFileSizeBytes;
  final String? reviewFeedback;
  final DateTime? receivedAt;
  final String? receivedBy;
  final String? weather;
  final String? workCompleted;
  final String? labourOnSite;
  final String? equipmentOnSite;
  final String? materialsUsed;
  final String? qualityObservations;
  final String? safetyObservations;
  final String? delaysBlockers;
  final String? instructionsReceived;
  final String? inspectionNotes;
  final String? visitorNotes;
  final String? nextPlannedWork;
  final String? issuesRisks;
  final String? siteConditions;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracyMeters;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;

  factory SiteReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return SiteReport.fromMap(
      snapshot.data() ?? <String, dynamic>{},
      id: snapshot.id,
    );
  }

  factory SiteReport.fromMap(Map<String, dynamic> data, {String? id}) {
    return SiteReport(
      id: id ?? data['id'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      reportDate: FirestoreModelUtils.readDate(data['reportDate']),
      progressPercent: FirestoreModelUtils.readInt(data['progressPercent']),
      status: ReportStatus.fromValue(data['status'] as String?),
      authorRole: UserRole.fromValue(data['authorRole'] as String?),
      submittedAt: FirestoreModelUtils.readOptionalDate(data['submittedAt']),
      pdfStoragePath: data['pdfStoragePath'] as String?,
      pdfDownloadUrl: data['pdfDownloadUrl'] as String?,
      pdfFileName: data['pdfFileName'] as String?,
      pdfGeneratedAt: FirestoreModelUtils.readOptionalDate(
        data['pdfGeneratedAt'],
      ),
      pdfVersion: FirestoreModelUtils.readInt(data['pdfVersion'], fallback: 0),
      pdfFileSizeBytes: data['pdfFileSizeBytes'] == null
          ? null
          : FirestoreModelUtils.readInt(data['pdfFileSizeBytes']),
      reviewFeedback: data['reviewFeedback'] as String?,
      receivedAt:
          FirestoreModelUtils.readOptionalDate(data['receivedAt']) ??
          FirestoreModelUtils.readOptionalDate(data['reviewedAt']),
      receivedBy:
          data['receivedBy'] as String? ?? data['reviewedBy'] as String?,
      weather: data['weather'] as String?,
      workCompleted: data['workCompleted'] as String?,
      labourOnSite: data['labourOnSite'] as String?,
      equipmentOnSite: data['equipmentOnSite'] as String?,
      materialsUsed: data['materialsUsed'] as String?,
      qualityObservations: data['qualityObservations'] as String?,
      safetyObservations: data['safetyObservations'] as String?,
      delaysBlockers: data['delaysBlockers'] as String?,
      instructionsReceived: data['instructionsReceived'] as String?,
      inspectionNotes: data['inspectionNotes'] as String?,
      visitorNotes: data['visitorNotes'] as String?,
      nextPlannedWork: data['nextPlannedWork'] as String?,
      issuesRisks: data['issuesRisks'] as String?,
      siteConditions: data['siteConditions'] as String?,
      latitude: FirestoreModelUtils.readOptionalDouble(data['latitude']),
      longitude: FirestoreModelUtils.readOptionalDouble(data['longitude']),
      locationAccuracyMeters: FirestoreModelUtils.readOptionalDouble(
        data['locationAccuracyMeters'],
      ),
      createdAt: FirestoreModelUtils.readDate(data['createdAt']),
      updatedAt: FirestoreModelUtils.readDate(data['updatedAt']),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'summary': summary,
      'reportDate': FirestoreModelUtils.timestamp(reportDate),
      'progressPercent': progressPercent,
      'status': status.value,
      'authorRole': authorRole.value,
      'submittedAt': FirestoreModelUtils.optionalTimestamp(submittedAt),
      'pdfStoragePath': pdfStoragePath,
      'pdfDownloadUrl': pdfDownloadUrl,
      'pdfFileName': pdfFileName,
      'pdfGeneratedAt': FirestoreModelUtils.optionalTimestamp(pdfGeneratedAt),
      'pdfVersion': pdfVersion,
      'pdfFileSizeBytes': pdfFileSizeBytes,
      'reviewFeedback': reviewFeedback,
      'receivedAt': FirestoreModelUtils.optionalTimestamp(receivedAt),
      'receivedBy': receivedBy,
      'weather': weather,
      'workCompleted': workCompleted,
      'labourOnSite': labourOnSite,
      'equipmentOnSite': equipmentOnSite,
      'materialsUsed': materialsUsed,
      'qualityObservations': qualityObservations,
      'safetyObservations': safetyObservations,
      'delaysBlockers': delaysBlockers,
      'instructionsReceived': instructionsReceived,
      'inspectionNotes': inspectionNotes,
      'visitorNotes': visitorNotes,
      'nextPlannedWork': nextPlannedWork,
      'issuesRisks': issuesRisks,
      'siteConditions': siteConditions,
      'latitude': latitude,
      'longitude': longitude,
      'locationAccuracyMeters': locationAccuracyMeters,
      'createdAt': FirestoreModelUtils.timestamp(createdAt),
      'updatedAt': FirestoreModelUtils.timestamp(updatedAt),
      'createdBy': createdBy,
    };
  }

  SiteReport copyWith({
    String? id,
    String? projectId,
    String? title,
    String? summary,
    DateTime? reportDate,
    int? progressPercent,
    ReportStatus? status,
    UserRole? authorRole,
    DateTime? submittedAt,
    String? pdfStoragePath,
    String? pdfDownloadUrl,
    String? pdfFileName,
    DateTime? pdfGeneratedAt,
    int? pdfVersion,
    int? pdfFileSizeBytes,
    String? reviewFeedback,
    DateTime? receivedAt,
    String? receivedBy,
    String? weather,
    String? workCompleted,
    String? labourOnSite,
    String? equipmentOnSite,
    String? materialsUsed,
    String? qualityObservations,
    String? safetyObservations,
    String? delaysBlockers,
    String? instructionsReceived,
    String? inspectionNotes,
    String? visitorNotes,
    String? nextPlannedWork,
    String? issuesRisks,
    String? siteConditions,
    double? latitude,
    double? longitude,
    double? locationAccuracyMeters,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return SiteReport(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      reportDate: reportDate ?? this.reportDate,
      progressPercent: progressPercent ?? this.progressPercent,
      status: status ?? this.status,
      authorRole: authorRole ?? this.authorRole,
      submittedAt: submittedAt ?? this.submittedAt,
      pdfStoragePath: pdfStoragePath ?? this.pdfStoragePath,
      pdfDownloadUrl: pdfDownloadUrl ?? this.pdfDownloadUrl,
      pdfFileName: pdfFileName ?? this.pdfFileName,
      pdfGeneratedAt: pdfGeneratedAt ?? this.pdfGeneratedAt,
      pdfVersion: pdfVersion ?? this.pdfVersion,
      pdfFileSizeBytes: pdfFileSizeBytes ?? this.pdfFileSizeBytes,
      reviewFeedback: reviewFeedback ?? this.reviewFeedback,
      receivedAt: receivedAt ?? this.receivedAt,
      receivedBy: receivedBy ?? this.receivedBy,
      weather: weather ?? this.weather,
      workCompleted: workCompleted ?? this.workCompleted,
      labourOnSite: labourOnSite ?? this.labourOnSite,
      equipmentOnSite: equipmentOnSite ?? this.equipmentOnSite,
      materialsUsed: materialsUsed ?? this.materialsUsed,
      qualityObservations: qualityObservations ?? this.qualityObservations,
      safetyObservations: safetyObservations ?? this.safetyObservations,
      delaysBlockers: delaysBlockers ?? this.delaysBlockers,
      instructionsReceived: instructionsReceived ?? this.instructionsReceived,
      inspectionNotes: inspectionNotes ?? this.inspectionNotes,
      visitorNotes: visitorNotes ?? this.visitorNotes,
      nextPlannedWork: nextPlannedWork ?? this.nextPlannedWork,
      issuesRisks: issuesRisks ?? this.issuesRisks,
      siteConditions: siteConditions ?? this.siteConditions,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAccuracyMeters:
          locationAccuracyMeters ?? this.locationAccuracyMeters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
