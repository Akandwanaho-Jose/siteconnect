import 'package:flutter/material.dart';

import '../../../../core/constants/firestore_enums.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/repositories/project_members_repository.dart';
import '../../../../core/repositories/projects_repository.dart';
import '../../../../core/repositories/role_based_query_service.dart';
import '../../../../core/services/auth_failure.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../routes/app_route_arguments.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/models/project_member.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({
    FirebaseAuthService? authService,
    ProjectsRepository? projectsRepository,
    ProjectMembersRepository? projectMembersRepository,
    super.key,
  }) : _authService = authService,
       _projectsRepository = projectsRepository,
       _projectMembersRepository = projectMembersRepository;

  final FirebaseAuthService? _authService;
  final ProjectsRepository? _projectsRepository;
  final ProjectMembersRepository? _projectMembersRepository;

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  late final FirebaseAuthService _authService;
  late final ProjectsRepository _projectsRepository;
  late final ProjectMembersRepository _projectMembersRepository;
  late final RoleBasedQueryService _roleQueryService;
  late Future<AppUser> _profileFuture;

  final _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _projectsRepository = widget._projectsRepository ?? ProjectsRepository();
    _projectMembersRepository =
        widget._projectMembersRepository ?? ProjectMembersRepository();
    _roleQueryService = RoleBasedQueryService(
      projectsRepository: _projectsRepository,
      projectMembersRepository: _projectMembersRepository,
    );
    _profileFuture = _authService.fetchCurrentUserProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retryProfileLoad() {
    setState(() {
      _profileFuture = _authService.fetchCurrentUserProfile();
    });
  }

  Future<void> _openProject(Project project) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.projectDetails,
      arguments: ProjectDetailsRouteArguments(
        projectId: project.id,
        project: project,
      ),
    );
  }

  Future<void> _openProjectForm() async {
    final result = await Navigator.of(context).pushNamed(AppRoutes.projectForm);

    if (!mounted || result is! String) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  List<Project> _filteredProjects(List<Project> projects) {
    final query = _searchTerm.trim().toLowerCase();
    if (query.isEmpty) {
      return projects;
    }

    return projects
        .where((project) {
          final haystack = [
            project.name,
            project.projectCode ?? '',
            project.district,
            project.contractorName ?? '',
            project.status.label,
          ].join(' ').toLowerCase();

          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Projects',
      body: FutureBuilder<AppUser>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Loading access');
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _ProjectsError(
              message: _profileErrorMessage(snapshot.error),
              onRetry: _retryProfileLoad,
            );
          }

          return _ProjectsForProfile(
            profile: snapshot.data!,
            roleQueryService: _roleQueryService,
            projectsRepository: _projectsRepository,
            filteredProjects: _filteredProjects,
            searchController: _searchController,
            searchTermChanged: (value) {
              setState(() => _searchTerm = value);
            },
            onOpenProject: _openProject,
            onCreateProject: _openProjectForm,
          );
        },
      ),
    );
  }

  String _profileErrorMessage(Object? error) {
    if (error is AuthFailure) {
      return error.message;
    }

    return 'Unable to load your project access.';
  }
}

class _ProjectsForProfile extends StatelessWidget {
  const _ProjectsForProfile({
    required this.profile,
    required this.roleQueryService,
    required this.projectsRepository,
    required this.filteredProjects,
    required this.searchController,
    required this.searchTermChanged,
    required this.onOpenProject,
    required this.onCreateProject,
  });

  final AppUser profile;
  final RoleBasedQueryService roleQueryService;
  final ProjectsRepository projectsRepository;
  final List<Project> Function(List<Project> projects) filteredProjects;
  final TextEditingController searchController;
  final ValueChanged<String> searchTermChanged;
  final ValueChanged<Project> onOpenProject;
  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    final directQuery = roleQueryService.directProjectsForUser(profile);

    if (directQuery != null) {
      return StreamBuilder<List<Project>>(
        stream: projectsRepository.watchQuery(directQuery),
        builder: (context, snapshot) {
          return _ProjectsListBody(
            snapshot: snapshot,
            profile: profile,
            filteredProjects: filteredProjects,
            searchController: searchController,
            searchTermChanged: searchTermChanged,
            onOpenProject: onOpenProject,
            onCreateProject: onCreateProject,
          );
        },
      );
    }

    return StreamBuilder<List<ProjectMember>>(
      stream: roleQueryService.projectMembersRepository.watchQuery(
        roleQueryService.membershipsForUser(profile.uid),
      ),
      builder: (context, membershipSnapshot) {
        if (membershipSnapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator(
            message: 'Loading assigned projects',
          );
        }

        if (membershipSnapshot.hasError) {
          return const _ProjectsError(
            message: 'Unable to load your project assignments.',
          );
        }

        final memberships = (membershipSnapshot.data ?? const <ProjectMember>[])
            .where((member) => member.status == ProjectMemberStatus.active)
            .toList(growable: false);
        if (memberships.isEmpty) {
          return _ProjectsListBody(
            snapshot: const AsyncSnapshot<List<Project>>.withData(
              ConnectionState.done,
              <Project>[],
            ),
            profile: profile,
            filteredProjects: filteredProjects,
            searchController: searchController,
            searchTermChanged: searchTermChanged,
            onOpenProject: onOpenProject,
            onCreateProject: onCreateProject,
          );
        }

        return FutureBuilder<List<Project>>(
          future: _projectsForMemberships(memberships),
          builder: (context, snapshot) {
            return _ProjectsListBody(
              snapshot: snapshot,
              profile: profile,
              filteredProjects: filteredProjects,
              searchController: searchController,
              searchTermChanged: searchTermChanged,
              onOpenProject: onOpenProject,
              onCreateProject: onCreateProject,
            );
          },
        );
      },
    );
  }

  Future<List<Project>> _projectsForMemberships(
    List<ProjectMember> memberships,
  ) async {
    final projects = <Project>[];
    final seenProjectIds = <String>{};

    for (final membership in memberships) {
      if (!seenProjectIds.add(membership.projectId)) {
        continue;
      }

      final project = await projectsRepository.findById(membership.projectId);
      if (project != null) {
        projects.add(project);
      }
    }

    projects.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return projects;
  }
}

class _ProjectsListBody extends StatelessWidget {
  const _ProjectsListBody({
    required this.snapshot,
    required this.profile,
    required this.filteredProjects,
    required this.searchController,
    required this.searchTermChanged,
    required this.onOpenProject,
    required this.onCreateProject,
  });

  final AsyncSnapshot<List<Project>> snapshot;
  final AppUser profile;
  final List<Project> Function(List<Project> projects) filteredProjects;
  final TextEditingController searchController;
  final ValueChanged<String> searchTermChanged;
  final ValueChanged<Project> onOpenProject;
  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const AppLoadingIndicator(message: 'Loading projects');
    }

    if (snapshot.hasError) {
      return const _ProjectsError(message: 'Unable to load projects.');
    }

    final projects = filteredProjects(snapshot.data ?? const <Project>[]);

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
              _ProjectsHeader(
                profile: profile,
                projectCount: projects.length,
                onCreateProject: _canCreateProjects(profile)
                    ? onCreateProject
                    : null,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Search projects',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: searchTermChanged,
              ),
              const SizedBox(height: 16),
              if (projects.isEmpty)
                const _EmptyProjects()
              else
                ...projects.map(
                  (project) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProjectCard(
                      project: project,
                      onTap: () => onOpenProject(project),
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

class _ProjectsHeader extends StatelessWidget {
  const _ProjectsHeader({
    required this.profile,
    required this.projectCount,
    required this.onCreateProject,
  });

  final AppUser profile;
  final int projectCount;
  final VoidCallback? onCreateProject;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_tree_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My projects', style: textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        '${profile.role.label} • ${profile.district}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoChip(
                        icon: Icons.folder_open_outlined,
                        label:
                            '$projectCount project${projectCount == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onCreateProject != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onCreateProject,
                  icon: const Icon(Icons.add_business_outlined),
                  label: const Text('New project'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

bool _canCreateProjects(AppUser profile) {
  return profile.role == UserRole.administrator ||
      profile.role == UserRole.projectManager;
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(project.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_city_outlined,
                  color: _statusColor(project.status),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.description,
                      style: textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
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

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.folder_off_outlined,
              color: AppColors.mutedInk,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              'No projects found.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectsError extends StatelessWidget {
  const _ProjectsError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

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
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
