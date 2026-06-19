import 'package:flutter/material.dart';

import '../../../../core/constants/firestore_enums.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/repositories/projects_repository.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../routes/app_route_arguments.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_motion.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_visuals.dart';

class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({
    required ProjectDetailsRouteArguments arguments,
    FirebaseAuthService? authService,
    ProjectsRepository? projectsRepository,
    super.key,
  }) : _arguments = arguments,
       _authService = authService,
       _projectsRepository = projectsRepository;

  final ProjectDetailsRouteArguments _arguments;
  final FirebaseAuthService? _authService;
  final ProjectsRepository? _projectsRepository;

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  late final FirebaseAuthService _authService;
  late final ProjectsRepository _projectsRepository;
  late final Future<AppUser> _profileFuture;
  late Future<Project?> _projectFuture;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _projectsRepository = widget._projectsRepository ?? ProjectsRepository();
    _profileFuture = _authService.fetchCurrentUserProfile();
    _projectFuture = widget._arguments.project == null
        ? _projectsRepository.findById(widget._arguments.projectId)
        : Future<Project?>.value(widget._arguments.project);
  }

  void _retryProjectLoad() {
    setState(() {
      _projectFuture = _projectsRepository.findById(
        widget._arguments.projectId,
      );
    });
  }

  Future<void> _openEditProject(Project project) async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.projectForm,
      arguments: ProjectFormRouteArguments(
        projectId: project.id,
        project: project,
      ),
    );

    if (!mounted || result is! String) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    setState(() {
      _projectFuture = _projectsRepository.findById(project.id);
    });
  }

  Future<void> _openProjectTeam(Project project) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.projectTeam,
      arguments: ProjectTeamRouteArguments(
        projectId: project.id,
        project: project,
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _projectFuture = _projectsRepository.findById(project.id);
    });
  }

  Future<void> _openSiteReports(Project project) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.siteReports,
      arguments: SiteReportsRouteArguments(
        projectId: project.id,
        project: project,
      ),
    );
  }

  bool _canEditProject(AppUser profile, Project project) {
    if (profile.role == UserRole.administrator) {
      return true;
    }

    if (profile.role != UserRole.projectManager) {
      return false;
    }

    return project.projectManagerId == profile.uid ||
        project.createdBy == profile.uid;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Project details',
      body: FutureBuilder<Project?>(
        future: _projectFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Loading project');
          }

          if (snapshot.hasError) {
            return _ProjectDetailsError(
              message: 'Unable to load this project.',
              onRetry: _retryProjectLoad,
            );
          }

          final project = snapshot.data;
          if (project == null) {
            return _ProjectDetailsError(
              message: 'This project could not be found.',
              onRetry: _retryProjectLoad,
            );
          }

          return FutureBuilder<AppUser>(
            future: _profileFuture,
            builder: (context, profileSnapshot) {
              final profile = profileSnapshot.data;
              final canEdit =
                  profile != null && _canEditProject(profile, project);

              return _ProjectDetailsBody(
                project: project,
                canEdit: canEdit,
                onEditProject: () => _openEditProject(project),
                onManageTeam: () => _openProjectTeam(project),
                onOpenSiteReports: () => _openSiteReports(project),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProjectDetailsBody extends StatelessWidget {
  const _ProjectDetailsBody({
    required this.project,
    required this.canEdit,
    required this.onEditProject,
    required this.onManageTeam,
    required this.onOpenSiteReports,
  });

  final Project project;
  final bool canEdit;
  final VoidCallback onEditProject;
  final VoidCallback onManageTeam;
  final VoidCallback onOpenSiteReports;

  @override
  Widget build(BuildContext context) {
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
                child: _ProjectHero(
                  project: project,
                  canEdit: canEdit,
                  onEditProject: onEditProject,
                  onManageTeam: onManageTeam,
                ),
              ),
              const SizedBox(height: 16),
              AppAnimatedEntry(index: 1, child: _FactsCard(project: project)),
              const SizedBox(height: 16),
              AppAnimatedEntry(
                index: 2,
                child: _TimelineCard(project: project),
              ),
              const SizedBox(height: 16),
              Text(
                'Project work',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              AppAnimatedEntry(
                index: 3,
                child: _WorkflowCard(
                  icon: Icons.assignment_outlined,
                  title: 'Site reports',
                  detail: 'Daily reports, observations, and progress notes.',
                  color: AppColors.fieldBlue,
                  onTap: onOpenSiteReports,
                ),
              ),
              const SizedBox(height: 12),
              const AppAnimatedEntry(
                index: 4,
                child: _WorkflowCard(
                  icon: Icons.photo_library_outlined,
                  title: 'Photo evidence',
                  detail: 'Photos linked to reports, defects, and milestones.',
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              const AppAnimatedEntry(
                index: 5,
                child: _WorkflowCard(
                  icon: Icons.folder_copy_outlined,
                  title: 'Documents',
                  detail: 'Contracts, drawings, certificates, and attachments.',
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectHero extends StatelessWidget {
  const _ProjectHero({
    required this.project,
    required this.canEdit,
    required this.onEditProject,
    required this.onManageTeam,
  });

  final Project project;
  final bool canEdit;
  final VoidCallback onEditProject;
  final VoidCallback onManageTeam;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconBadge(
                  icon: Icons.location_city_outlined,
                  color: _statusColor(project.status),
                  size: 52,
                  filled: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.name, style: textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(project.description, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((project.projectCode ?? '').trim().isNotEmpty)
                  _InfoChip(
                    icon: Icons.tag_outlined,
                    label: project.projectCode!,
                  ),
                _InfoChip(
                  icon: Icons.flag_outlined,
                  label: project.status.label,
                ),
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: project.district,
                ),
              ],
            ),
            if (canEdit) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEditProject,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit project'),
                  ),
                  FilledButton.icon(
                    onPressed: onManageTeam,
                    icon: const Icon(Icons.groups_2_outlined),
                    label: const Text('Manage team'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.active => AppColors.primaryGreen,
      ProjectStatus.completed => AppColors.fieldBlue,
      ProjectStatus.paused || ProjectStatus.cancelled => AppColors.civicRed,
      ProjectStatus.planning ||
      ProjectStatus.procurement ||
      ProjectStatus.mobilization => AppColors.ink,
    };
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contract facts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _FactRow(
              icon: Icons.business_outlined,
              label: 'Contractor',
              value: _valueOrDash(project.contractorName),
            ),
            _FactRow(
              icon: Icons.payments_outlined,
              label: 'Budget',
              value: _budget(project.budgetAmount),
            ),
            _FactRow(
              icon: Icons.map_outlined,
              label: 'Coordinates',
              value: _coordinates(project),
            ),
          ],
        ),
      ),
    );
  }

  String _budget(double? amount) {
    if (amount == null) {
      return '-';
    }

    return 'UGX ${amount.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
  }

  String _coordinates(Project project) {
    if (project.latitude == null || project.longitude == null) {
      return '-';
    }

    return '${project.latitude}, ${project.longitude}';
  }

  String _valueOrDash(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '-' : trimmed;
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _FactRow(
              icon: Icons.play_circle_outline,
              label: 'Start date',
              value: _date(project.startDate),
            ),
            _FactRow(
              icon: Icons.event_available_outlined,
              label: 'Expected end',
              value: _date(project.expectedEndDate),
            ),
            _FactRow(
              icon: Icons.update,
              label: 'Last updated',
              value: _date(project.updatedAt),
            ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime? value) {
    if (value == null || value.millisecondsSinceEpoch == 0) {
      return '-';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBadge(icon: icon, color: color, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              if (onTap != null) ...[
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

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.mutedInk, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.pageBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _ProjectDetailsError extends StatelessWidget {
  const _ProjectDetailsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
