import '../shared/models/app_user.dart';
import '../shared/models/project.dart';
import '../shared/models/site_report.dart';

class LoginRouteArguments {
  const LoginRouteArguments({this.message, this.redirectRoute});

  final String? message;
  final String? redirectRoute;
}

class PasswordResetRouteArguments {
  const PasswordResetRouteArguments({this.email});

  final String? email;
}

class DashboardRouteArguments {
  const DashboardRouteArguments({this.profile});

  final AppUser? profile;
}

class UserFormRouteArguments {
  const UserFormRouteArguments({this.user});

  final AppUser? user;
}

class ProjectDetailsRouteArguments {
  const ProjectDetailsRouteArguments({required this.projectId, this.project});

  final String projectId;
  final Project? project;
}

class ProjectFormRouteArguments {
  const ProjectFormRouteArguments({this.projectId, this.project});

  final String? projectId;
  final Project? project;
}

class ProjectTeamRouteArguments {
  const ProjectTeamRouteArguments({required this.projectId, this.project});

  final String projectId;
  final Project? project;
}

class ReportsRouteArguments {
  const ReportsRouteArguments({this.projectId, this.project, this.title});

  final String? projectId;
  final Project? project;
  final String? title;
}

class ReportDetailsRouteArguments {
  const ReportDetailsRouteArguments({
    required this.reportId,
    this.projectId,
    this.report,
    this.project,
  });

  final String reportId;
  final String? projectId;
  final SiteReport? report;
  final Project? project;
}

class SiteReportsRouteArguments {
  const SiteReportsRouteArguments({required this.projectId, this.project});

  final String projectId;
  final Project? project;
}

class SiteReportFormRouteArguments {
  const SiteReportFormRouteArguments({
    required this.projectId,
    this.project,
    this.report,
  });

  final String projectId;
  final Project? project;
  final SiteReport? report;
}

class ReportPhotosRouteArguments {
  const ReportPhotosRouteArguments({
    required this.projectId,
    required this.reportId,
    this.project,
    this.report,
  });

  final String projectId;
  final String reportId;
  final Project? project;
  final SiteReport? report;
}
