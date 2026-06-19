import 'package:cloud_firestore/cloud_firestore.dart';

import 'announcement_comments_repository.dart';
import 'announcement_reactions_repository.dart';
import 'announcements_repository.dart';
import 'community_feedback_repository.dart';
import 'documents_repository.dart';
import 'environmental_reports_repository.dart';
import 'meetings_repository.dart';
import 'notifications_repository.dart';
import 'project_members_repository.dart';
import 'projects_repository.dart';
import 'report_comments_repository.dart';
import 'report_photos_repository.dart';
import 'site_reports_repository.dart';
import 'users_repository.dart';

class SiteConnectRepositories {
  SiteConnectRepositories({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance {
    users = UsersRepository(firestore: this.firestore);
    projects = ProjectsRepository(firestore: this.firestore);
    projectMembers = ProjectMembersRepository(firestore: this.firestore);
    siteReports = SiteReportsRepository(firestore: this.firestore);
    announcements = AnnouncementsRepository(firestore: this.firestore);
    announcementComments = AnnouncementCommentsRepository(
      firestore: this.firestore,
    );
    announcementReactions = AnnouncementReactionsRepository(
      firestore: this.firestore,
    );
    reportComments = ReportCommentsRepository(firestore: this.firestore);
    reportPhotos = ReportPhotosRepository(firestore: this.firestore);
    documents = DocumentsRepository(firestore: this.firestore);
    notifications = NotificationsRepository(firestore: this.firestore);
    environmentalReports = EnvironmentalReportsRepository(
      firestore: this.firestore,
    );
    communityFeedback = CommunityFeedbackRepository(firestore: this.firestore);
    meetings = MeetingsRepository(firestore: this.firestore);
  }

  final FirebaseFirestore firestore;

  late final UsersRepository users;
  late final ProjectsRepository projects;
  late final ProjectMembersRepository projectMembers;
  late final SiteReportsRepository siteReports;
  late final AnnouncementsRepository announcements;
  late final AnnouncementCommentsRepository announcementComments;
  late final AnnouncementReactionsRepository announcementReactions;
  late final ReportCommentsRepository reportComments;
  late final ReportPhotosRepository reportPhotos;
  late final DocumentsRepository documents;
  late final NotificationsRepository notifications;
  late final EnvironmentalReportsRepository environmentalReports;
  late final CommunityFeedbackRepository communityFeedback;
  late final MeetingsRepository meetings;
}
