import 'package:flutter/material.dart';

import '../core/services/firebase_auth_service.dart';
import '../features/account/presentation/screens/change_password_screen.dart';
import '../features/account/presentation/screens/profile_edit_screen.dart';
import '../features/admin/presentation/screens/admin_user_form_screen.dart';
import '../features/admin/presentation/screens/admin_user_list_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/password_reset_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/communication/presentation/screens/announcements_screen.dart';
import '../features/communication/presentation/screens/messages_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/projects/presentation/screens/project_details_screen.dart';
import '../features/projects/presentation/screens/project_form_screen.dart';
import '../features/projects/presentation/screens/project_team_screen.dart';
import '../features/projects/presentation/screens/projects_list_screen.dart';
import '../features/projects/presentation/screens/report_photos_screen.dart';
import '../features/projects/presentation/screens/site_report_form_screen.dart';
import '../features/projects/presentation/screens/site_reports_screen.dart';
import '../features/reports/presentation/screens/report_details_screen.dart';
import '../features/reports/presentation/screens/reports_list_screen.dart';
import '../features/reports/presentation/screens/submit_report_screen.dart';
import 'app_route_arguments.dart';
import 'app_routes.dart';
import 'route_guard.dart';

class AppRouter {
  const AppRouter._();

  static final FirebaseAuthService _authService = FirebaseAuthService();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final guardedSettings = RouteGuard.guardedSettings(
      settings,
      authService: _authService,
    );

    if (guardedSettings.name == AppRoutes.login &&
        _authService.currentUser != null) {
      return _pageRoute(
        const RouteSettings(name: AppRoutes.splash),
        SplashScreen(authService: _authService),
      );
    }

    return switch (guardedSettings.name) {
      AppRoutes.splash => _pageRoute(
        guardedSettings,
        SplashScreen(authService: _authService),
      ),
      AppRoutes.login => _pageRoute(
        guardedSettings,
        LoginScreen(
          authService: _authService,
          arguments: _loginArguments(guardedSettings.arguments),
        ),
      ),
      AppRoutes.passwordReset => _pageRoute(
        guardedSettings,
        PasswordResetScreen(
          authService: _authService,
          arguments: _passwordResetArguments(guardedSettings.arguments),
        ),
      ),
      AppRoutes.profileEdit => _pageRoute(
        guardedSettings,
        ProfileEditScreen(authService: _authService),
      ),
      AppRoutes.passwordChange => _pageRoute(
        guardedSettings,
        ChangePasswordScreen(authService: _authService),
      ),
      AppRoutes.adminUsers => _pageRoute(
        guardedSettings,
        AdminUserListScreen(authService: _authService),
      ),
      AppRoutes.adminUserForm => _pageRoute(
        guardedSettings,
        AdminUserFormScreen(
          authService: _authService,
          arguments: _userFormArguments(guardedSettings.arguments),
        ),
      ),
      AppRoutes.projects => _pageRoute(
        guardedSettings,
        ProjectsListScreen(authService: _authService),
      ),
      AppRoutes.projectForm => _pageRoute(
        guardedSettings,
        ProjectFormScreen(
          authService: _authService,
          arguments: _projectFormArguments(guardedSettings.arguments),
        ),
      ),
      AppRoutes.projectDetails => _pageRoute(
        guardedSettings,
        ProjectDetailsScreen(
          authService: _authService,
          arguments: _projectDetailsArguments(guardedSettings.arguments),
        ),
      ),
      AppRoutes.projectTeam => _pageRoute(
        guardedSettings,
        ProjectTeamScreen(
          authService: _authService,
          arguments: _projectTeamArguments(guardedSettings.arguments),
        ),
      ),
      AppRoutes.reports => _pageRoute(
        guardedSettings,
        ReportsListScreen(
          authService: _authService,
          arguments: _reportsArguments(guardedSettings.arguments),
        ),
      ),
      AppRoutes.reportDetails => _pageRoute(
        guardedSettings,
        ReportDetailsScreen(
          authService: _authService,
          arguments: _reportDetailsArguments(guardedSettings.arguments),
        ),
      ),
      AppRoutes.submitReport => _pageRoute(
        guardedSettings,
        SubmitReportScreen(authService: _authService),
      ),
      AppRoutes.siteReports => _pageRoute(
        guardedSettings,
        SiteReportsScreen(
          authService: _authService,
          arguments: _siteReportsArguments(guardedSettings.arguments),
        ),
      ),
      AppRoutes.siteReportForm => _pageRoute(
        guardedSettings,
        SiteReportFormScreen(
          authService: _authService,
          arguments: _siteReportFormArguments(guardedSettings.arguments),
        ),
      ),
      AppRoutes.reportPhotos => _pageRoute(
        guardedSettings,
        ReportPhotosScreen(
          authService: _authService,
          arguments: _reportPhotosArguments(guardedSettings.arguments),
        ),
      ),
      AppRoutes.announcements => _pageRoute(
        guardedSettings,
        AnnouncementsScreen(authService: _authService),
      ),
      AppRoutes.messages => _pageRoute(guardedSettings, const MessagesScreen()),
      AppRoutes.dashboard ||
      AppRoutes.administratorDashboard ||
      AppRoutes.projectManagerDashboard ||
      AppRoutes.siteEngineerDashboard ||
      AppRoutes.contractorDashboard ||
      AppRoutes.consultantDashboard ||
      AppRoutes.clerkOfWorksDashboard ||
      AppRoutes.districtEngineerDashboard ||
      AppRoutes.procurementOfficerDashboard ||
      AppRoutes.communityRepresentativeDashboard ||
      AppRoutes.environmentOfficerDashboard ||
      AppRoutes.communityDevelopmentOfficerDashboard => _pageRoute(
        guardedSettings,
        DashboardScreen(
          authService: _authService,
          expectedRole: AppRoutes.expectedRoleForDashboard(
            guardedSettings.name,
          ),
          initialProfile: _dashboardArguments(
            guardedSettings.arguments,
          )?.profile,
        ),
      ),
      _ => _pageRoute(guardedSettings, SplashScreen(authService: _authService)),
    };
  }

  static LoginRouteArguments? _loginArguments(Object? arguments) {
    return arguments is LoginRouteArguments ? arguments : null;
  }

  static PasswordResetRouteArguments? _passwordResetArguments(
    Object? arguments,
  ) {
    return arguments is PasswordResetRouteArguments ? arguments : null;
  }

  static DashboardRouteArguments? _dashboardArguments(Object? arguments) {
    return arguments is DashboardRouteArguments ? arguments : null;
  }

  static UserFormRouteArguments? _userFormArguments(Object? arguments) {
    return arguments is UserFormRouteArguments ? arguments : null;
  }

  static ProjectDetailsRouteArguments _projectDetailsArguments(
    Object? arguments,
  ) {
    if (arguments is ProjectDetailsRouteArguments) {
      return arguments;
    }

    return const ProjectDetailsRouteArguments(projectId: '');
  }

  static ProjectFormRouteArguments? _projectFormArguments(Object? arguments) {
    return arguments is ProjectFormRouteArguments ? arguments : null;
  }

  static ProjectTeamRouteArguments _projectTeamArguments(Object? arguments) {
    if (arguments is ProjectTeamRouteArguments) {
      return arguments;
    }

    return const ProjectTeamRouteArguments(projectId: '');
  }

  static ReportsRouteArguments? _reportsArguments(Object? arguments) {
    return arguments is ReportsRouteArguments ? arguments : null;
  }

  static ReportDetailsRouteArguments _reportDetailsArguments(
    Object? arguments,
  ) {
    if (arguments is ReportDetailsRouteArguments) {
      return arguments;
    }

    return const ReportDetailsRouteArguments(reportId: '');
  }

  static SiteReportsRouteArguments _siteReportsArguments(Object? arguments) {
    if (arguments is SiteReportsRouteArguments) {
      return arguments;
    }

    return const SiteReportsRouteArguments(projectId: '');
  }

  static SiteReportFormRouteArguments _siteReportFormArguments(
    Object? arguments,
  ) {
    if (arguments is SiteReportFormRouteArguments) {
      return arguments;
    }

    return const SiteReportFormRouteArguments(projectId: '');
  }

  static ReportPhotosRouteArguments _reportPhotosArguments(Object? arguments) {
    if (arguments is ReportPhotosRouteArguments) {
      return arguments;
    }

    return const ReportPhotosRouteArguments(projectId: '', reportId: '');
  }

  static Route<dynamic> _pageRoute(RouteSettings settings, Widget screen) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (_, _, _) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) {
          return child;
        }

        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }
}
