import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firestore_enums.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/repositories/project_members_repository.dart';
import '../../../../core/repositories/projects_repository.dart';
import '../../../../core/repositories/site_reports_repository.dart';
import '../../../../core/repositories/users_repository.dart';
import '../../../../core/services/auth_failure.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../routes/app_route_arguments.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/models/project_member.dart';
import '../../../../shared/models/site_report.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_motion.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_visuals.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    FirebaseAuthService? authService,
    UserRole? expectedRole,
    AppUser? initialProfile,
    super.key,
  }) : _authService = authService,
       _expectedRole = expectedRole,
       _initialProfile = initialProfile;

  final FirebaseAuthService? _authService;
  final UserRole? _expectedRole;
  final AppUser? _initialProfile;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final FirebaseAuthService _authService;
  late Future<AppUser> _profileFuture;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _profileFuture = widget._initialProfile == null
        ? _authService.fetchCurrentUserProfile()
        : Future<AppUser>.value(widget._initialProfile);
  }

  void _retryProfileLoad() {
    setState(() {
      _profileFuture = _authService.fetchCurrentUserProfile();
    });
  }

  Future<void> _signOut() async {
    await _authService.signOut();

    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _openProfileEditor() async {
    final didChange = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.profileEdit);

    if (didChange == true) {
      _retryProfileLoad();
    }
  }

  void _redirectToRoleDashboard(AppUser profile) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.dashboardForRole(profile.role),
        (route) => false,
        arguments: DashboardRouteArguments(profile: profile),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Dashboard',
      actions: [
        IconButton(
          tooltip: 'Edit profile',
          onPressed: _openProfileEditor,
          icon: const Icon(Icons.account_circle_outlined),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
      body: FutureBuilder<AppUser>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Loading dashboard');
          }

          if (snapshot.hasError) {
            return _DashboardError(
              message: _dashboardErrorMessage(snapshot.error),
              onRetry: _retryProfileLoad,
              onSignOut: _signOut,
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return _DashboardError(
              message: 'Your account profile could not be loaded.',
              onRetry: _retryProfileLoad,
              onSignOut: _signOut,
            );
          }

          final expectedRole = widget._expectedRole;
          if (expectedRole != null && expectedRole != profile.role) {
            _redirectToRoleDashboard(profile);
            return AppLoadingIndicator(
              message: 'Opening ${profile.role.label} dashboard',
            );
          }

          return _DashboardContent(
            profile: profile,
            onEditProfile: _openProfileEditor,
            onSignOut: _signOut,
          );
        },
      ),
    );
  }

  String _dashboardErrorMessage(Object? error) {
    if (error is AuthFailure) {
      return error.message;
    }

    return 'Unable to load dashboard.';
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.profile,
    required this.onEditProfile,
    required this.onSignOut,
  });

  final AppUser profile;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    if (profile.role == UserRole.administrator) {
      return _AdministratorDashboard(
        profile: profile,
        onEditProfile: onEditProfile,
        onSignOut: onSignOut,
      );
    }

    if (profile.role == UserRole.districtEngineer) {
      return _DistrictEngineerDashboard(
        profile: profile,
        onEditProfile: onEditProfile,
      );
    }

    if (profile.role == UserRole.clerkOfWorks) {
      return _ClerkOfWorksDashboard(
        profile: profile,
        onEditProfile: onEditProfile,
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final role = profile.role;
    final modules = _modulesForRole(role);
    final adminModules = _adminModulesForRole(role);

    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ResponsiveLayout.maxContentWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppAnimatedEntry(
                child: _OverviewCard(
                  profile: profile,
                  onEditProfile: onEditProfile,
                ),
              ),
              const SizedBox(height: 20),
              if (adminModules.isNotEmpty) ...[
                Text('Administration', style: textTheme.titleLarge),
                const SizedBox(height: 12),
                ...adminModules.asMap().entries.map(
                  (entry) => AppAnimatedEntry(
                    index: entry.key + 1,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ModuleCard(module: entry.value),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text('Work areas', style: textTheme.titleLarge),
              const SizedBox(height: 12),
              ...modules.asMap().entries.map(
                (entry) => AppAnimatedEntry(
                  index: entry.key + adminModules.length + 2,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ModuleCard(module: entry.value),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_DashboardModule> _modulesForRole(UserRole role) {
    final allModules = <_DashboardModule>[
      const _DashboardModule(
        title: 'Projects',
        detail: 'Project records, districts, contractors, and status.',
        icon: Icons.account_tree_outlined,
        color: AppColors.primaryGreen,
        routeName: AppRoutes.projects,
      ),
      const _DashboardModule(
        title: 'Reports',
        detail: 'Submitted reports, engineer comments, and archive lookup.',
        icon: Icons.assignment_outlined,
        color: AppColors.fieldBlue,
        routeName: AppRoutes.reports,
      ),
      const _DashboardModule(
        title: 'Documents',
        detail: 'Contracts, drawings, certificates, and attachments.',
        icon: Icons.folder_copy_outlined,
        color: AppColors.ink,
      ),
      const _DashboardModule(
        title: 'Environment',
        detail: 'Safeguards, compliance checks, risks, and mitigation.',
        icon: Icons.eco_outlined,
        color: AppColors.primaryGreenDark,
      ),
      const _DashboardModule(
        title: 'Community',
        detail: 'Feedback, grievances, resolutions, and follow-up.',
        icon: Icons.groups_outlined,
        color: AppColors.civicRed,
      ),
    ];

    return switch (role) {
      UserRole.administrator => allModules,
      UserRole.projectManager => allModules,
      UserRole.siteEngineer => [allModules[0], allModules[1], allModules[2]],
      UserRole.contractor => [allModules[0], allModules[1], allModules[2]],
      UserRole.consultant => [allModules[0], allModules[1], allModules[3]],
      UserRole.clerkOfWorks => [allModules[0], allModules[1]],
      UserRole.districtEngineer => [
        allModules[0],
        allModules[1],
        allModules[4],
      ],
      UserRole.procurementOfficer => [allModules[0], allModules[2]],
      UserRole.communityRepresentative => [allModules[4]],
      UserRole.environmentOfficer => [allModules[0], allModules[3]],
      UserRole.communityDevelopmentOfficer => [allModules[3], allModules[4]],
      UserRole.unknown => allModules,
    };
  }

  List<_DashboardModule> _adminModulesForRole(UserRole role) {
    if (role != UserRole.administrator) {
      return const <_DashboardModule>[];
    }

    return const <_DashboardModule>[
      _DashboardModule(
        title: 'Users and roles',
        detail: 'Create user logins, update profiles, and assign roles.',
        icon: Icons.manage_accounts_outlined,
        color: AppColors.civicRed,
        routeName: AppRoutes.adminUsers,
      ),
    ];
  }
}

class _AdministratorDashboard extends StatefulWidget {
  const _AdministratorDashboard({
    required this.profile,
    required this.onEditProfile,
    required this.onSignOut,
  });

  final AppUser profile;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;

  @override
  State<_AdministratorDashboard> createState() =>
      _AdministratorDashboardState();
}

class _AdministratorDashboardState extends State<_AdministratorDashboard> {
  late final UsersRepository _usersRepository;
  late final ProjectsRepository _projectsRepository;
  late final ProjectMembersRepository _projectMembersRepository;
  late Future<_AdminDashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _usersRepository = UsersRepository();
    _projectsRepository = ProjectsRepository();
    _projectMembersRepository = ProjectMembersRepository();
    _dataFuture = _loadData();
  }

  Future<_AdminDashboardData> _loadData() async {
    final usersFuture = _usersRepository.getQuery(
      _usersRepository.allUsers(limit: 200),
    );
    final allProjectsFuture = _projectsRepository.getQuery(
      _projectsRepository.recent(limit: 100),
    );

    final results = await Future.wait([usersFuture, allProjectsFuture]);

    final users = results[0] as List<AppUser>;
    final projects = results[1] as List<Project>;
    final activeProjects = projects
        .where((project) => project.status == ProjectStatus.active)
        .toList(growable: false);
    final projectsWithoutManager = projects
        .where((project) => (project.projectManagerId ?? '').trim().isEmpty)
        .toList(growable: false);

    final setupChecks = await Future.wait(
      projects.map((project) async {
        final members = await _projectMembersRepository.getQuery(
          _projectMembersRepository.allMembersForProject(project.id),
        );
        return _ProjectSetupSnapshot(
          project: project,
          activeMembers: members
              .where((member) => member.status == ProjectMemberStatus.active)
              .toList(growable: false),
        );
      }),
    );

    return _AdminDashboardData(
      users: users,
      activeProjects: activeProjects,
      projectsWithoutManager: projectsWithoutManager,
      projectsWithoutTeam: setupChecks
          .where((item) => item.activeMembers.isEmpty)
          .map((item) => item.project)
          .toList(growable: false),
    );
  }

  Future<void> _refresh() {
    final dataFuture = _loadData();
    setState(() {
      _dataFuture = dataFuture;
    });

    return dataFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdminDashboardData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator(message: 'Loading command center');
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _AdminDashboardError(
            message: _adminDashboardErrorMessage(snapshot.error),
            onRetry: _refresh,
          );
        }

        return _AdministratorDashboardBody(
          profile: widget.profile,
          data: snapshot.data!,
          onRefresh: _refresh,
          onEditProfile: widget.onEditProfile,
          onSignOut: widget.onSignOut,
        );
      },
    );
  }

  String _adminDashboardErrorMessage(Object? error) {
    final rawMessage = error?.toString() ?? '';
    final normalizedMessage = rawMessage.toLowerCase();

    if (normalizedMessage.contains('permission-denied')) {
      return 'Firebase denied one of the admin dashboard reads. Confirm this account has the administrator role and deploy the latest Firestore rules.';
    }

    if (normalizedMessage.contains('requires an index') ||
        normalizedMessage.contains('failed-precondition')) {
      return 'Firebase is still missing an index for one dashboard query. Deploy Firestore indexes, then retry.';
    }

    if (rawMessage.trim().isNotEmpty) {
      return rawMessage;
    }

    return 'Check your connection and try again.';
  }
}

class _AdministratorDashboardBody extends StatelessWidget {
  const _AdministratorDashboardBody({
    required this.profile,
    required this.data,
    required this.onRefresh,
    required this.onEditProfile,
    required this.onSignOut,
  });

  final AppUser profile;
  final _AdminDashboardData data;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return _AdminDashboardScrollView(
      profile: profile,
      data: data,
      onRefresh: onRefresh,
      onEditProfile: onEditProfile,
      menuButton: _AdminMobileMenuButton(
        profile: profile,
        data: data,
        onEditProfile: onEditProfile,
        onSignOut: onSignOut,
      ),
    );
  }
}

class _AdminDashboardScrollView extends StatelessWidget {
  const _AdminDashboardScrollView({
    required this.profile,
    required this.data,
    required this.onRefresh,
    required this.onEditProfile,
    this.menuButton,
  });

  final AppUser profile;
  final _AdminDashboardData data;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditProfile;
  final Widget? menuButton;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveLayout.pagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppAnimatedEntry(
                  child: _AdminCommandHeader(
                    profile: profile,
                    onEditProfile: onEditProfile,
                  ),
                ),
                if (menuButton != null) ...[
                  const SizedBox(height: 12),
                  AppAnimatedEntry(index: 1, child: menuButton!),
                ],
                const SizedBox(height: 12),
                const AppAnimatedEntry(
                  index: 2,
                  child: _AdminAnnouncementShortcut(),
                ),
                const SizedBox(height: 18),
                AppAnimatedEntry(index: 3, child: _AdminStatsGrid(data: data)),
                const SizedBox(height: 22),
                Text('Project setup health', style: textTheme.titleLarge),
                const SizedBox(height: 12),
                AppAnimatedEntry(
                  index: 4,
                  child: _ProjectSetupHealth(data: data),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardIdentityHeader extends StatelessWidget {
  const _DashboardIdentityHeader({
    required this.profile,
    required this.fallbackName,
    required this.subtitle,
    required this.color,
    required this.fallbackIcon,
    this.onEditProfile,
  });

  final AppUser profile;
  final String fallbackName;
  final String subtitle;
  final Color color;
  final IconData fallbackIcon;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    final name = profile.fullName.trim().isEmpty
        ? fallbackName
        : profile.fullName.trim();
    final email = profile.email.trim();
    final district = profile.district.trim().isEmpty
        ? 'Uganda'
        : profile.district.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppStatusChip(
                      icon: Icons.badge_outlined,
                      label: profile.role.label,
                      color: color,
                    ),
                    AppStatusChip(
                      icon: Icons.location_on_outlined,
                      label: district,
                      color: AppColors.fieldBlue,
                    ),
                  ],
                ),
              ],
            );
            final editButton = onEditProfile == null
                ? null
                : OutlinedButton.icon(
                    onPressed: onEditProfile,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'),
                  );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashboardUserAvatar(
                        profile: profile,
                        color: color,
                        fallbackIcon: fallbackIcon,
                        size: 72,
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: details),
                    ],
                  ),
                  if (editButton != null) ...[
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: editButton),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardUserAvatar(
                  profile: profile,
                  color: color,
                  fallbackIcon: fallbackIcon,
                  size: 78,
                ),
                const SizedBox(width: 16),
                Expanded(child: details),
                if (editButton != null) ...[
                  const SizedBox(width: 12),
                  editButton,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardUserAvatar extends StatelessWidget {
  const _DashboardUserAvatar({
    required this.profile,
    required this.color,
    required this.fallbackIcon,
    required this.size,
  });

  final AppUser profile;
  final Color color;
  final IconData fallbackIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile.profileImage?.trim() ?? '';
    final initials = _initials(profile.fullName, profile.email);

    Widget child;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      child = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _InitialsAvatar(initials: initials, color: color);
        },
      );
    } else if (initials.isNotEmpty) {
      child = _InitialsAvatar(initials: initials, color: color);
    } else {
      child = Icon(fallbackIcon, color: Colors.white, size: size * 0.42);
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: 0.28), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: ColoredBox(color: color, child: child),
      ),
    );
  }

  String _initials(String name, String email) {
    final source = name.trim().isEmpty ? email : name;
    final parts = source
        .split(RegExp(r'\s+|@|\.|-|_'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList(growable: false);

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, required this.color});

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(
        child: Text(
          initials.isEmpty ? 'U' : initials,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AdminCommandHeader extends StatelessWidget {
  const _AdminCommandHeader({
    required this.profile,
    required this.onEditProfile,
  });

  final AppUser profile;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return _DashboardIdentityHeader(
      profile: profile,
      fallbackName: 'SiteConnect Administrator',
      subtitle: 'System administration.',
      color: AppColors.primaryGreen,
      fallbackIcon: Icons.admin_panel_settings_outlined,
      onEditProfile: onEditProfile,
    );
  }
}

class _AdminAnnouncementShortcut extends StatelessWidget {
  const _AdminAnnouncementShortcut();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.announcements),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              AppIconBadge(
                icon: Icons.campaign_outlined,
                color: AppColors.nationalGold,
                size: 44,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Announcements',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text('Likes, comments, and replies'),
                  ],
                ),
              ),
              Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDashboardError extends StatelessWidget {
  const _AdminDashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveLayout.pagePadding(context),
        child: AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load the administrator command center.',
          message: message,
          action: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ),
    );
  }
}

class _DistrictEngineerDashboard extends StatefulWidget {
  const _DistrictEngineerDashboard({
    required this.profile,
    required this.onEditProfile,
  });

  final AppUser profile;
  final VoidCallback onEditProfile;

  @override
  State<_DistrictEngineerDashboard> createState() =>
      _DistrictEngineerDashboardState();
}

class _DistrictEngineerDashboardState
    extends State<_DistrictEngineerDashboard> {
  late final ProjectsRepository _projectsRepository;
  late final ProjectMembersRepository _projectMembersRepository;
  late final SiteReportsRepository _siteReportsRepository;
  late Future<_DistrictEngineerDashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _projectsRepository = ProjectsRepository();
    _projectMembersRepository = ProjectMembersRepository();
    _siteReportsRepository = SiteReportsRepository();
    _dataFuture = _loadData();
  }

  Future<_DistrictEngineerDashboardData> _loadData() async {
    final projectsFuture = _projectsRepository.getQuery(
      _projectsRepository.recent(limit: 100),
    );
    final assignmentsFuture = _projectMembersRepository.getQuery(
      _projectMembersRepository.activeMembershipsForUser(
        widget.profile.uid,
        limit: 100,
      ),
    );
    final submittedReportsFuture = _siteReportsRepository.getQuery(
      _siteReportsRepository.reportsByStatus(
        ReportStatus.submitted,
        limit: 100,
      ),
    );
    final receivedReportsFuture = _siteReportsRepository.getQuery(
      _siteReportsRepository.reportsByStatus(ReportStatus.received, limit: 100),
    );

    final results = await Future.wait([
      projectsFuture,
      assignmentsFuture,
      submittedReportsFuture,
      receivedReportsFuture,
    ]);
    final allProjects = results[0] as List<Project>;
    final assignments = (results[1] as List<ProjectMember>)
        .where(
          (member) =>
              member.role == UserRole.districtEngineer &&
              member.status == ProjectMemberStatus.active,
        )
        .toList(growable: false);
    final assignedProjectIds = assignments
        .map((member) => member.projectId)
        .where((projectId) => projectId.trim().isNotEmpty)
        .toSet();
    final projectsById = {
      for (final project in allProjects) project.id: project,
    };

    for (final projectId in assignedProjectIds) {
      if (!projectsById.containsKey(projectId)) {
        final assignedProject = await _projectsRepository.findById(projectId);
        if (assignedProject != null) {
          projectsById[projectId] = assignedProject;
        }
      }
    }

    final projects = projectsById.values
        .where(
          (project) =>
              _projectBelongsToEngineerDistrict(project) ||
              assignedProjectIds.contains(project.id),
        )
        .toList(growable: false);
    final submittedReports = results[2] as List<SiteReport>;
    final receivedReports = results[3] as List<SiteReport>;
    final projectNamesById = {
      for (final project in projects) project.id: project.name,
    };
    final projectIds = projectNamesById.keys.toSet();
    final districtSubmittedReports =
        submittedReports
            .where((report) => projectIds.contains(report.projectId))
            .toList(growable: false)
          ..sort((a, b) => b.reportDate.compareTo(a.reportDate));
    final districtReceivedReports =
        receivedReports
            .where((report) => projectIds.contains(report.projectId))
            .toList(growable: false)
          ..sort((a, b) => b.reportDate.compareTo(a.reportDate));
    return _DistrictEngineerDashboardData(
      activeProjects: projects
          .where((project) => project.status == ProjectStatus.active)
          .toList(growable: false),
      submittedReports: districtSubmittedReports
          .take(20)
          .toList(growable: false),
      receivedReports: districtReceivedReports.take(20).toList(growable: false),
      projectNamesById: projectNamesById,
    );
  }

  bool _projectBelongsToEngineerDistrict(Project project) {
    final engineerDistrict = widget.profile.district.trim().toLowerCase();
    final projectDistrict = project.district.trim().toLowerCase();

    return engineerDistrict.isEmpty ||
        projectDistrict.isEmpty ||
        engineerDistrict == projectDistrict;
  }

  Future<void> _refresh() {
    final dataFuture = _loadData();
    setState(() {
      _dataFuture = dataFuture;
    });

    return dataFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DistrictEngineerDashboardData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator(
            message: 'Loading technical dashboard',
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _DistrictEngineerDashboardError(onRetry: _refresh);
        }

        return _DistrictEngineerDashboardBody(
          profile: widget.profile,
          data: snapshot.data!,
          onRefresh: _refresh,
          onEditProfile: widget.onEditProfile,
        );
      },
    );
  }
}

class _DistrictEngineerDashboardBody extends StatelessWidget {
  const _DistrictEngineerDashboardBody({
    required this.profile,
    required this.data,
    required this.onRefresh,
    required this.onEditProfile,
  });

  final AppUser profile;
  final _DistrictEngineerDashboardData data;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveLayout.pagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppAnimatedEntry(
                  child: _DistrictEngineerHeader(
                    profile: profile,
                    onEditProfile: onEditProfile,
                  ),
                ),
                const SizedBox(height: 18),
                AppAnimatedEntry(index: 1, child: _DistrictHubGrid(data: data)),
                const SizedBox(height: 18),
                AppAnimatedEntry(
                  index: 2,
                  child: _DistrictRecentActivity(data: data),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DistrictHubGrid extends StatelessWidget {
  const _DistrictHubGrid({required this.data});

  final _DistrictEngineerDashboardData data;

  @override
  Widget build(BuildContext context) {
    final modules = [
      _DistrictHubModule(
        title: 'Projects',
        count: data.activeProjects.length.toString(),
        detail: 'Active projects',
        icon: Icons.account_tree_outlined,
        color: AppColors.primaryGreen,
        routeName: AppRoutes.projects,
      ),
      _DistrictHubModule(
        title: 'Reports',
        count: data.submittedReports.length.toString(),
        detail: 'Awaiting receipt',
        icon: Icons.assignment_outlined,
        color: AppColors.fieldBlue,
        routeName: AppRoutes.reports,
        arguments: const ReportsRouteArguments(title: 'Reports'),
      ),
      const _DistrictHubModule(
        title: 'Announcements',
        count: '0',
        detail: 'Official notices',
        icon: Icons.campaign_outlined,
        color: AppColors.nationalGold,
        routeName: AppRoutes.announcements,
      ),
      const _DistrictHubModule(
        title: 'Messages',
        count: '0',
        detail: 'Team conversations',
        icon: Icons.forum_outlined,
        color: AppColors.civicRed,
        routeName: AppRoutes.messages,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: modules
              .map(
                (module) => SizedBox(
                  width: itemWidth,
                  child: _DistrictHubCard(module: module),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _DistrictHubCard extends StatelessWidget {
  const _DistrictHubCard({required this.module});

  final _DistrictHubModule module;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(module.routeName, arguments: module.arguments);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIconBadge(
                    icon: module.icon,
                    color: module.color,
                    size: 42,
                    iconSize: 22,
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.mutedInk),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                module.count,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                module.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                module.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistrictRecentActivity extends StatelessWidget {
  const _DistrictRecentActivity({required this.data});

  final _DistrictEngineerDashboardData data;

  @override
  Widget build(BuildContext context) {
    final activity =
        [
          ...data.submittedReports.map(
            (report) => _DistrictActivityItem(
              report: report,
              icon: Icons.mark_email_unread_outlined,
              color: AppColors.fieldBlue,
            ),
          ),
          ...data.receivedReports.map(
            (report) => _DistrictActivityItem(
              report: report,
              icon: Icons.mark_email_read_outlined,
              color: AppColors.primaryGreen,
            ),
          ),
        ]..sort((left, right) {
          final leftDate = left.report.submittedAt ?? left.report.updatedAt;
          final rightDate = right.report.submittedAt ?? right.report.updatedAt;
          return rightDate.compareTo(leftDate);
        });
    final visibleActivity = activity.take(5).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.reports,
                      arguments: const ReportsRouteArguments(title: 'Reports'),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Reports'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (visibleActivity.isEmpty)
              const AppEmptyState(
                icon: Icons.assignment_outlined,
                title: 'No report activity yet.',
              )
            else
              ...visibleActivity.map(
                (item) => _DistrictActivityTile(
                  item: item,
                  projectName:
                      data.projectNamesById[item.report.projectId] ??
                      'Project record',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DistrictActivityTile extends StatelessWidget {
  const _DistrictActivityTile({required this.item, required this.projectName});

  final _DistrictActivityItem item;
  final String projectName;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppIconBadge(
        icon: item.icon,
        color: item.color,
        size: 38,
        iconSize: 20,
      ),
      title: Text(
        item.report.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(projectName, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRoutes.reportDetails,
          arguments: ReportDetailsRouteArguments(
            reportId: item.report.id,
            projectId: item.report.projectId,
            report: item.report,
          ),
        );
      },
    );
  }
}

class _DistrictHubModule {
  const _DistrictHubModule({
    required this.title,
    required this.count,
    required this.detail,
    required this.icon,
    required this.color,
    required this.routeName,
    this.arguments,
  });

  final String title;
  final String count;
  final String detail;
  final IconData icon;
  final Color color;
  final String routeName;
  final Object? arguments;
}

class _DistrictActivityItem {
  const _DistrictActivityItem({
    required this.report,
    required this.icon,
    required this.color,
  });

  final SiteReport report;
  final IconData icon;
  final Color color;
}

class _DistrictEngineerHeader extends StatelessWidget {
  const _DistrictEngineerHeader({
    required this.profile,
    required this.onEditProfile,
  });

  final AppUser profile;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return _DashboardIdentityHeader(
      profile: profile,
      fallbackName: 'District Engineer',
      subtitle:
          'Receive submitted reports and monitor district project progress.',
      color: AppColors.fieldBlue,
      fallbackIcon: Icons.engineering_outlined,
      onEditProfile: onEditProfile,
    );
  }
}

class _DistrictEngineerDashboardError extends StatelessWidget {
  const _DistrictEngineerDashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveLayout.pagePadding(context),
        child: AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load the district engineer dashboard.',
          action: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ),
    );
  }
}

class _ClerkOfWorksDashboard extends StatefulWidget {
  const _ClerkOfWorksDashboard({
    required this.profile,
    required this.onEditProfile,
  });

  final AppUser profile;
  final VoidCallback onEditProfile;

  @override
  State<_ClerkOfWorksDashboard> createState() => _ClerkOfWorksDashboardState();
}

class _ClerkOfWorksDashboardState extends State<_ClerkOfWorksDashboard> {
  late final ProjectsRepository _projectsRepository;
  late final ProjectMembersRepository _projectMembersRepository;
  late final SiteReportsRepository _siteReportsRepository;
  late Future<_ClerkOfWorksDashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _projectsRepository = ProjectsRepository();
    _projectMembersRepository = ProjectMembersRepository();
    _siteReportsRepository = SiteReportsRepository();
    _dataFuture = _loadData();
  }

  Future<_ClerkOfWorksDashboardData> _loadData() async {
    final membershipsFuture = _projectMembersRepository.getQuery(
      _projectMembersRepository.activeMembershipsForUser(
        widget.profile.uid,
        limit: 100,
      ),
    );
    final reportsFuture = _siteReportsRepository.getQuery(
      _siteReportsRepository.reportsByAuthorSummary(
        widget.profile.uid,
        limit: 100,
      ),
    );

    final results = await Future.wait([membershipsFuture, reportsFuture]);
    final memberships = (results[0] as List<ProjectMember>)
        .where(
          (member) =>
              member.role == UserRole.clerkOfWorks &&
              member.status == ProjectMemberStatus.active,
        )
        .toList(growable: false);
    final reports = (results[1] as List<SiteReport>).toList(growable: false)
      ..sort((a, b) => b.reportDate.compareTo(a.reportDate));
    final projectIds = {
      ...memberships.map((member) => member.projectId),
      ...reports.map((report) => report.projectId),
    }.where((projectId) => projectId.trim().isNotEmpty).toSet();
    final projectsById = <String, Project>{};

    for (final projectId in projectIds) {
      final project = await _projectsRepository.findById(projectId);
      if (project != null) {
        projectsById[project.id] = project;
      }
    }

    final assignedProjects =
        memberships
            .map((member) => projectsById[member.projectId])
            .whereType<Project>()
            .toList(growable: false)
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

    return _ClerkOfWorksDashboardData(
      assignedProjects: assignedProjects,
      reports: reports,
      projectsById: projectsById,
      projectNamesById: {
        for (final entry in projectsById.entries) entry.key: entry.value.name,
      },
    );
  }

  Future<void> _refresh() {
    final dataFuture = _loadData();
    setState(() {
      _dataFuture = dataFuture;
    });

    return dataFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ClerkOfWorksDashboardData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator(
            message: 'Loading site supervision dashboard',
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _ClerkDashboardError(onRetry: _refresh);
        }

        return _ClerkDashboardBody(
          profile: widget.profile,
          data: snapshot.data!,
          onRefresh: _refresh,
          onEditProfile: widget.onEditProfile,
        );
      },
    );
  }
}

class _ClerkDashboardBody extends StatelessWidget {
  const _ClerkDashboardBody({
    required this.profile,
    required this.data,
    required this.onRefresh,
    required this.onEditProfile,
  });

  final AppUser profile;
  final _ClerkOfWorksDashboardData data;
  final Future<void> Function() onRefresh;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveLayout.pagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ResponsiveLayout.maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppAnimatedEntry(
                  child: _ClerkHeader(
                    profile: profile,
                    onEditProfile: onEditProfile,
                  ),
                ),
                const SizedBox(height: 18),
                AppAnimatedEntry(index: 1, child: _ClerkHubGrid(data: data)),
                const SizedBox(height: 18),
                AppAnimatedEntry(
                  index: 2,
                  child: _ClerkRecentActivity(data: data),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClerkHeader extends StatelessWidget {
  const _ClerkHeader({required this.profile, required this.onEditProfile});

  final AppUser profile;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return _DashboardIdentityHeader(
      profile: profile,
      fallbackName: 'Clerk of Works',
      subtitle: 'Submit site reports and track engineer comments.',
      color: AppColors.primaryGreen,
      fallbackIcon: Icons.construction_outlined,
      onEditProfile: onEditProfile,
    );
  }
}

class _ClerkHubGrid extends StatelessWidget {
  const _ClerkHubGrid({required this.data});

  final _ClerkOfWorksDashboardData data;

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ClerkHubModule(
        title: 'My Projects',
        count: data.assignedProjects.length.toString(),
        detail: 'Assigned sites',
        icon: Icons.account_tree_outlined,
        color: AppColors.primaryGreen,
        routeName: AppRoutes.projects,
      ),
      _ClerkHubModule(
        title: 'Reports',
        count: data.reports.length.toString(),
        detail:
            '${data.draftReports.length} draft${data.draftReports.length == 1 ? '' : 's'}',
        icon: Icons.assignment_outlined,
        color: AppColors.fieldBlue,
        routeName: AppRoutes.reports,
        arguments: const ReportsRouteArguments(title: 'My Reports'),
      ),
      const _ClerkHubModule(
        title: 'Submit Report',
        count: '+',
        detail: 'Choose project',
        icon: Icons.note_add_outlined,
        color: AppColors.primaryGreenDark,
        routeName: AppRoutes.submitReport,
      ),
      const _ClerkHubModule(
        title: 'Announcements',
        count: '0',
        detail: 'Site notices',
        icon: Icons.campaign_outlined,
        color: AppColors.nationalGold,
        routeName: AppRoutes.announcements,
      ),
      const _ClerkHubModule(
        title: 'Messages',
        count: '0',
        detail: 'Team chat',
        icon: Icons.forum_outlined,
        color: AppColors.civicRed,
        routeName: AppRoutes.messages,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 680
            ? 3
            : 2;
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: modules
              .map(
                (module) => SizedBox(
                  width: itemWidth,
                  child: _ClerkHubCard(module: module),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ClerkHubCard extends StatelessWidget {
  const _ClerkHubCard({required this.module});

  final _ClerkHubModule module;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(module.routeName, arguments: module.arguments);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIconBadge(
                    icon: module.icon,
                    color: module.color,
                    size: 42,
                    iconSize: 22,
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.mutedInk),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                module.count,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                module.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClerkRecentActivity extends StatelessWidget {
  const _ClerkRecentActivity({required this.data});

  final _ClerkOfWorksDashboardData data;

  @override
  Widget build(BuildContext context) {
    final recentReports = data.recentReports.take(5).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.reports,
                      arguments: const ReportsRouteArguments(
                        title: 'My Reports',
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Reports'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (recentReports.isEmpty)
              const AppEmptyState(
                icon: Icons.assignment_outlined,
                title: 'No report activity yet.',
              )
            else
              ...recentReports.map(
                (report) => _ClerkActivityTile(
                  report: report,
                  project: data.projectsById[report.projectId],
                  projectName:
                      data.projectNamesById[report.projectId] ??
                      'Project record',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClerkActivityTile extends StatelessWidget {
  const _ClerkActivityTile({
    required this.report,
    required this.project,
    required this.projectName,
  });

  final SiteReport report;
  final Project? project;
  final String projectName;

  @override
  Widget build(BuildContext context) {
    final statusColor = _reportStatusColor(report.status);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppIconBadge(
        icon: report.status == ReportStatus.draft
            ? Icons.edit_note_outlined
            : report.status == ReportStatus.received
            ? Icons.mark_email_read_outlined
            : Icons.outbox_outlined,
        color: statusColor,
        size: 38,
        iconSize: 20,
      ),
      title: Text(report.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$projectName • ${report.status.label}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if (report.status == ReportStatus.draft) {
          Navigator.of(context).pushNamed(
            AppRoutes.siteReportForm,
            arguments: SiteReportFormRouteArguments(
              projectId: report.projectId,
              project: project,
              report: report,
            ),
          );
          return;
        }

        Navigator.of(context).pushNamed(
          AppRoutes.reportDetails,
          arguments: ReportDetailsRouteArguments(
            reportId: report.id,
            projectId: report.projectId,
            report: report,
            project: project,
          ),
        );
      },
    );
  }
}

class _ClerkHubModule {
  const _ClerkHubModule({
    required this.title,
    required this.count,
    required this.detail,
    required this.icon,
    required this.color,
    required this.routeName,
    this.arguments,
  });

  final String title;
  final String count;
  final String detail;
  final IconData icon;
  final Color color;
  final String routeName;
  final Object? arguments;
}

Color _reportStatusColor(ReportStatus status) {
  return switch (status) {
    ReportStatus.draft => AppColors.mutedInk,
    ReportStatus.submitted => AppColors.fieldBlue,
    ReportStatus.received => AppColors.primaryGreen,
  };
}

class _ClerkDashboardError extends StatelessWidget {
  const _ClerkDashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveLayout.pagePadding(context),
        child: AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load the Clerk of Works dashboard.',
          action: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ),
    );
  }
}

class _AdminStatsGrid extends StatelessWidget {
  const _AdminStatsGrid({required this.data});

  final _AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _AdminStatCardData(
        label: 'Total users',
        value: data.users.length.toString(),
        icon: Icons.people_alt_outlined,
        color: AppColors.civicRed,
      ),
      _AdminStatCardData(
        label: 'Active projects',
        value: data.activeProjects.length.toString(),
        icon: Icons.account_tree_outlined,
        color: AppColors.primaryGreen,
      ),
      _AdminStatCardData(
        label: 'Without manager',
        value: data.projectsWithoutManager.length.toString(),
        icon: Icons.supervisor_account_outlined,
        color: AppColors.fieldBlue,
      ),
      _AdminStatCardData(
        label: 'Projects without team',
        value: data.projectsWithoutTeam.length.toString(),
        icon: Icons.group_off_outlined,
        color: AppColors.nationalGold,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: _AdminStatCard(data: card),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _AdminMobileMenuButton extends StatelessWidget {
  const _AdminMobileMenuButton({
    required this.profile,
    required this.data,
    required this.onEditProfile,
    required this.onSignOut,
  });

  final AppUser profile;
  final _AdminDashboardData data;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (context) {
              return _AdminNavigationSheet(
                profile: profile,
                data: data,
                onEditProfile: onEditProfile,
                onSignOut: onSignOut,
              );
            },
          );
        },
        icon: const Icon(Icons.menu_open_outlined),
        label: const Text('Menu'),
      ),
    );
  }
}

class _AdminNavigationSheet extends StatelessWidget {
  const _AdminNavigationSheet({
    required this.profile,
    required this.data,
    required this.onEditProfile,
    required this.onSignOut,
  });

  final AppUser profile;
  final _AdminDashboardData data;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _AdminNavigationPanel(
          profile: profile,
          data: data,
          onEditProfile: onEditProfile,
          onSignOut: onSignOut,
          compact: true,
          closeOnSelect: true,
        ),
      ),
    );
  }
}

class _AdminNavigationPanel extends StatelessWidget {
  const _AdminNavigationPanel({
    required this.profile,
    required this.data,
    required this.onEditProfile,
    required this.onSignOut,
    this.compact = false,
    this.closeOnSelect = false,
  });

  final AppUser profile;
  final _AdminDashboardData data;
  final VoidCallback onEditProfile;
  final VoidCallback onSignOut;
  final bool compact;
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context) {
    final mainItems = _mainItems();
    final accountItems = _accountItems();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: compact ? Colors.transparent : AppColors.surface,
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 0 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AdminNavigationHeader(profile: profile, compact: compact),
            const SizedBox(height: 14),
            Flexible(
              child: ListView(
                shrinkWrap: compact,
                children: [
                  ...mainItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AdminNavigationTile(
                        item: item,
                        closeOnSelect: closeOnSelect,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  ...accountItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AdminNavigationTile(
                        item: item,
                        closeOnSelect: closeOnSelect,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_AdminNavigationItem> _mainItems() {
    return [
      const _AdminNavigationItem(
        label: 'Dashboard',
        detail: 'Overview and alerts',
        icon: Icons.dashboard_outlined,
        color: AppColors.primaryGreen,
        selected: true,
      ),
      _AdminNavigationItem(
        label: 'Users & roles',
        detail: 'Manage logins and access',
        icon: Icons.manage_accounts_outlined,
        color: AppColors.civicRed,
        routeName: AppRoutes.adminUsers,
        badge: data.users.length.toString(),
      ),
      const _AdminNavigationItem(
        label: 'Add user',
        detail: 'Create a team login',
        icon: Icons.person_add_alt_1_outlined,
        color: AppColors.civicRed,
        routeName: AppRoutes.adminUserForm,
      ),
      _AdminNavigationItem(
        label: 'Projects',
        detail: 'Records and status',
        icon: Icons.account_tree_outlined,
        color: AppColors.fieldBlue,
        routeName: AppRoutes.projects,
        badge: data.activeProjects.length.toString(),
      ),
      const _AdminNavigationItem(
        label: 'Create project',
        detail: 'Start a new record',
        icon: Icons.add_business_outlined,
        color: AppColors.primaryGreen,
        routeName: AppRoutes.projectForm,
      ),
      const _AdminNavigationItem(
        label: 'Announcements',
        detail: 'Post notices',
        icon: Icons.campaign_outlined,
        color: AppColors.nationalGold,
        routeName: AppRoutes.announcements,
      ),
      const _AdminNavigationItem(
        label: 'Project teams',
        detail: 'Assign members from projects',
        icon: Icons.groups_2_outlined,
        color: AppColors.primaryGreenDark,
        routeName: AppRoutes.projects,
      ),
    ];
  }

  List<_AdminNavigationItem> _accountItems() {
    return [
      _AdminNavigationItem(
        label: 'Profile',
        detail: 'Edit admin details',
        icon: Icons.account_circle_outlined,
        color: AppColors.primaryGreen,
        onTap: onEditProfile,
      ),
      _AdminNavigationItem(
        label: 'Sign out',
        detail: 'Leave this session',
        icon: Icons.logout,
        color: AppColors.civicRed,
        onTap: onSignOut,
      ),
    ];
  }
}

class _AdminNavigationHeader extends StatelessWidget {
  const _AdminNavigationHeader({required this.profile, required this.compact});

  final AppUser profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final name = profile.fullName.trim().isEmpty
        ? 'Administrator'
        : profile.fullName.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DashboardUserAvatar(
          profile: profile,
          color: AppColors.primaryGreen,
          fallbackIcon: Icons.admin_panel_settings_outlined,
          size: 48,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Menu', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminNavigationTile extends StatelessWidget {
  const _AdminNavigationTile({required this.item, required this.closeOnSelect});

  final _AdminNavigationItem item;
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context) {
    final canOpen = item.routeName != null || item.onTap != null;
    final background = item.selected
        ? item.color.withValues(alpha: 0.10)
        : Colors.transparent;
    final border = item.selected
        ? item.color.withValues(alpha: 0.30)
        : Colors.transparent;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: canOpen ? () => _open(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              AppIconBadge(icon: item.icon, color: item.color, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: item.selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.detail!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (item.badge != null) ...[
                const SizedBox(width: 8),
                AppStatusChip(
                  icon: Icons.circle,
                  label: item.badge!,
                  color: item.color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final navigator = Navigator.of(context);

    if (closeOnSelect) {
      navigator.pop();
    }

    final action = item.onTap;
    if (action != null) {
      action();
      return;
    }

    final routeName = item.routeName;
    if (routeName != null) {
      navigator.pushNamed(routeName);
    }
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({required this.data});

  final _AdminStatCardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconBadge(icon: data.icon, color: data.color, size: 42),
            const SizedBox(height: 14),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: int.tryParse(data.value) ?? 0),
              duration: const Duration(milliseconds: 620),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Text(
                  value.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            Text(
              data.label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectSetupHealth extends StatelessWidget {
  const _ProjectSetupHealth({required this.data});

  final _AdminDashboardData data;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SetupHealthItem(
        title: 'Projects without Project Manager',
        count: data.projectsWithoutManager.length,
        icon: Icons.supervisor_account_outlined,
        color: AppColors.civicRed,
        projects: data.projectsWithoutManager,
      ),
      _SetupHealthItem(
        title: 'Projects without team',
        count: data.projectsWithoutTeam.length,
        icon: Icons.group_off_outlined,
        color: AppColors.nationalGold,
        projects: data.projectsWithoutTeam,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SetupHealthCard(item: item),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SetupHealthCard extends StatelessWidget {
  const _SetupHealthCard({required this.item});

  final _SetupHealthItem item;

  @override
  Widget build(BuildContext context) {
    final topProjects = item.projects.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconBadge(icon: item.icon, color: item.color, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      AppStatusChip(
                        icon: item.count == 0
                            ? Icons.check_circle_outline
                            : Icons.priority_high_outlined,
                        label: item.count.toString(),
                        color: item.count == 0
                            ? AppColors.primaryGreen
                            : item.color,
                      ),
                    ],
                  ),
                  if (topProjects.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'All clear.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    ...topProjects.map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          project.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (item.projects.length > topProjects.length)
                      Text(
                        '+${item.projects.length - topProjects.length} more',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Open projects',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.projects),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.profile, required this.onEditProfile});

  final AppUser profile;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return _DashboardIdentityHeader(
      profile: profile,
      fallbackName: 'Field team',
      subtitle: AppConstants.appTagline,
      color: AppColors.primaryGreen,
      fallbackIcon: Icons.verified_user_outlined,
      onEditProfile: onEditProfile,
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module});

  final _DashboardModule module;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: module.routeName == null
            ? null
            : () => Navigator.of(context).pushNamed(module.routeName!),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBadge(icon: module.icon, color: module.color, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      module.detail,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (module.routeName != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveLayout.pagePadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.civicRed,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardModule {
  const _DashboardModule({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    this.routeName,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final String? routeName;
}

class _AdminDashboardData {
  const _AdminDashboardData({
    required this.users,
    required this.activeProjects,
    required this.projectsWithoutManager,
    required this.projectsWithoutTeam,
  });

  final List<AppUser> users;
  final List<Project> activeProjects;
  final List<Project> projectsWithoutManager;
  final List<Project> projectsWithoutTeam;
}

class _DistrictEngineerDashboardData {
  const _DistrictEngineerDashboardData({
    required this.activeProjects,
    required this.submittedReports,
    required this.receivedReports,
    required this.projectNamesById,
  });

  final List<Project> activeProjects;
  final List<SiteReport> submittedReports;
  final List<SiteReport> receivedReports;
  final Map<String, String> projectNamesById;
}

class _ClerkOfWorksDashboardData {
  const _ClerkOfWorksDashboardData({
    required this.assignedProjects,
    required this.reports,
    required this.projectsById,
    required this.projectNamesById,
  });

  final List<Project> assignedProjects;
  final List<SiteReport> reports;
  final Map<String, Project> projectsById;
  final Map<String, String> projectNamesById;

  List<SiteReport> get draftReports => reports
      .where((report) => report.status == ReportStatus.draft)
      .toList(growable: false);

  List<SiteReport> get submittedReports => reports
      .where((report) => report.status == ReportStatus.submitted)
      .toList(growable: false);

  List<SiteReport> get receivedReports => reports
      .where((report) => report.status == ReportStatus.received)
      .toList(growable: false);

  List<SiteReport> get recentReports =>
      reports.take(10).toList(growable: false);
}

class _ProjectSetupSnapshot {
  const _ProjectSetupSnapshot({
    required this.project,
    required this.activeMembers,
  });

  final Project project;
  final List<ProjectMember> activeMembers;
}

class _AdminStatCardData {
  const _AdminStatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _SetupHealthItem {
  const _SetupHealthItem({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.projects,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final List<Project> projects;
}

class _AdminNavigationItem {
  const _AdminNavigationItem({
    required this.label,
    required this.icon,
    required this.color,
    this.detail,
    this.routeName,
    this.onTap,
    this.badge,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String? detail;
  final String? routeName;
  final VoidCallback? onTap;
  final String? badge;
  final bool selected;
}
