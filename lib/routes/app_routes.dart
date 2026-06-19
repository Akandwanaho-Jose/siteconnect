import '../core/constants/user_roles.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const passwordReset = '/password/reset';
  static const profileEdit = '/profile/edit';
  static const passwordChange = '/profile/password';
  static const adminUsers = '/admin/users';
  static const adminUserForm = '/admin/users/form';
  static const projects = '/projects';
  static const projectForm = '/projects/form';
  static const projectDetails = '/projects/details';
  static const projectTeam = '/projects/team';
  static const reports = '/reports';
  static const reportDetails = '/reports/details';
  static const submitReport = '/reports/submit';
  static const siteReports = '/projects/reports';
  static const siteReportForm = '/projects/reports/form';
  static const reportPhotos = '/projects/reports/photos';
  static const announcements = '/announcements';
  static const messages = '/messages';
  static const dashboard = '/dashboard';
  static const administratorDashboard = '/dashboard/administrator';
  static const projectManagerDashboard = '/dashboard/project-manager';
  static const siteEngineerDashboard = '/dashboard/site-engineer';
  static const contractorDashboard = '/dashboard/contractor';
  static const consultantDashboard = '/dashboard/consultant';
  static const clerkOfWorksDashboard = '/dashboard/clerk-of-works';
  static const districtEngineerDashboard = '/dashboard/district-engineer';
  static const procurementOfficerDashboard = '/dashboard/procurement-officer';
  static const communityRepresentativeDashboard =
      '/dashboard/community-representative';
  static const environmentOfficerDashboard = '/dashboard/environment-officer';
  static const communityDevelopmentOfficerDashboard =
      '/dashboard/community-development-officer';

  static const Set<String> protectedRoutes = {
    profileEdit,
    passwordChange,
    adminUsers,
    adminUserForm,
    projects,
    projectForm,
    projectDetails,
    projectTeam,
    reports,
    reportDetails,
    submitReport,
    siteReports,
    siteReportForm,
    reportPhotos,
    announcements,
    messages,
    dashboard,
    administratorDashboard,
    projectManagerDashboard,
    siteEngineerDashboard,
    contractorDashboard,
    consultantDashboard,
    clerkOfWorksDashboard,
    districtEngineerDashboard,
    procurementOfficerDashboard,
    communityRepresentativeDashboard,
    environmentOfficerDashboard,
    communityDevelopmentOfficerDashboard,
  };

  static bool isProtectedRoute(String? routeName) {
    return routeName != null && protectedRoutes.contains(routeName);
  }

  static String dashboardForRole(UserRole role) {
    return switch (role) {
      UserRole.administrator => administratorDashboard,
      UserRole.projectManager => projectManagerDashboard,
      UserRole.siteEngineer => siteEngineerDashboard,
      UserRole.contractor => contractorDashboard,
      UserRole.consultant => consultantDashboard,
      UserRole.clerkOfWorks => clerkOfWorksDashboard,
      UserRole.districtEngineer => districtEngineerDashboard,
      UserRole.procurementOfficer => procurementOfficerDashboard,
      UserRole.communityRepresentative => communityRepresentativeDashboard,
      UserRole.environmentOfficer => environmentOfficerDashboard,
      UserRole.communityDevelopmentOfficer =>
        communityDevelopmentOfficerDashboard,
      UserRole.unknown => dashboard,
    };
  }

  static UserRole? expectedRoleForDashboard(String? routeName) {
    return switch (routeName) {
      administratorDashboard => UserRole.administrator,
      projectManagerDashboard => UserRole.projectManager,
      siteEngineerDashboard => UserRole.siteEngineer,
      contractorDashboard => UserRole.contractor,
      consultantDashboard => UserRole.consultant,
      clerkOfWorksDashboard => UserRole.clerkOfWorks,
      districtEngineerDashboard => UserRole.districtEngineer,
      procurementOfficerDashboard => UserRole.procurementOfficer,
      communityRepresentativeDashboard => UserRole.communityRepresentative,
      environmentOfficerDashboard => UserRole.environmentOfficer,
      communityDevelopmentOfficerDashboard =>
        UserRole.communityDevelopmentOfficer,
      _ => null,
    };
  }
}
