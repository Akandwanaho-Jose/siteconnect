import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/firestore_enums.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/repositories/announcement_comments_repository.dart';
import '../../../../core/repositories/announcement_reactions_repository.dart';
import '../../../../core/repositories/announcements_repository.dart';
import '../../../../core/repositories/project_members_repository.dart';
import '../../../../core/repositories/projects_repository.dart';
import '../../../../core/services/announcement_image_storage_service.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../shared/models/announcement.dart';
import '../../../../shared/models/announcement_comment.dart';
import '../../../../shared/models/announcement_reaction.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/models/project_member.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_motion.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_visuals.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    FirebaseAuthService? authService,
    AnnouncementsRepository? announcementsRepository,
    AnnouncementCommentsRepository? announcementCommentsRepository,
    AnnouncementReactionsRepository? announcementReactionsRepository,
    ProjectsRepository? projectsRepository,
    ProjectMembersRepository? projectMembersRepository,
    AnnouncementImageStorageService? announcementImageStorageService,
    ImagePicker? imagePicker,
    super.key,
  }) : _authService = authService,
       _announcementsRepository = announcementsRepository,
       _announcementCommentsRepository = announcementCommentsRepository,
       _announcementReactionsRepository = announcementReactionsRepository,
       _projectsRepository = projectsRepository,
       _projectMembersRepository = projectMembersRepository,
       _announcementImageStorageService = announcementImageStorageService,
       _imagePicker = imagePicker;

  final FirebaseAuthService? _authService;
  final AnnouncementsRepository? _announcementsRepository;
  final AnnouncementCommentsRepository? _announcementCommentsRepository;
  final AnnouncementReactionsRepository? _announcementReactionsRepository;
  final ProjectsRepository? _projectsRepository;
  final ProjectMembersRepository? _projectMembersRepository;
  final AnnouncementImageStorageService? _announcementImageStorageService;
  final ImagePicker? _imagePicker;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late final FirebaseAuthService _authService;
  late final AnnouncementsRepository _announcementsRepository;
  late final AnnouncementCommentsRepository _announcementCommentsRepository;
  late final AnnouncementReactionsRepository _announcementReactionsRepository;
  late final ProjectsRepository _projectsRepository;
  late final ProjectMembersRepository _projectMembersRepository;
  late final AnnouncementImageStorageService _announcementImageStorageService;
  late final ImagePicker _imagePicker;
  late Future<_AnnouncementsAccessData> _accessFuture;
  bool _showArchived = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _announcementsRepository =
        widget._announcementsRepository ?? AnnouncementsRepository();
    _announcementCommentsRepository =
        widget._announcementCommentsRepository ??
        AnnouncementCommentsRepository();
    _announcementReactionsRepository =
        widget._announcementReactionsRepository ??
        AnnouncementReactionsRepository();
    _projectsRepository = widget._projectsRepository ?? ProjectsRepository();
    _projectMembersRepository =
        widget._projectMembersRepository ?? ProjectMembersRepository();
    _announcementImageStorageService =
        widget._announcementImageStorageService ??
        AnnouncementImageStorageService();
    _imagePicker = widget._imagePicker ?? ImagePicker();
    _accessFuture = _loadAccess();
  }

  Future<_AnnouncementsAccessData> _loadAccess() async {
    final profile = await _authService.fetchCurrentUserProfile();
    final projectsFuture = _projectsRepository.getQuery(
      _projectsRepository.recent(limit: 200),
    );
    final membershipsFuture = _projectMembersRepository.getQuery(
      _projectMembersRepository.activeMembershipsForUser(
        profile.uid,
        limit: 200,
      ),
    );

    final results = await Future.wait([projectsFuture, membershipsFuture]);
    final projects = (results[0] as List<Project>).toList(growable: false);
    final memberships = (results[1] as List<ProjectMember>)
        .where((member) => member.status == ProjectMemberStatus.active)
        .toList(growable: false);
    final assignedProjectIds = memberships
        .map((member) => member.projectId)
        .where((projectId) => projectId.trim().isNotEmpty)
        .toSet();
    final projectsById = {for (final project in projects) project.id: project};
    final availableProjects = _availableProjectsFor(
      profile: profile,
      projects: projects,
      assignedProjectIds: assignedProjectIds,
    );

    return _AnnouncementsAccessData(
      profile: profile,
      projectsById: projectsById,
      assignedProjectIds: assignedProjectIds,
      availableProjects: availableProjects,
    );
  }

  List<Project> _availableProjectsFor({
    required AppUser profile,
    required List<Project> projects,
    required Set<String> assignedProjectIds,
  }) {
    final district = profile.district.trim().toLowerCase();
    final visibleProjects = projects
        .where((project) {
          if (profile.role == UserRole.administrator) {
            return true;
          }

          if (assignedProjectIds.contains(project.id)) {
            return true;
          }

          if (profile.role == UserRole.projectManager) {
            return project.projectManagerId == profile.uid ||
                project.createdBy == profile.uid;
          }

          if (profile.role == UserRole.districtEngineer) {
            final projectDistrict = project.district.trim().toLowerCase();
            return district.isEmpty ||
                projectDistrict.isEmpty ||
                district == projectDistrict;
          }

          return false;
        })
        .toList(growable: false);

    visibleProjects.sort((left, right) => left.name.compareTo(right.name));
    return visibleProjects;
  }

  bool _canPost(AppUser profile) {
    return profile.role == UserRole.administrator ||
        profile.role == UserRole.projectManager ||
        profile.role == UserRole.districtEngineer;
  }

  List<Announcement> _visibleAnnouncements(
    List<Announcement> announcements,
    _AnnouncementsAccessData access,
  ) {
    final now = DateTime.now();
    return announcements
        .where((announcement) {
          if (_showArchived) {
            return _canSeeAnnouncement(announcement, access);
          }

          if (announcement.status != AnnouncementStatus.active) {
            return false;
          }

          if (announcement.publishAt.isAfter(now)) {
            return false;
          }

          final expiresAt = announcement.expiresAt;
          if (expiresAt != null && expiresAt.isBefore(now)) {
            return false;
          }

          return _canSeeAnnouncement(announcement, access);
        })
        .toList(growable: false)
      ..sort((left, right) => right.publishAt.compareTo(left.publishAt));
  }

  bool _canSeeAnnouncement(
    Announcement announcement,
    _AnnouncementsAccessData access,
  ) {
    final profile = access.profile;
    if (profile.role == UserRole.administrator ||
        announcement.createdBy == profile.uid) {
      return true;
    }

    return switch (announcement.scope) {
      AnnouncementScope.global => true,
      AnnouncementScope.district => _sameDistrict(
        profile.district,
        announcement.district,
      ),
      AnnouncementScope.project => _canSeeProjectAnnouncement(
        announcement,
        access,
      ),
    };
  }

  bool _sameDistrict(String userDistrict, String? announcementDistrict) {
    final userValue = userDistrict.trim().toLowerCase();
    final announcementValue = announcementDistrict?.trim().toLowerCase() ?? '';

    return userValue.isEmpty ||
        announcementValue.isEmpty ||
        userValue == announcementValue;
  }

  bool _canSeeProjectAnnouncement(
    Announcement announcement,
    _AnnouncementsAccessData access,
  ) {
    final projectId = announcement.projectId?.trim() ?? '';
    if (projectId.isEmpty) {
      return true;
    }

    if (access.assignedProjectIds.contains(projectId)) {
      return true;
    }

    final project = access.projectsById[projectId];
    if (project == null) {
      return false;
    }

    final profile = access.profile;
    if (profile.role == UserRole.projectManager) {
      return project.projectManagerId == profile.uid ||
          project.createdBy == profile.uid;
    }

    if (profile.role == UserRole.districtEngineer) {
      return _sameDistrict(profile.district, project.district);
    }

    return false;
  }

  Future<void> _createAnnouncement(_AnnouncementsAccessData access) async {
    final announcement = await showModalBottomSheet<Announcement>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AnnouncementComposerSheet(
        profile: access.profile,
        projects: access.availableProjects,
        newId: _announcementsRepository.newDocumentId(),
        imageStorageService: _announcementImageStorageService,
        imagePicker: _imagePicker,
      ),
    );

    if (announcement == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _announcementsRepository.save(announcement);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Announcement published.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to publish announcement.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _archiveAnnouncement(Announcement announcement) async {
    setState(() => _isSaving = true);
    try {
      await _announcementsRepository.archive(announcement.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Announcement archived.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to archive announcement.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _addComment({
    required AppUser profile,
    required Announcement announcement,
    required String body,
    AnnouncementComment? replyTo,
  }) async {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return;
    }

    try {
      final now = DateTime.now();
      final replyParentId = replyTo?.parentCommentId?.trim();
      final comment = AnnouncementComment(
        id: _announcementCommentsRepository.newDocumentId(),
        announcementId: announcement.id,
        body: trimmedBody,
        createdBy: profile.uid,
        authorName: _displayName(profile),
        authorRole: profile.role,
        createdAt: now,
        updatedAt: now,
        parentCommentId: replyParentId == null || replyParentId.isEmpty
            ? replyTo?.id
            : replyParentId,
        replyToAuthorName: replyTo?.authorName,
      );

      await _announcementCommentsRepository.save(comment);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to post this comment.')),
      );
    }
  }

  Future<void> _toggleReaction({
    required AppUser profile,
    required Announcement announcement,
    required AnnouncementReactionType type,
  }) async {
    try {
      final now = DateTime.now();
      final reaction = AnnouncementReaction(
        id: _announcementReactionsRepository.reactionDocumentId(
          announcementId: announcement.id,
          userId: profile.uid,
          type: type,
        ),
        announcementId: announcement.id,
        type: type,
        createdBy: profile.uid,
        authorName: _displayName(profile),
        authorRole: profile.role,
        createdAt: now,
        updatedAt: now,
      );

      await _announcementReactionsRepository.toggleReaction(reaction);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update reaction.')),
      );
    }
  }

  String _displayName(AppUser profile) {
    return profile.fullName.trim().isEmpty
        ? profile.email.trim()
        : profile.fullName.trim();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Announcements',
      body: Stack(
        children: [
          FutureBuilder<_AnnouncementsAccessData>(
            future: _accessFuture,
            builder: (context, accessSnapshot) {
              if (accessSnapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingIndicator(message: 'Loading notices');
              }

              if (accessSnapshot.hasError || accessSnapshot.data == null) {
                return _AnnouncementsError(
                  onRetry: () {
                    setState(() => _accessFuture = _loadAccess());
                  },
                );
              }

              final access = accessSnapshot.data!;

              return StreamBuilder<List<Announcement>>(
                stream: _announcementsRepository.watchQuery(
                  _announcementsRepository.recentAnnouncements(),
                ),
                builder: (context, announcementsSnapshot) {
                  if (announcementsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const AppLoadingIndicator(
                      message: 'Loading notices',
                    );
                  }

                  if (announcementsSnapshot.hasError) {
                    return _AnnouncementsError(
                      onRetry: () {
                        setState(() => _accessFuture = _loadAccess());
                      },
                    );
                  }

                  final announcements = _visibleAnnouncements(
                    announcementsSnapshot.data ?? const <Announcement>[],
                    access,
                  );

                  return _AnnouncementsBody(
                    access: access,
                    announcements: announcements,
                    commentsRepository: _announcementCommentsRepository,
                    reactionsRepository: _announcementReactionsRepository,
                    canPost: _canPost(access.profile),
                    showArchived: _showArchived,
                    onToggleArchived: (value) {
                      setState(() => _showArchived = value);
                    },
                    onCreate: () => _createAnnouncement(access),
                    onArchive: _archiveAnnouncement,
                    onAddComment: (announcement, body, replyTo) => _addComment(
                      profile: access.profile,
                      announcement: announcement,
                      body: body,
                      replyTo: replyTo,
                    ),
                    onToggleReaction: (announcement, type) => _toggleReaction(
                      profile: access.profile,
                      announcement: announcement,
                      type: type,
                    ),
                  );
                },
              );
            },
          ),
          if (_isSaving) const _SavingOverlay(),
        ],
      ),
    );
  }
}

class _AnnouncementsBody extends StatelessWidget {
  const _AnnouncementsBody({
    required this.access,
    required this.announcements,
    required this.commentsRepository,
    required this.reactionsRepository,
    required this.canPost,
    required this.showArchived,
    required this.onToggleArchived,
    required this.onCreate,
    required this.onArchive,
    required this.onAddComment,
    required this.onToggleReaction,
  });

  final _AnnouncementsAccessData access;
  final List<Announcement> announcements;
  final AnnouncementCommentsRepository commentsRepository;
  final AnnouncementReactionsRepository reactionsRepository;
  final bool canPost;
  final bool showArchived;
  final ValueChanged<bool> onToggleArchived;
  final VoidCallback onCreate;
  final ValueChanged<Announcement> onArchive;
  final Future<void> Function(
    Announcement announcement,
    String body,
    AnnouncementComment? replyTo,
  )
  onAddComment;
  final Future<void> Function(
    Announcement announcement,
    AnnouncementReactionType type,
  )
  onToggleReaction;

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
                child: _AnnouncementsHeader(
                  count: announcements.length,
                  canPost: canPost,
                  onCreate: onCreate,
                ),
              ),
              const SizedBox(height: 14),
              AppAnimatedEntry(
                index: 1,
                child: _AnnouncementControls(
                  showArchived: showArchived,
                  onToggleArchived: onToggleArchived,
                ),
              ),
              const SizedBox(height: 14),
              if (announcements.isEmpty)
                const AppAnimatedEntry(
                  index: 2,
                  child: AppEmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'No announcements yet.',
                  ),
                )
              else
                ...announcements.asMap().entries.map(
                  (entry) => AppAnimatedEntry(
                    index: entry.key + 2,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AnnouncementCard(
                        announcement: entry.value,
                        currentUser: access.profile,
                        commentsRepository: commentsRepository,
                        reactionsRepository: reactionsRepository,
                        canArchive:
                            canPost &&
                            entry.value.status == AnnouncementStatus.active,
                        onArchive: () => onArchive(entry.value),
                        onAddComment: (body, replyTo) =>
                            onAddComment(entry.value, body, replyTo),
                        onToggleReaction: (type) =>
                            onToggleReaction(entry.value, type),
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

class _AnnouncementsHeader extends StatelessWidget {
  const _AnnouncementsHeader({
    required this.count,
    required this.canPost,
    required this.onCreate,
  });

  final int count;
  final bool canPost;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AppIconBadge(
                  icon: Icons.campaign_outlined,
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
                        'Announcements',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Official notices, meetings, and project updates.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                AppStatusChip(
                  icon: Icons.inventory_2_outlined,
                  label: count.toString(),
                  color: AppColors.fieldBlue,
                ),
              ],
            ),
            if (canPost) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_alert_outlined),
                  label: const Text('New announcement'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnnouncementControls extends StatelessWidget {
  const _AnnouncementControls({
    required this.showArchived,
    required this.onToggleArchived,
  });

  final bool showArchived;
  final ValueChanged<bool> onToggleArchived;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        value: showArchived,
        onChanged: onToggleArchived,
        title: const Text('Show archived and expired notices'),
        secondary: const Icon(Icons.archive_outlined),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.currentUser,
    required this.commentsRepository,
    required this.reactionsRepository,
    required this.canArchive,
    required this.onArchive,
    required this.onAddComment,
    required this.onToggleReaction,
  });

  final Announcement announcement;
  final AppUser currentUser;
  final AnnouncementCommentsRepository commentsRepository;
  final AnnouncementReactionsRepository reactionsRepository;
  final bool canArchive;
  final VoidCallback onArchive;
  final Future<void> Function(String body, AnnouncementComment? replyTo)
  onAddComment;
  final Future<void> Function(AnnouncementReactionType type) onToggleReaction;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(announcement.priority);
    final targetLabel = _targetLabel(announcement);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconBadge(
                  icon: _priorityIcon(announcement.priority),
                  color: color,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${announcement.authorName} - ${_dateTime(announcement.publishAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canArchive)
                  IconButton(
                    tooltip: 'Archive',
                    onPressed: onArchive,
                    icon: const Icon(Icons.archive_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if ((announcement.imageUrl ?? '').trim().isNotEmpty) ...[
              _AnnouncementImage(imageUrl: announcement.imageUrl!.trim()),
              const SizedBox(height: 12),
            ],
            Text(announcement.body),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppStatusChip(
                  icon: _priorityIcon(announcement.priority),
                  label: announcement.priority.label,
                  color: color,
                ),
                AppStatusChip(
                  icon: _scopeIcon(announcement.scope),
                  label: targetLabel,
                  color: AppColors.fieldBlue,
                ),
                if (announcement.status == AnnouncementStatus.archived)
                  const AppStatusChip(
                    icon: Icons.archive_outlined,
                    label: 'Archived',
                    color: AppColors.mutedInk,
                  ),
                if (announcement.expiresAt != null)
                  AppStatusChip(
                    icon: Icons.event_busy_outlined,
                    label: 'Expires ${_date(announcement.expiresAt!)}',
                    color: AppColors.mutedInk,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _AnnouncementEngagementSection(
              announcement: announcement,
              currentUser: currentUser,
              commentsRepository: commentsRepository,
              reactionsRepository: reactionsRepository,
              onAddComment: onAddComment,
              onToggleReaction: onToggleReaction,
            ),
          ],
        ),
      ),
    );
  }

  String _targetLabel(Announcement announcement) {
    return switch (announcement.scope) {
      AnnouncementScope.global => 'All users',
      AnnouncementScope.district =>
        (announcement.district ?? '').trim().isEmpty
            ? 'District'
            : announcement.district!.trim(),
      AnnouncementScope.project =>
        (announcement.projectName ?? '').trim().isEmpty
            ? 'Project'
            : announcement.projectName!.trim(),
    };
  }

  IconData _priorityIcon(AnnouncementPriority priority) {
    return switch (priority) {
      AnnouncementPriority.normal => Icons.campaign_outlined,
      AnnouncementPriority.important => Icons.notification_important_outlined,
      AnnouncementPriority.urgent => Icons.warning_amber_outlined,
    };
  }

  Color _priorityColor(AnnouncementPriority priority) {
    return switch (priority) {
      AnnouncementPriority.normal => AppColors.primaryGreen,
      AnnouncementPriority.important => AppColors.fieldBlue,
      AnnouncementPriority.urgent => AppColors.civicRed,
    };
  }

  IconData _scopeIcon(AnnouncementScope scope) {
    return switch (scope) {
      AnnouncementScope.global => Icons.public_outlined,
      AnnouncementScope.district => Icons.location_on_outlined,
      AnnouncementScope.project => Icons.account_tree_outlined,
    };
  }
}

class _AnnouncementImage extends StatelessWidget {
  const _AnnouncementImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return ColoredBox(
              color: AppColors.border.withValues(alpha: 0.35),
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.mutedInk.withValues(alpha: 0.70),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementEngagementSection extends StatelessWidget {
  const _AnnouncementEngagementSection({
    required this.announcement,
    required this.currentUser,
    required this.commentsRepository,
    required this.reactionsRepository,
    required this.onAddComment,
    required this.onToggleReaction,
  });

  final Announcement announcement;
  final AppUser currentUser;
  final AnnouncementCommentsRepository commentsRepository;
  final AnnouncementReactionsRepository reactionsRepository;
  final Future<void> Function(String body, AnnouncementComment? replyTo)
  onAddComment;
  final Future<void> Function(AnnouncementReactionType type) onToggleReaction;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AnnouncementReaction>>(
      stream: reactionsRepository.watchQuery(
        reactionsRepository.reactionsForAnnouncement(announcement.id),
      ),
      builder: (context, reactionsSnapshot) {
        final reactions =
            reactionsSnapshot.data ?? const <AnnouncementReaction>[];

        return StreamBuilder<List<AnnouncementComment>>(
          stream: commentsRepository.watchQuery(
            commentsRepository.commentsForAnnouncement(announcement.id),
          ),
          builder: (context, commentsSnapshot) {
            final comments =
                [...(commentsSnapshot.data ?? const <AnnouncementComment>[])]
                  ..sort((left, right) {
                    return left.createdAt.compareTo(right.createdAt);
                  });

            if (reactionsSnapshot.hasError || commentsSnapshot.hasError) {
              return Text(
                'Unable to load discussion.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.civicRed),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AnnouncementReactionBar(
                  reactions: reactions,
                  currentUser: currentUser,
                  onToggleReaction: onToggleReaction,
                ),
                const SizedBox(height: 12),
                _AnnouncementCommentsPreview(
                  comments: comments,
                  onAddComment: onAddComment,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AnnouncementReactionBar extends StatelessWidget {
  const _AnnouncementReactionBar({
    required this.reactions,
    required this.currentUser,
    required this.onToggleReaction,
  });

  final List<AnnouncementReaction> reactions;
  final AppUser currentUser;
  final Future<void> Function(AnnouncementReactionType type) onToggleReaction;

  @override
  Widget build(BuildContext context) {
    final likesByUser = <String, AnnouncementReaction>{};
    for (final reaction in reactions) {
      if (reaction.type == AnnouncementReactionType.like) {
        likesByUser[reaction.createdBy] = reaction;
      }
    }

    final likes = likesByUser.values.toList(growable: false)
      ..sort((left, right) => left.authorName.compareTo(right.authorName));
    final selected = likesByUser.containsKey(currentUser.uid);
    const type = AnnouncementReactionType.like;
    final color = _reactionColor(type);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          avatar: Icon(
            _reactionIcon(type),
            size: 18,
            color: selected ? Colors.white : color,
          ),
          label: Text('Like ${likes.length}'),
          selected: selected,
          showCheckmark: false,
          selectedColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.24)),
          backgroundColor: color.withValues(alpha: 0.08),
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w700,
          ),
          onSelected: (_) => onToggleReaction(type),
        ),
        if (likes.isNotEmpty)
          TextButton.icon(
            onPressed: () => _showLikesSheet(context, likes),
            icon: const Icon(Icons.people_alt_outlined),
            label: const Text('View likes'),
          ),
      ],
    );
  }

  void _showLikesSheet(
    BuildContext context,
    List<AnnouncementReaction> reactions,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            itemCount: reactions.length + 1,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Liked by',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              }

              final reaction = reactions[index - 1];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.fieldBlue.withValues(alpha: 0.10),
                  child: Text(
                    _initials(reaction.authorName, reaction.authorRole.label),
                    style: const TextStyle(
                      color: AppColors.fieldBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(reaction.authorName),
                subtitle: Text(reaction.authorRole.label),
              );
            },
          ),
        );
      },
    );
  }
}

class _AnnouncementCommentsPreview extends StatefulWidget {
  const _AnnouncementCommentsPreview({
    required this.comments,
    required this.onAddComment,
  });

  final List<AnnouncementComment> comments;
  final Future<void> Function(String body, AnnouncementComment? replyTo)
  onAddComment;

  @override
  State<_AnnouncementCommentsPreview> createState() =>
      _AnnouncementCommentsPreviewState();
}

class _AnnouncementCommentsPreviewState
    extends State<_AnnouncementCommentsPreview> {
  AnnouncementComment? _replyTo;

  @override
  Widget build(BuildContext context) {
    final rootComments = widget.comments
        .where((comment) => (comment.parentCommentId ?? '').trim().isEmpty)
        .toList(growable: false);
    final repliesByParent = <String, List<AnnouncementComment>>{};
    for (final comment in widget.comments) {
      final parentId = comment.parentCommentId?.trim() ?? '';
      if (parentId.isEmpty) {
        continue;
      }

      repliesByParent.putIfAbsent(parentId, () => []).add(comment);
    }

    final commentLabel = widget.comments.length == 1
        ? '1 comment'
        : '${widget.comments.length} comments';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.comments.isNotEmpty) ...[
          Text(
            commentLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.mutedInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...rootComments.expand(
            (comment) => [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AnnouncementCommentTile(
                  comment: comment,
                  onReply: () => setState(() => _replyTo = comment),
                ),
              ),
              ...(repliesByParent[comment.id] ?? const <AnnouncementComment>[])
                  .map(
                    (reply) => Padding(
                      padding: const EdgeInsets.only(left: 28, bottom: 8),
                      child: _AnnouncementCommentTile(
                        comment: reply,
                        isReply: true,
                        onReply: () => setState(() => _replyTo = reply),
                      ),
                    ),
                  ),
            ],
          ),
        ],
        _AnnouncementCommentComposer(
          replyTo: _replyTo,
          onCancelReply: () => setState(() => _replyTo = null),
          onSubmit: (body) async {
            final replyTarget = _replyTo;
            await widget.onAddComment(body, replyTarget);
            if (mounted) {
              setState(() => _replyTo = null);
            }
          },
        ),
      ],
    );
  }
}

class _AnnouncementCommentTile extends StatelessWidget {
  const _AnnouncementCommentTile({
    required this.comment,
    required this.onReply,
    this.isReply = false,
  });

  final AnnouncementComment comment;
  final VoidCallback onReply;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(comment.authorName, comment.authorRole.label);
    final replyLabel = comment.replyToAuthorName?.trim() ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: isReply ? 14 : 16,
          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
          child: Text(
            initials,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    comment.authorName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    comment.authorRole.label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.mutedInk),
                  ),
                  Text(
                    _dateTime(comment.createdAt),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.mutedInk),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (replyLabel.isNotEmpty) ...[
                Text(
                  'Replying to $replyLabel',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.fieldBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(comment.body),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_outlined, size: 18),
                  label: const Text('Reply'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnnouncementCommentComposer extends StatefulWidget {
  const _AnnouncementCommentComposer({
    required this.onSubmit,
    required this.onCancelReply,
    this.replyTo,
  });

  final Future<void> Function(String body) onSubmit;
  final VoidCallback onCancelReply;
  final AnnouncementComment? replyTo;

  @override
  State<_AnnouncementCommentComposer> createState() =>
      _AnnouncementCommentComposerState();
}

class _AnnouncementCommentComposerState
    extends State<_AnnouncementCommentComposer> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(body);
      if (mounted) {
        _controller.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final replyTo = widget.replyTo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (replyTo != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.fieldBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.fieldBlue.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.reply_outlined,
                  size: 18,
                  color: AppColors.fieldBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Replying to ${replyTo.authorName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.fieldBlue,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel reply',
                  onPressed: widget.onCancelReply,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ],
        TextField(
          controller: _controller,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: replyTo == null ? 'Write a comment' : 'Write a reply',
            prefixIcon: const Icon(Icons.chat_bubble_outline),
            suffixIcon: IconButton(
              tooltip: 'Send',
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
            ),
          ),
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }
}

class _AnnouncementComposerSheet extends StatefulWidget {
  const _AnnouncementComposerSheet({
    required this.profile,
    required this.projects,
    required this.newId,
    required this.imageStorageService,
    required this.imagePicker,
  });

  final AppUser profile;
  final List<Project> projects;
  final String newId;
  final AnnouncementImageStorageService imageStorageService;
  final ImagePicker imagePicker;

  @override
  State<_AnnouncementComposerSheet> createState() =>
      _AnnouncementComposerSheetState();
}

class _AnnouncementComposerSheetState
    extends State<_AnnouncementComposerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  late AnnouncementScope _scope;
  AnnouncementPriority _priority = AnnouncementPriority.normal;
  String? _projectId;
  DateTime? _expiresAt;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isPublishing = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _scope = _scopeOptions.first;
    if (_scope == AnnouncementScope.project && widget.projects.isNotEmpty) {
      _projectId = widget.projects.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  List<AnnouncementScope> get _scopeOptions {
    return switch (widget.profile.role) {
      UserRole.administrator => AnnouncementScope.values,
      UserRole.districtEngineer => const [
        AnnouncementScope.district,
        AnnouncementScope.project,
      ],
      UserRole.projectManager => const [AnnouncementScope.project],
      _ => const [AnnouncementScope.project],
    };
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: DateTime(now.year + 2, 12, 31),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _expiresAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        23,
        59,
        59,
      );
    });
  }

  Future<void> _openImageSourceSheet() async {
    if (_isPickingImage || _isPublishing) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    await _pickAnnouncementImage(source);
  }

  Future<void> _pickAnnouncementImage(ImageSource source) async {
    setState(() => _isPickingImage = true);

    try {
      final image = await widget.imagePicker.pickImage(
        source: source,
        imageQuality: 84,
        maxWidth: 1400,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to select this image.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  Future<void> _publish() async {
    if (_isPublishing) {
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    setState(() => _isPublishing = true);
    try {
      String? imageUrl;
      String? imageStoragePath;
      final selectedImage = _selectedImage;
      if (selectedImage != null) {
        final upload = await widget.imageStorageService.uploadAnnouncementImage(
          image: selectedImage,
          announcementId: widget.newId,
        );
        imageUrl = upload.downloadUrl;
        imageStoragePath = upload.storagePath;
      }

      final now = DateTime.now();
      final project = _scope == AnnouncementScope.project
          ? widget.projects
                .where((item) => item.id == _projectId)
                .cast<Project?>()
                .firstOrNull
          : null;
      final authorName = widget.profile.fullName.trim().isEmpty
          ? widget.profile.email
          : widget.profile.fullName.trim();
      final announcement = Announcement(
        id: widget.newId,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        scope: _scope,
        priority: _priority,
        status: AnnouncementStatus.active,
        projectId: project?.id,
        projectName: project?.name,
        district: _scope == AnnouncementScope.district
            ? widget.profile.district.trim()
            : project?.district,
        createdBy: widget.profile.uid,
        authorName: authorName,
        authorRole: widget.profile.role,
        createdAt: now,
        updatedAt: now,
        publishAt: now,
        expiresAt: _expiresAt,
        imageUrl: imageUrl,
        imageStoragePath: imageStoragePath,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(announcement);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to publish announcement.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppIconBadge(
                    icon: Icons.campaign_outlined,
                    color: AppColors.primaryGreen,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'New announcement',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  return (value ?? '').trim().isEmpty
                      ? 'Enter an announcement title.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                validator: (value) {
                  return (value ?? '').trim().isEmpty
                      ? 'Enter the announcement message.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              _AnnouncementImagePickerPanel(
                selectedImageBytes: _selectedImageBytes,
                isBusy: _isPickingImage || _isPublishing,
                onPickImage: _openImageSourceSheet,
                onRemoveImage: _removeImage,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AnnouncementPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  prefixIcon: Icon(Icons.priority_high_outlined),
                ),
                items: AnnouncementPriority.values
                    .map(
                      (priority) => DropdownMenuItem<AnnouncementPriority>(
                        value: priority,
                        child: Text(priority.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _priority = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AnnouncementScope>(
                initialValue: _scope,
                decoration: const InputDecoration(
                  labelText: 'Audience',
                  prefixIcon: Icon(Icons.groups_2_outlined),
                ),
                items: _scopeOptions
                    .map(
                      (scope) => DropdownMenuItem<AnnouncementScope>(
                        value: scope,
                        child: Text(scope.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _scope = value;
                    if (_scope == AnnouncementScope.project &&
                        _projectId == null &&
                        widget.projects.isNotEmpty) {
                      _projectId = widget.projects.first.id;
                    }
                  });
                },
              ),
              if (_scope == AnnouncementScope.project) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _projectId,
                  decoration: const InputDecoration(
                    labelText: 'Project',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                  ),
                  items: widget.projects
                      .map(
                        (project) => DropdownMenuItem<String>(
                          value: project.id,
                          child: Text(project.name),
                        ),
                      )
                      .toList(growable: false),
                  validator: (value) {
                    return (value ?? '').trim().isEmpty
                        ? 'Select a project.'
                        : null;
                  },
                  onChanged: (value) => setState(() => _projectId = value),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickExpiryDate,
                icon: const Icon(Icons.event_busy_outlined),
                label: Text(
                  _expiresAt == null
                      ? 'Optional expiry date'
                      : 'Expires ${_date(_expiresAt!)}',
                ),
              ),
              if (_expiresAt != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _expiresAt = null),
                    icon: const Icon(Icons.close),
                    label: const Text('Clear expiry'),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isPublishing ? null : _publish,
                icon: _isPublishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_outlined),
                label: Text(
                  _isPublishing ? 'Publishing...' : 'Publish announcement',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementImagePickerPanel extends StatelessWidget {
  const _AnnouncementImagePickerPanel({
    required this.selectedImageBytes,
    required this.isBusy,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  final Uint8List? selectedImageBytes;
  final bool isBusy;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  @override
  Widget build(BuildContext context) {
    final imageBytes = selectedImageBytes;

    if (imageBytes == null) {
      return OutlinedButton.icon(
        onPressed: isBusy ? null : onPickImage,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add photo'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.memory(imageBytes, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: isBusy ? null : onPickImage,
              icon: const Icon(Icons.change_circle_outlined),
              label: const Text('Change photo'),
            ),
            TextButton.icon(
              onPressed: isBusy ? null : onRemoveImage,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnnouncementsAccessData {
  const _AnnouncementsAccessData({
    required this.profile,
    required this.projectsById,
    required this.assignedProjectIds,
    required this.availableProjects,
  });

  final AppUser profile;
  final Map<String, Project> projectsById;
  final Set<String> assignedProjectIds;
  final List<Project> availableProjects;
}

class _SavingOverlay extends StatelessWidget {
  const _SavingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.16),
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementsError extends StatelessWidget {
  const _AnnouncementsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveLayout.pagePadding(context),
        child: AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load announcements.',
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

IconData _reactionIcon(AnnouncementReactionType type) {
  return switch (type) {
    AnnouncementReactionType.like => Icons.thumb_up_alt_outlined,
  };
}

Color _reactionColor(AnnouncementReactionType type) {
  return switch (type) {
    AnnouncementReactionType.like => AppColors.fieldBlue,
  };
}

String _initials(String primary, String fallback) {
  final source = primary.trim().isEmpty ? fallback : primary;
  final parts = source
      .split(RegExp(r'\s+|@|\.|-|_'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList(growable: false);

  final value = parts.map((part) => part[0].toUpperCase()).join();
  return value.isEmpty ? 'U' : value;
}

String _date(DateTime value) {
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

String _dateTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';

  return '${_date(value)} $hour:$minute $period';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
