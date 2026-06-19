enum ProjectStatus {
  planning('planning', 'Planning'),
  procurement('procurement', 'Procurement'),
  mobilization('mobilization', 'Mobilization'),
  active('active', 'Active'),
  paused('paused', 'Paused'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const ProjectStatus(this.value, this.label);

  final String value;
  final String label;

  static ProjectStatus fromValue(String? value) {
    return _enumFromValue(
      value,
      ProjectStatus.values,
      fallback: ProjectStatus.planning,
    );
  }
}

enum ProjectMemberStatus {
  active('active', 'Active'),
  invited('invited', 'Invited'),
  suspended('suspended', 'Suspended'),
  removed('removed', 'Removed');

  const ProjectMemberStatus(this.value, this.label);

  final String value;
  final String label;

  static ProjectMemberStatus fromValue(String? value) {
    return _enumFromValue(
      value,
      ProjectMemberStatus.values,
      fallback: ProjectMemberStatus.active,
    );
  }
}

enum ReportStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  received('received', 'Received');

  const ReportStatus(this.value, this.label);

  final String value;
  final String label;

  static ReportStatus fromValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'reviewed') {
      return ReportStatus.received;
    }
    if (normalized == 'rejected') {
      return ReportStatus.submitted;
    }

    return _enumFromValue(
      value,
      ReportStatus.values,
      fallback: ReportStatus.draft,
    );
  }
}

enum DocumentType {
  contract('contract', 'Contract'),
  drawing('drawing', 'Drawing'),
  certificate('certificate', 'Certificate'),
  report('report', 'Report'),
  photoEvidence('photo_evidence', 'Photo Evidence'),
  minutes('minutes', 'Minutes'),
  other('other', 'Other');

  const DocumentType(this.value, this.label);

  final String value;
  final String label;

  static DocumentType fromValue(String? value) {
    return _enumFromValue(
      value,
      DocumentType.values,
      fallback: DocumentType.other,
    );
  }
}

enum DocumentVisibility {
  projectTeam('project_team', 'Project Team'),
  district('district', 'District'),
  public('public', 'Public'),
  restricted('restricted', 'Restricted');

  const DocumentVisibility(this.value, this.label);

  final String value;
  final String label;

  static DocumentVisibility fromValue(String? value) {
    return _enumFromValue(
      value,
      DocumentVisibility.values,
      fallback: DocumentVisibility.projectTeam,
    );
  }
}

enum DocumentStatus {
  active('active', 'Active'),
  archived('archived', 'Archived'),
  deleted('deleted', 'Deleted');

  const DocumentStatus(this.value, this.label);

  final String value;
  final String label;

  static DocumentStatus fromValue(String? value) {
    return _enumFromValue(
      value,
      DocumentStatus.values,
      fallback: DocumentStatus.active,
    );
  }
}

enum NotificationType {
  projectUpdate('project_update', 'Project Update'),
  reportSubmitted('report_submitted', 'Report Submitted'),
  documentUploaded('document_uploaded', 'Document Uploaded'),
  feedbackReceived('feedback_received', 'Feedback Received'),
  meetingScheduled('meeting_scheduled', 'Meeting Scheduled'),
  system('system', 'System');

  const NotificationType(this.value, this.label);

  final String value;
  final String label;

  static NotificationType fromValue(String? value) {
    return _enumFromValue(
      value,
      NotificationType.values,
      fallback: NotificationType.system,
    );
  }
}

enum AnnouncementScope {
  global('global', 'All users'),
  district('district', 'District'),
  project('project', 'Project');

  const AnnouncementScope(this.value, this.label);

  final String value;
  final String label;

  static AnnouncementScope fromValue(String? value) {
    return _enumFromValue(
      value,
      AnnouncementScope.values,
      fallback: AnnouncementScope.global,
    );
  }
}

enum AnnouncementPriority {
  normal('normal', 'Normal'),
  important('important', 'Important'),
  urgent('urgent', 'Urgent');

  const AnnouncementPriority(this.value, this.label);

  final String value;
  final String label;

  static AnnouncementPriority fromValue(String? value) {
    return _enumFromValue(
      value,
      AnnouncementPriority.values,
      fallback: AnnouncementPriority.normal,
    );
  }
}

enum AnnouncementStatus {
  active('active', 'Active'),
  archived('archived', 'Archived');

  const AnnouncementStatus(this.value, this.label);

  final String value;
  final String label;

  static AnnouncementStatus fromValue(String? value) {
    return _enumFromValue(
      value,
      AnnouncementStatus.values,
      fallback: AnnouncementStatus.active,
    );
  }
}

enum AnnouncementReactionType {
  like('like', 'Like');

  const AnnouncementReactionType(this.value, this.label);

  final String value;
  final String label;

  static AnnouncementReactionType fromValue(String? value) {
    return _enumFromValue(
      value,
      AnnouncementReactionType.values,
      fallback: AnnouncementReactionType.like,
    );
  }
}

enum EnvironmentalCategory {
  wasteManagement('waste_management', 'Waste Management'),
  waterProtection('water_protection', 'Water Protection'),
  dustNoise('dust_noise', 'Dust and Noise'),
  safety('safety', 'Safety'),
  biodiversity('biodiversity', 'Biodiversity'),
  communityImpact('community_impact', 'Community Impact'),
  other('other', 'Other');

  const EnvironmentalCategory(this.value, this.label);

  final String value;
  final String label;

  static EnvironmentalCategory fromValue(String? value) {
    return _enumFromValue(
      value,
      EnvironmentalCategory.values,
      fallback: EnvironmentalCategory.other,
    );
  }
}

enum RiskSeverity {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  critical('critical', 'Critical');

  const RiskSeverity(this.value, this.label);

  final String value;
  final String label;

  static RiskSeverity fromValue(String? value) {
    return _enumFromValue(
      value,
      RiskSeverity.values,
      fallback: RiskSeverity.low,
    );
  }
}

enum FeedbackType {
  complaint('complaint', 'Complaint'),
  grievance('grievance', 'Grievance'),
  suggestion('suggestion', 'Suggestion'),
  appreciation('appreciation', 'Appreciation'),
  inquiry('inquiry', 'Inquiry');

  const FeedbackType(this.value, this.label);

  final String value;
  final String label;

  static FeedbackType fromValue(String? value) {
    return _enumFromValue(
      value,
      FeedbackType.values,
      fallback: FeedbackType.inquiry,
    );
  }
}

enum FeedbackStatus {
  received('received', 'Received'),
  assigned('assigned', 'Assigned'),
  inReview('in_review', 'In Review'),
  resolved('resolved', 'Resolved'),
  closed('closed', 'Closed');

  const FeedbackStatus(this.value, this.label);

  final String value;
  final String label;

  static FeedbackStatus fromValue(String? value) {
    return _enumFromValue(
      value,
      FeedbackStatus.values,
      fallback: FeedbackStatus.received,
    );
  }
}

enum FeedbackPriority {
  low('low', 'Low'),
  normal('normal', 'Normal'),
  urgent('urgent', 'Urgent');

  const FeedbackPriority(this.value, this.label);

  final String value;
  final String label;

  static FeedbackPriority fromValue(String? value) {
    return _enumFromValue(
      value,
      FeedbackPriority.values,
      fallback: FeedbackPriority.normal,
    );
  }
}

enum MeetingStatus {
  scheduled('scheduled', 'Scheduled'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const MeetingStatus(this.value, this.label);

  final String value;
  final String label;

  static MeetingStatus fromValue(String? value) {
    return _enumFromValue(
      value,
      MeetingStatus.values,
      fallback: MeetingStatus.scheduled,
    );
  }
}

T _enumFromValue<T extends Enum>(
  String? value,
  List<T> values, {
  required T fallback,
}) {
  if (value == null || value.trim().isEmpty) {
    return fallback;
  }

  final normalized = value.trim().toLowerCase();

  for (final item in values) {
    final enumValue = (item as dynamic).value as String;
    if (enumValue == normalized || item.name == normalized) {
      return item;
    }
  }

  return fallback;
}
