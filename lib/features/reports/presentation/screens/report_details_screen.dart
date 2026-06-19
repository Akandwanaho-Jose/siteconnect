import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/firestore_enums.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/repositories/project_members_repository.dart';
import '../../../../core/repositories/projects_repository.dart';
import '../../../../core/repositories/report_comments_repository.dart';
import '../../../../core/repositories/site_reports_repository.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../routes/app_route_arguments.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/models/project_member.dart';
import '../../../../shared/models/report_comment.dart';
import '../../../../shared/models/site_report.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_motion.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_visuals.dart';
import '../../../../shared/widgets/report_comment_dialog.dart';

class ReportDetailsScreen extends StatefulWidget {
  const ReportDetailsScreen({
    required ReportDetailsRouteArguments arguments,
    FirebaseAuthService? authService,
    ProjectsRepository? projectsRepository,
    ProjectMembersRepository? projectMembersRepository,
    ReportCommentsRepository? reportCommentsRepository,
    SiteReportsRepository? siteReportsRepository,
    super.key,
  }) : _arguments = arguments,
       _authService = authService,
       _projectsRepository = projectsRepository,
       _projectMembersRepository = projectMembersRepository,
       _reportCommentsRepository = reportCommentsRepository,
       _siteReportsRepository = siteReportsRepository;

  final ReportDetailsRouteArguments _arguments;
  final FirebaseAuthService? _authService;
  final ProjectsRepository? _projectsRepository;
  final ProjectMembersRepository? _projectMembersRepository;
  final ReportCommentsRepository? _reportCommentsRepository;
  final SiteReportsRepository? _siteReportsRepository;

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  late final FirebaseAuthService _authService;
  late final ProjectsRepository _projectsRepository;
  late final ProjectMembersRepository _projectMembersRepository;
  late final ReportCommentsRepository _reportCommentsRepository;
  late final SiteReportsRepository _siteReportsRepository;
  late final Future<AppUser> _profileFuture;
  Future<Project?>? _projectFuture;
  String? _projectFutureKey;
  String? _savingMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _projectsRepository = widget._projectsRepository ?? ProjectsRepository();
    _projectMembersRepository =
        widget._projectMembersRepository ?? ProjectMembersRepository();
    _reportCommentsRepository =
        widget._reportCommentsRepository ?? ReportCommentsRepository();
    _siteReportsRepository =
        widget._siteReportsRepository ?? SiteReportsRepository();
    _profileFuture = _authService.fetchCurrentUserProfile();
  }

  Stream<SiteReport?> _reportStream() {
    if (widget._arguments.reportId.trim().isNotEmpty) {
      return _siteReportsRepository.watchById(widget._arguments.reportId);
    }

    return Stream<SiteReport?>.value(widget._arguments.report);
  }

  Future<Project?> _projectFutureFor(SiteReport report) {
    if (widget._arguments.project != null) {
      final key = widget._arguments.project!.id;
      if (_projectFutureKey != key) {
        _projectFutureKey = key;
        _projectFuture = Future<Project?>.value(widget._arguments.project);
      }

      return _projectFuture!;
    }

    final projectId = widget._arguments.projectId?.trim().isNotEmpty == true
        ? widget._arguments.projectId!.trim()
        : report.projectId;
    final key = projectId.trim();

    if (_projectFutureKey != key) {
      _projectFutureKey = key;
      _projectFuture = key.isEmpty
          ? Future<Project?>.value(null)
          : _projectsRepository.findById(key);
    }

    return _projectFuture!;
  }

  Future<void> _receiveReport({
    required AppUser profile,
    required SiteReport report,
  }) async {
    final comment = await _commentDialog(
      title: 'Receive report',
      actionLabel: 'Receive',
      initialComment: report.reviewFeedback,
    );
    if (comment == null) {
      return;
    }

    await _settleDialogRoute();
    if (!mounted) {
      return;
    }

    try {
      _setSavingMessage('Receiving report...');
      await _siteReportsRepository.receiveReport(
        report: report,
        receivedBy: profile.uid,
        comment: _blankToNull(comment),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report received.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to receive this report.')),
      );
    } finally {
      _setSavingMessage(null);
    }
  }

  Future<void> _commentOnReport(SiteReport report) async {
    final comment = await _commentDialog(
      title: 'Comment on report',
      actionLabel: 'Save comment',
      initialComment: report.reviewFeedback,
    );
    if (comment == null) {
      return;
    }

    await _settleDialogRoute();
    if (!mounted) {
      return;
    }

    try {
      _setSavingMessage('Saving comment...');
      await _siteReportsRepository.commentOnReport(
        reportId: report.id,
        comment: _blankToNull(comment),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comment saved.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save this comment.')),
      );
    } finally {
      _setSavingMessage(null);
    }
  }

  Future<String?> _commentDialog({
    required String title,
    required String actionLabel,
    String? initialComment,
  }) async {
    return ReportCommentDialog.show(
      context,
      title: title,
      actionLabel: actionLabel,
      initialComment: initialComment,
    );
  }

  Future<void> _settleDialogRoute() {
    return Future<void>.delayed(const Duration(milliseconds: 120));
  }

  void _setSavingMessage(String? message) {
    if (!mounted) {
      return;
    }

    setState(() => _savingMessage = message);
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _canReceiveReport({
    required AppUser profile,
    required Project? project,
    required List<ProjectMember> members,
  }) {
    if (profile.role != UserRole.districtEngineer || project == null) {
      return false;
    }

    final isAssignedToProject = members.any((member) {
      return member.userId == profile.uid &&
          member.role == UserRole.districtEngineer &&
          member.status == ProjectMemberStatus.active;
    });
    if (isAssignedToProject) {
      return true;
    }

    final engineerDistrict = profile.district.trim().toLowerCase();
    final projectDistrict = project.district.trim().toLowerCase();

    return engineerDistrict.isEmpty ||
        projectDistrict.isEmpty ||
        engineerDistrict == projectDistrict;
  }

  bool _canUseReportThread({
    required AppUser profile,
    required SiteReport report,
    required Project? project,
    required List<ProjectMember> members,
  }) {
    if (profile.role == UserRole.administrator) {
      return true;
    }

    if (report.createdBy == profile.uid) {
      return true;
    }

    if (profile.role == UserRole.projectManager && project != null) {
      return project.projectManagerId == profile.uid ||
          project.createdBy == profile.uid;
    }

    return _canReceiveReport(
      profile: profile,
      project: project,
      members: members,
    );
  }

  Future<void> _sendThreadMessage({
    required AppUser profile,
    required SiteReport report,
    required String body,
  }) async {
    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return;
    }

    try {
      _setSavingMessage('Sending reply...');
      final now = DateTime.now();
      final comment = ReportComment(
        id: _reportCommentsRepository.newDocumentId(),
        reportId: report.id,
        projectId: report.projectId,
        body: trimmedBody,
        createdBy: profile.uid,
        authorName: profile.fullName.trim().isEmpty
            ? profile.email
            : profile.fullName.trim(),
        authorRole: profile.role,
        createdAt: now,
        updatedAt: now,
      );

      await _reportCommentsRepository.save(comment);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reply sent.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send this reply.')),
      );
    } finally {
      _setSavingMessage(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Report Details',
      body: Stack(
        children: [
          FutureBuilder<AppUser>(
            future: _profileFuture,
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingIndicator(message: 'Checking access');
              }

              if (profileSnapshot.hasError || profileSnapshot.data == null) {
                return const _ReportDetailsError();
              }

              final profile = profileSnapshot.data!;

              return StreamBuilder<SiteReport?>(
                stream: _reportStream(),
                builder: (context, reportSnapshot) {
                  if (reportSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const AppLoadingIndicator(message: 'Loading report');
                  }

                  final report = reportSnapshot.data;
                  if (reportSnapshot.hasError || report == null) {
                    return const _ReportDetailsError();
                  }

                  return FutureBuilder<Project?>(
                    future: _projectFutureFor(report),
                    builder: (context, projectSnapshot) {
                      if (projectSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const AppLoadingIndicator(
                          message: 'Loading project',
                        );
                      }

                      final project = projectSnapshot.data;

                      if (project == null) {
                        final canUseThread = _canUseReportThread(
                          profile: profile,
                          report: report,
                          project: null,
                          members: const <ProjectMember>[],
                        );
                        return _ReportDetailsBody(
                          profile: profile,
                          report: report,
                          project: null,
                          commentsRepository: _reportCommentsRepository,
                          canUseDiscussion: canUseThread,
                          onReceive: null,
                          onComment: null,
                          onSendMessage: canUseThread
                              ? (body) => _sendThreadMessage(
                                  profile: profile,
                                  report: report,
                                  body: body,
                                )
                              : null,
                        );
                      }

                      return StreamBuilder<List<ProjectMember>>(
                        stream: _projectMembersRepository.watchQuery(
                          _projectMembersRepository.allMembersForProject(
                            project.id,
                          ),
                        ),
                        builder: (context, membersSnapshot) {
                          final members =
                              membersSnapshot.data ?? const <ProjectMember>[];
                          final canReceive = _canReceiveReport(
                            profile: profile,
                            project: project,
                            members: members,
                          );
                          final canUseThread = _canUseReportThread(
                            profile: profile,
                            report: report,
                            project: project,
                            members: members,
                          );

                          return _ReportDetailsBody(
                            profile: profile,
                            report: report,
                            project: project,
                            commentsRepository: _reportCommentsRepository,
                            canUseDiscussion: canUseThread,
                            onReceive:
                                canReceive &&
                                    report.status == ReportStatus.submitted
                                ? () => _receiveReport(
                                    profile: profile,
                                    report: report,
                                  )
                                : null,
                            onComment: canReceive
                                ? () => _commentOnReport(report)
                                : null,
                            onSendMessage: canUseThread
                                ? (body) => _sendThreadMessage(
                                    profile: profile,
                                    report: report,
                                    body: body,
                                  )
                                : null,
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          if (_savingMessage != null) _ReportSavingOverlay(_savingMessage!),
        ],
      ),
    );
  }
}

class _ReportSavingOverlay extends StatelessWidget {
  const _ReportSavingOverlay(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.18),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Text(message),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportDetailsBody extends StatelessWidget {
  const _ReportDetailsBody({
    required this.profile,
    required this.report,
    required this.project,
    required this.commentsRepository,
    required this.canUseDiscussion,
    required this.onReceive,
    required this.onComment,
    required this.onSendMessage,
  });

  final AppUser profile;
  final SiteReport report;
  final Project? project;
  final ReportCommentsRepository commentsRepository;
  final bool canUseDiscussion;
  final VoidCallback? onReceive;
  final VoidCallback? onComment;
  final ValueChanged<String>? onSendMessage;

  @override
  Widget build(BuildContext context) {
    final hasPdf = (report.pdfDownloadUrl ?? '').trim().isNotEmpty;
    final comment = report.reviewFeedback?.trim() ?? '';

    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppAnimatedEntry(
                child: _ReportHeaderCard(report: report, project: project),
              ),
              const SizedBox(height: 14),
              AppAnimatedEntry(
                index: 1,
                child: _ReportPdfCard(report: report, hasPdf: hasPdf),
              ),
              const SizedBox(height: 14),
              AppAnimatedEntry(
                index: 2,
                child: _ReportCommentCard(
                  comment: comment,
                  onComment: onComment,
                ),
              ),
              const SizedBox(height: 14),
              AppAnimatedEntry(
                index: 3,
                child: _ReportDiscussionCard(
                  report: report,
                  currentUser: profile,
                  commentsRepository: commentsRepository,
                  canUseDiscussion: canUseDiscussion,
                  onSendMessage: onSendMessage,
                ),
              ),
              const SizedBox(height: 14),
              AppAnimatedEntry(
                index: 4,
                child: _ReportTimelineCard(report: report),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (onReceive != null)
                    FilledButton.icon(
                      onPressed: onReceive,
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: const Text('Receive'),
                    ),
                  if (hasPdf)
                    OutlinedButton.icon(
                      onPressed: () => _openReportPdf(context, report),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('View PDF'),
                    ),
                  if (project != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.projectDetails,
                          arguments: ProjectDetailsRouteArguments(
                            projectId: project!.id,
                            project: project,
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_tree_outlined),
                      label: const Text('Project'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportHeaderCard extends StatelessWidget {
  const _ReportHeaderCard({required this.report, required this.project});

  final SiteReport report;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIconBadge(
                  icon: report.status == ReportStatus.received
                      ? Icons.mark_email_read_outlined
                      : Icons.assignment_outlined,
                  color: _statusColor(report.status),
                  size: 50,
                  filled: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        project?.name ?? 'Project record',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppStatusChip(
                  icon: Icons.flag_outlined,
                  label: report.status.label,
                  color: _statusColor(report.status),
                ),
                AppStatusChip(
                  icon: Icons.event_outlined,
                  label: _date(report.reportDate),
                  color: AppColors.fieldBlue,
                ),
                AppStatusChip(
                  icon: Icons.person_outline,
                  label: report.authorRole.label,
                  color: AppColors.primaryGreen,
                ),
              ],
            ),
            if (report.summary.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(report.summary.trim()),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportPdfCard extends StatelessWidget {
  const _ReportPdfCard({required this.report, required this.hasPdf});

  final SiteReport report;
  final bool hasPdf;

  @override
  Widget build(BuildContext context) {
    final fileName = report.pdfFileName?.trim() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AppIconBadge(
              icon: hasPdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.attach_file_outlined,
              color: hasPdf ? AppColors.civicRed : AppColors.mutedInk,
              size: 44,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName.isEmpty ? 'No file attached' : fileName,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (report.pdfFileSizeBytes != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _fileSize(report.pdfFileSizeBytes!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasPdf)
              IconButton(
                tooltip: 'View PDF',
                onPressed: () => _openReportPdf(context, report),
                icon: const Icon(Icons.open_in_new),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportCommentCard extends StatelessWidget {
  const _ReportCommentCard({required this.comment, required this.onComment});

  final String comment;
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AppIconBadge(
                  icon: Icons.comment_outlined,
                  color: AppColors.primaryGreen,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Engineer Comment',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onComment != null)
                  IconButton(
                    tooltip: 'Comment',
                    onPressed: onComment,
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              comment.isEmpty ? 'No comment recorded.' : comment,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: comment.isEmpty ? AppColors.mutedInk : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportDiscussionCard extends StatelessWidget {
  const _ReportDiscussionCard({
    required this.report,
    required this.currentUser,
    required this.commentsRepository,
    required this.canUseDiscussion,
    required this.onSendMessage,
  });

  final SiteReport report;
  final AppUser currentUser;
  final ReportCommentsRepository commentsRepository;
  final bool canUseDiscussion;
  final ValueChanged<String>? onSendMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AppIconBadge(
                  icon: Icons.forum_outlined,
                  color: AppColors.fieldBlue,
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Report Discussion',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!canUseDiscussion)
              const AppEmptyState(
                icon: Icons.lock_outline,
                title: 'Discussion is limited to this report team.',
              )
            else
              StreamBuilder<List<ReportComment>>(
                stream: commentsRepository.watchQuery(
                  commentsRepository.commentsForReport(
                    report.id,
                    projectId: report.projectId,
                  ),
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return const AppEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to load report discussion.',
                      message:
                          'Check Firestore rules, then reopen this report.',
                    );
                  }

                  final comments =
                      (snapshot.data ?? const <ReportComment>[]).toList()..sort(
                        (left, right) =>
                            left.createdAt.compareTo(right.createdAt),
                      );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (comments.isEmpty)
                        const AppEmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: 'No replies yet.',
                          message:
                              'Start a report-specific discussion here so every query stays traceable.',
                        )
                      else
                        ...comments.map(
                          (comment) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ReportDiscussionBubble(
                              comment: comment,
                              isCurrentUser:
                                  comment.createdBy == currentUser.uid,
                            ),
                          ),
                        ),
                      if (onSendMessage != null) ...[
                        const SizedBox(height: 8),
                        _ReportReplyComposer(onSendMessage: onSendMessage!),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportDiscussionBubble extends StatelessWidget {
  const _ReportDiscussionBubble({
    required this.comment,
    required this.isCurrentUser,
  });

  final ReportComment comment;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final color = isCurrentUser ? AppColors.fieldBlue : AppColors.primaryGreen;
    final alignment = isCurrentUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: isCurrentUser ? 0.10 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          comment.authorName.trim().isEmpty
                              ? comment.authorRole.label
                              : comment.authorName.trim(),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppStatusChip(
                        icon: Icons.badge_outlined,
                        label: comment.authorRole.label,
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(comment.body),
                  const SizedBox(height: 8),
                  Text(
                    _dateTime(comment.createdAt),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportReplyComposer extends StatefulWidget {
  const _ReportReplyComposer({required this.onSendMessage});

  final ValueChanged<String> onSendMessage;

  @override
  State<_ReportReplyComposer> createState() => _ReportReplyComposerState();
}

class _ReportReplyComposerState extends State<_ReportReplyComposer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    widget.onSendMessage(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Reply',
              hintText: 'Respond to this report query',
              prefixIcon: Icon(Icons.chat_bubble_outline),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Send reply',
          onPressed: _send,
          icon: const Icon(Icons.send_outlined),
        ),
      ],
    );
  }
}

class _ReportTimelineCard extends StatelessWidget {
  const _ReportTimelineCard({required this.report});

  final SiteReport report;

  @override
  Widget build(BuildContext context) {
    final items = [
      _TimelineItem(
        icon: Icons.edit_note_outlined,
        label: 'Created',
        value: _dateTime(report.createdAt),
      ),
      if (report.submittedAt != null)
        _TimelineItem(
          icon: Icons.outbox_outlined,
          label: 'Submitted',
          value: _dateTime(report.submittedAt!),
        ),
      if (report.receivedAt != null)
        _TimelineItem(
          icon: Icons.mark_email_read_outlined,
          label: 'Received',
          value: _dateTime(report.receivedAt!),
        ),
      if (report.pdfGeneratedAt != null)
        _TimelineItem(
          icon: Icons.upload_file_outlined,
          label: 'Uploaded',
          value: _dateTime(report.pdfGeneratedAt!),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(item.icon, color: AppColors.mutedInk, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.label)),
                    Text(
                      item.value,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportDetailsError extends StatelessWidget {
  const _ReportDetailsError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveLayout.pagePadding(context),
        child: const AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load this report.',
        ),
      ),
    );
  }
}

class _TimelineItem {
  const _TimelineItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

Future<void> _openReportPdf(BuildContext context, SiteReport report) async {
  final url = report.pdfDownloadUrl?.trim();
  if (url == null || url.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No PDF file is attached.')));
    return;
  }

  final uri = Uri.tryParse(url);
  if (uri == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open this PDF.')));
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open this PDF.')));
  }
}

Color _statusColor(ReportStatus status) {
  return switch (status) {
    ReportStatus.draft => AppColors.mutedInk,
    ReportStatus.submitted => AppColors.fieldBlue,
    ReportStatus.received => AppColors.primaryGreen,
  };
}

String _fileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  return '${(bytes / 1024).ceil()} KB';
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
