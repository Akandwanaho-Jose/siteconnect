import 'package:flutter/material.dart';

import '../../../../core/constants/firestore_enums.dart';
import '../../../../core/repositories/project_members_repository.dart';
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

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({
    FirebaseAuthService? authService,
    ProjectMembersRepository? projectMembersRepository,
    ProjectsRepository? projectsRepository,
    super.key,
  }) : _authService = authService,
       _projectMembersRepository = projectMembersRepository,
       _projectsRepository = projectsRepository;

  final FirebaseAuthService? _authService;
  final ProjectMembersRepository? _projectMembersRepository;
  final ProjectsRepository? _projectsRepository;

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  late final FirebaseAuthService _authService;
  late final ProjectMembersRepository _projectMembersRepository;
  late final ProjectsRepository _projectsRepository;
  late Future<_SubmitReportData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _projectMembersRepository =
        widget._projectMembersRepository ?? ProjectMembersRepository();
    _projectsRepository = widget._projectsRepository ?? ProjectsRepository();
    _dataFuture = _loadData();
  }

  Future<_SubmitReportData> _loadData() async {
    final profile = await _authService.fetchCurrentUserProfile();
    final memberships = await _projectMembersRepository.getQuery(
      _projectMembersRepository.activeMembershipsForUser(
        profile.uid,
        limit: 100,
      ),
    );
    final projectIds = memberships
        .where((member) => member.status == ProjectMemberStatus.active)
        .map((member) => member.projectId)
        .where((projectId) => projectId.trim().isNotEmpty)
        .toSet();
    final projects = <Project>[];

    for (final projectId in projectIds) {
      final project = await _projectsRepository.findById(projectId);
      if (project != null) {
        projects.add(project);
      }
    }

    projects.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

    return _SubmitReportData(profile: profile, projects: projects);
  }

  void _retry() {
    setState(() => _dataFuture = _loadData());
  }

  Future<void> _openReportForm(Project project) async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.siteReportForm,
      arguments: SiteReportFormRouteArguments(
        projectId: project.id,
        project: project,
      ),
    );

    if (!mounted || result is! String) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Submit Report',
      body: FutureBuilder<_SubmitReportData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Loading projects');
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _SubmitReportError(onRetry: _retry);
          }

          return _SubmitReportBody(
            data: snapshot.data!,
            onOpenProject: _openReportForm,
          );
        },
      ),
    );
  }
}

class _SubmitReportBody extends StatelessWidget {
  const _SubmitReportBody({required this.data, required this.onOpenProject});

  final _SubmitReportData data;
  final ValueChanged<Project> onOpenProject;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppAnimatedEntry(
                child: _SubmitReportHeader(
                  count: data.projects.length,
                  profile: data.profile,
                ),
              ),
              const SizedBox(height: 14),
              if (data.projects.isEmpty)
                const AppAnimatedEntry(
                  index: 1,
                  child: AppEmptyState(
                    icon: Icons.assignment_ind_outlined,
                    title: 'No assigned projects found.',
                  ),
                )
              else
                ...data.projects.asMap().entries.map(
                  (entry) => AppAnimatedEntry(
                    index: entry.key + 1,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SubmitProjectTile(
                        project: entry.value,
                        onTap: () => onOpenProject(entry.value),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitReportHeader extends StatelessWidget {
  const _SubmitReportHeader({required this.count, required this.profile});

  final int count;
  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const AppIconBadge(
              icon: Icons.note_add_outlined,
              color: AppColors.primaryGreen,
              size: 50,
              filled: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose project',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.fullName.trim().isEmpty
                        ? 'Assigned site reports'
                        : profile.fullName,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
                  ),
                ],
              ),
            ),
            AppStatusChip(
              icon: Icons.account_tree_outlined,
              label: '$count',
              color: AppColors.fieldBlue,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitProjectTile extends StatelessWidget {
  const _SubmitProjectTile({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const AppIconBadge(
          icon: Icons.location_city_outlined,
          color: AppColors.primaryGreen,
          size: 42,
          iconSize: 22,
        ),
        title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          project.district,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SubmitReportError extends StatelessWidget {
  const _SubmitReportError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveLayout.pagePadding(context),
        child: AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load assigned projects.',
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

class _SubmitReportData {
  const _SubmitReportData({required this.profile, required this.projects});

  final AppUser profile;
  final List<Project> projects;
}
