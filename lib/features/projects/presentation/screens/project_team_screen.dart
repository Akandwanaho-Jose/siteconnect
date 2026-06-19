import 'package:flutter/material.dart';

import '../../../../core/constants/firestore_enums.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/repositories/project_members_repository.dart';
import '../../../../core/repositories/projects_repository.dart';
import '../../../../core/repositories/users_repository.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../routes/app_route_arguments.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/models/project_member.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class ProjectTeamScreen extends StatefulWidget {
  const ProjectTeamScreen({
    required ProjectTeamRouteArguments arguments,
    FirebaseAuthService? authService,
    ProjectsRepository? projectsRepository,
    ProjectMembersRepository? projectMembersRepository,
    UsersRepository? usersRepository,
    super.key,
  }) : _arguments = arguments,
       _authService = authService,
       _projectsRepository = projectsRepository,
       _projectMembersRepository = projectMembersRepository,
       _usersRepository = usersRepository;

  final ProjectTeamRouteArguments _arguments;
  final FirebaseAuthService? _authService;
  final ProjectsRepository? _projectsRepository;
  final ProjectMembersRepository? _projectMembersRepository;
  final UsersRepository? _usersRepository;

  @override
  State<ProjectTeamScreen> createState() => _ProjectTeamScreenState();
}

class _ProjectTeamScreenState extends State<ProjectTeamScreen> {
  static const _assignableRoles = [
    UserRole.projectManager,
    UserRole.siteEngineer,
    UserRole.contractor,
    UserRole.consultant,
    UserRole.clerkOfWorks,
    UserRole.districtEngineer,
    UserRole.procurementOfficer,
    UserRole.communityRepresentative,
    UserRole.environmentOfficer,
    UserRole.communityDevelopmentOfficer,
  ];

  late final FirebaseAuthService _authService;
  late final ProjectsRepository _projectsRepository;
  late final ProjectMembersRepository _projectMembersRepository;
  late final UsersRepository _usersRepository;
  late final Future<AppUser> _profileFuture;
  late Future<Project?> _projectFuture;
  late Future<List<AppUser>> _usersFuture;

  final _formKey = GlobalKey<FormState>();
  String _selectedUserId = '';
  UserRole _selectedRole = UserRole.siteEngineer;
  ProjectMemberStatus _selectedStatus = ProjectMemberStatus.active;
  ProjectMember? _editingMember;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _projectsRepository = widget._projectsRepository ?? ProjectsRepository();
    _projectMembersRepository =
        widget._projectMembersRepository ?? ProjectMembersRepository();
    _usersRepository = widget._usersRepository ?? UsersRepository();
    _profileFuture = _authService.fetchCurrentUserProfile();
    _projectFuture = _loadProject();
    _usersFuture = _usersRepository.getQuery(_usersRepository.allUsers());
  }

  Future<Project?> _loadProject() {
    if (widget._arguments.project != null) {
      return Future<Project?>.value(widget._arguments.project);
    }

    return _projectsRepository.findById(widget._arguments.projectId);
  }

  bool _canManageProject(AppUser profile, Project project) {
    if (profile.role == UserRole.administrator) {
      return true;
    }

    if (profile.role != UserRole.projectManager) {
      return false;
    }

    return project.projectManagerId == profile.uid ||
        project.createdBy == profile.uid;
  }

  Future<void> _saveAssignment({
    required AppUser profile,
    required Project project,
    required List<ProjectMember> members,
  }) async {
    if (_isSaving) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final existingMember =
          _editingMember ?? _memberForUser(members, _selectedUserId);
      final member = ProjectMember(
        id:
            existingMember?.id ??
            _memberDocumentId(project.id, _selectedUserId),
        projectId: project.id,
        userId: _selectedUserId,
        role: _selectedRole,
        status: _selectedStatus,
        assignedAt: _selectedStatus == ProjectMemberStatus.active
            ? existingMember?.assignedAt ?? now
            : existingMember?.assignedAt,
        createdAt: existingMember?.createdAt ?? now,
        updatedAt: now,
        createdBy: existingMember?.createdBy ?? profile.uid,
      );

      await _projectMembersRepository.save(member);
      await _syncProjectManager(project: project, member: member);

      if (!mounted) {
        return;
      }

      _resetAssignmentForm();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project team assignment saved.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save this team assignment.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _quickUpdateStatus({
    required Project project,
    required ProjectMember member,
    required ProjectMemberStatus status,
  }) async {
    final now = DateTime.now();
    final updatedMember = member.copyWith(
      status: status,
      assignedAt: status == ProjectMemberStatus.active
          ? member.assignedAt ?? now
          : member.assignedAt,
      updatedAt: now,
    );

    try {
      await _projectMembersRepository.save(updatedMember);
      await _syncProjectManager(project: project, member: updatedMember);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assignment set to ${status.label}.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update assignment status.')),
      );
    }
  }

  Future<void> _syncProjectManager({
    required Project project,
    required ProjectMember member,
  }) async {
    if (member.role == UserRole.projectManager &&
        member.status == ProjectMemberStatus.active) {
      await _projectsRepository.updateFields(project.id, {
        'projectManagerId': member.userId,
      });
      if (mounted) {
        setState(() {
          _projectFuture = _projectsRepository.findById(project.id);
        });
      }
      return;
    }

    if (project.projectManagerId == member.userId) {
      await _projectsRepository.updateFields(project.id, {
        'projectManagerId': null,
      });
      if (mounted) {
        setState(() {
          _projectFuture = _projectsRepository.findById(project.id);
        });
      }
    }
  }

  void _startEditing(ProjectMember member) {
    setState(() {
      _editingMember = member;
      _selectedUserId = member.userId;
      _selectedRole = _assignableRoles.contains(member.role)
          ? member.role
          : UserRole.siteEngineer;
      _selectedStatus = member.status;
    });
  }

  void _resetAssignmentForm() {
    setState(() {
      _editingMember = null;
      _selectedUserId = '';
      _selectedRole = UserRole.siteEngineer;
      _selectedStatus = ProjectMemberStatus.active;
    });
    _formKey.currentState?.reset();
  }

  void _selectUser(String? userId, List<AppUser> users) {
    final selectedUserId = userId ?? '';
    setState(() {
      _selectedUserId = selectedUserId;
      final user = _userForId(users, selectedUserId);
      _selectedRole = _defaultRoleForUser(user);
    });
  }

  UserRole _defaultRoleForUser(AppUser? user) {
    if (user != null && _assignableRoles.contains(user.role)) {
      return user.role;
    }

    return UserRole.siteEngineer;
  }

  ProjectMember? _memberForUser(List<ProjectMember> members, String userId) {
    for (final member in members) {
      if (member.userId == userId) {
        return member;
      }
    }

    return null;
  }

  AppUser? _userForId(List<AppUser> users, String userId) {
    for (final user in users) {
      if (user.uid == userId) {
        return user;
      }
    }

    return null;
  }

  String _memberDocumentId(String projectId, String userId) {
    return '${projectId}_$userId';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Manage team',
      body: FutureBuilder<AppUser>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Checking access');
          }

          if (profileSnapshot.hasError || profileSnapshot.data == null) {
            return const _ProjectTeamError(message: 'Unable to load access.');
          }

          final profile = profileSnapshot.data!;

          return FutureBuilder<Project?>(
            future: _projectFuture,
            builder: (context, projectSnapshot) {
              if (projectSnapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingIndicator(message: 'Loading project');
              }

              final project = projectSnapshot.data;
              if (projectSnapshot.hasError || project == null) {
                return _ProjectTeamError(
                  message: 'Unable to load this project.',
                  onRetry: () {
                    setState(() => _projectFuture = _loadProject());
                  },
                );
              }

              if (!_canManageProject(profile, project)) {
                return const _ProjectTeamError(
                  message:
                      'Administrator or assigned project manager access is required.',
                );
              }

              return FutureBuilder<List<AppUser>>(
                future: _usersFuture,
                builder: (context, usersSnapshot) {
                  if (usersSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const AppLoadingIndicator(message: 'Loading users');
                  }

                  if (usersSnapshot.hasError) {
                    return _ProjectTeamError(
                      message: 'Unable to load users for assignment.',
                      onRetry: () {
                        setState(() {
                          _usersFuture = _usersRepository.getQuery(
                            _usersRepository.allUsers(),
                          );
                        });
                      },
                    );
                  }

                  return StreamBuilder<List<ProjectMember>>(
                    stream: _projectMembersRepository.watchQuery(
                      _projectMembersRepository.allMembersForProject(
                        project.id,
                      ),
                    ),
                    builder: (context, membersSnapshot) {
                      if (membersSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const AppLoadingIndicator(
                          message: 'Loading project team',
                        );
                      }

                      if (membersSnapshot.hasError) {
                        return const _ProjectTeamError(
                          message: 'Unable to load project team.',
                        );
                      }

                      final users = usersSnapshot.data ?? const <AppUser>[];
                      final members = _sortedMembers(
                        membersSnapshot.data ?? const <ProjectMember>[],
                        users,
                      );

                      return _ProjectTeamBody(
                        project: project,
                        users: users,
                        members: members,
                        selectedUserId: _selectedUserId,
                        selectedRole: _selectedRole,
                        selectedStatus: _selectedStatus,
                        editingMember: _editingMember,
                        isSaving: _isSaving,
                        formKey: _formKey,
                        onUserChanged: (userId) => _selectUser(userId, users),
                        onRoleChanged: (role) {
                          if (role == null) {
                            return;
                          }
                          setState(() => _selectedRole = role);
                        },
                        onStatusChanged: (status) {
                          if (status == null) {
                            return;
                          }
                          setState(() => _selectedStatus = status);
                        },
                        onSave: () => _saveAssignment(
                          profile: profile,
                          project: project,
                          members: members,
                        ),
                        onCancelEdit: _resetAssignmentForm,
                        onEditMember: _startEditing,
                        onUpdateStatus: (member, status) => _quickUpdateStatus(
                          project: project,
                          member: member,
                          status: status,
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<ProjectMember> _sortedMembers(
    List<ProjectMember> members,
    List<AppUser> users,
  ) {
    final userMap = {for (final user in users) user.uid: user};
    final sorted = [...members];
    sorted.sort((left, right) {
      final statusCompare = _statusRank(
        left.status,
      ).compareTo(_statusRank(right.status));
      if (statusCompare != 0) {
        return statusCompare;
      }

      final roleCompare = left.role.label.compareTo(right.role.label);
      if (roleCompare != 0) {
        return roleCompare;
      }

      return _userName(
        userMap[left.userId],
        left.userId,
      ).compareTo(_userName(userMap[right.userId], right.userId));
    });
    return sorted;
  }

  int _statusRank(ProjectMemberStatus status) {
    return switch (status) {
      ProjectMemberStatus.active => 0,
      ProjectMemberStatus.invited => 1,
      ProjectMemberStatus.suspended => 2,
      ProjectMemberStatus.removed => 3,
    };
  }

  String _userName(AppUser? user, String fallback) {
    final name = user?.fullName.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }

    final email = user?.email.trim() ?? '';
    return email.isEmpty ? fallback : email;
  }
}

class _ProjectTeamBody extends StatelessWidget {
  const _ProjectTeamBody({
    required this.project,
    required this.users,
    required this.members,
    required this.selectedUserId,
    required this.selectedRole,
    required this.selectedStatus,
    required this.editingMember,
    required this.isSaving,
    required this.formKey,
    required this.onUserChanged,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onSave,
    required this.onCancelEdit,
    required this.onEditMember,
    required this.onUpdateStatus,
  });

  final Project project;
  final List<AppUser> users;
  final List<ProjectMember> members;
  final String selectedUserId;
  final UserRole selectedRole;
  final ProjectMemberStatus selectedStatus;
  final ProjectMember? editingMember;
  final bool isSaving;
  final GlobalKey<FormState> formKey;
  final ValueChanged<String?> onUserChanged;
  final ValueChanged<UserRole?> onRoleChanged;
  final ValueChanged<ProjectMemberStatus?> onStatusChanged;
  final VoidCallback onSave;
  final VoidCallback onCancelEdit;
  final ValueChanged<ProjectMember> onEditMember;
  final void Function(ProjectMember member, ProjectMemberStatus status)
  onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    final userMap = {for (final user in users) user.uid: user};

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
              _ProjectSummaryCard(
                project: project,
                memberCount: members.length,
              ),
              const SizedBox(height: 16),
              _AssignmentFormCard(
                users: users,
                selectedUserId: selectedUserId,
                selectedRole: selectedRole,
                selectedStatus: selectedStatus,
                editingMember: editingMember,
                isSaving: isSaving,
                formKey: formKey,
                onUserChanged: onUserChanged,
                onRoleChanged: onRoleChanged,
                onStatusChanged: onStatusChanged,
                onSave: onSave,
                onCancelEdit: onCancelEdit,
              ),
              const SizedBox(height: 18),
              Text(
                'Current team',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (members.isEmpty)
                const _EmptyTeam()
              else
                ...members.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MemberCard(
                      member: member,
                      user: userMap[member.userId],
                      onEdit: () => onEditMember(member),
                      onUpdateStatus: (status) =>
                          onUpdateStatus(member, status),
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

class _ProjectSummaryCard extends StatelessWidget {
  const _ProjectSummaryCard({required this.project, required this.memberCount});

  final Project project;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.groups_2_outlined, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project.district,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
                  ),
                  const SizedBox(height: 10),
                  _InfoChip(
                    icon: Icons.people_alt_outlined,
                    label:
                        '$memberCount assignment${memberCount == 1 ? '' : 's'}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentFormCard extends StatelessWidget {
  const _AssignmentFormCard({
    required this.users,
    required this.selectedUserId,
    required this.selectedRole,
    required this.selectedStatus,
    required this.editingMember,
    required this.isSaving,
    required this.formKey,
    required this.onUserChanged,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onSave,
    required this.onCancelEdit,
  });

  final List<AppUser> users;
  final String selectedUserId;
  final UserRole selectedRole;
  final ProjectMemberStatus selectedStatus;
  final ProjectMember? editingMember;
  final bool isSaving;
  final GlobalKey<FormState> formKey;
  final ValueChanged<String?> onUserChanged;
  final ValueChanged<UserRole?> onRoleChanged;
  final ValueChanged<ProjectMemberStatus?> onStatusChanged;
  final VoidCallback onSave;
  final VoidCallback onCancelEdit;

  @override
  Widget build(BuildContext context) {
    final isEditing = editingMember != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Edit assignment' : 'Add team member',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('member_user_${editingMember?.id ?? 'new'}'),
                initialValue: selectedUserId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'User',
                  prefixIcon: Icon(Icons.person_add_alt_1_outlined),
                ),
                items: _userItems(),
                onChanged: isEditing ? null : onUserChanged,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Select a user.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<UserRole>(
                key: ValueKey('member_role_${editingMember?.id ?? 'new'}'),
                initialValue: selectedRole,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Project role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: _ProjectTeamScreenState._assignableRoles
                    .map(
                      (role) => DropdownMenuItem<UserRole>(
                        value: role,
                        child: Text(role.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onRoleChanged,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ProjectMemberStatus>(
                key: ValueKey('member_status_${editingMember?.id ?? 'new'}'),
                initialValue: selectedStatus,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assignment status',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
                items: ProjectMemberStatus.values
                    .map(
                      (status) => DropdownMenuItem<ProjectMemberStatus>(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onStatusChanged,
              ),
              const SizedBox(height: 18),
              AppButton(
                label: isEditing ? 'Save assignment' : 'Add member',
                icon: isEditing
                    ? Icons.save_outlined
                    : Icons.person_add_alt_1_outlined,
                isLoading: isSaving,
                onPressed: onSave,
              ),
              if (isEditing) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onCancelEdit,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel edit'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _userItems() {
    final activeUsers = users.where((user) => user.isActive).toList();
    final selectedUser = users.where((user) => user.uid == selectedUserId);

    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: '', child: Text('Select user')),
      ...activeUsers.map(
        (user) => DropdownMenuItem<String>(
          value: user.uid,
          child: Text(_userLabel(user), overflow: TextOverflow.ellipsis),
        ),
      ),
    ];

    if (selectedUserId.isNotEmpty &&
        !activeUsers.any((user) => user.uid == selectedUserId) &&
        selectedUser.isNotEmpty) {
      final user = selectedUser.first;
      items.add(
        DropdownMenuItem<String>(
          value: user.uid,
          child: Text(_userLabel(user), overflow: TextOverflow.ellipsis),
        ),
      );
    } else if (selectedUserId.isNotEmpty &&
        !activeUsers.any((user) => user.uid == selectedUserId)) {
      items.add(
        DropdownMenuItem<String>(
          value: selectedUserId,
          child: Text(
            'Unknown user ($selectedUserId)',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return items;
  }

  String _userLabel(AppUser user) {
    final name = user.fullName.trim();
    final email = user.email.trim();

    if (name.isEmpty) {
      return email;
    }

    if (email.isEmpty) {
      return name;
    }

    return '$name - $email';
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.user,
    required this.onEdit,
    required this.onUpdateStatus,
  });

  final ProjectMember member;
  final AppUser? user;
  final VoidCallback onEdit;
  final ValueChanged<ProjectMemberStatus> onUpdateStatus;

  @override
  Widget build(BuildContext context) {
    final name = _displayName();
    final email = user?.email.trim() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor(member.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person_outline,
                color: _statusColor(member.status),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.badge_outlined,
                        label: member.role.label,
                      ),
                      _InfoChip(
                        icon: Icons.verified_user_outlined,
                        label: member.status.label,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_MemberAction>(
              tooltip: 'Manage assignment',
              onSelected: (action) {
                switch (action) {
                  case _MemberAction.edit:
                    onEdit();
                  case _MemberAction.activate:
                    onUpdateStatus(ProjectMemberStatus.active);
                  case _MemberAction.suspend:
                    onUpdateStatus(ProjectMemberStatus.suspended);
                  case _MemberAction.remove:
                    onUpdateStatus(ProjectMemberStatus.removed);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_MemberAction>(
                  value: _MemberAction.edit,
                  child: Text('Edit'),
                ),
                PopupMenuItem<_MemberAction>(
                  value: _MemberAction.activate,
                  child: Text('Activate'),
                ),
                PopupMenuItem<_MemberAction>(
                  value: _MemberAction.suspend,
                  child: Text('Suspend'),
                ),
                PopupMenuItem<_MemberAction>(
                  value: _MemberAction.remove,
                  child: Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _displayName() {
    final name = user?.fullName.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }

    final email = user?.email.trim() ?? '';
    if (email.isNotEmpty) {
      return email;
    }

    return member.userId;
  }

  Color _statusColor(ProjectMemberStatus status) {
    return switch (status) {
      ProjectMemberStatus.active => AppColors.primaryGreen,
      ProjectMemberStatus.invited => AppColors.fieldBlue,
      ProjectMemberStatus.suspended ||
      ProjectMemberStatus.removed => AppColors.civicRed,
    };
  }
}

enum _MemberAction { edit, activate, suspend, remove }

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

class _EmptyTeam extends StatelessWidget {
  const _EmptyTeam();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.group_off_outlined,
              color: AppColors.mutedInk,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              'No team members assigned.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTeamError extends StatelessWidget {
  const _ProjectTeamError({required this.message, this.onRetry});

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
            const Icon(Icons.lock_outline, color: AppColors.civicRed, size: 40),
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
