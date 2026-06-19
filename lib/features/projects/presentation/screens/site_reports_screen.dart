import 'package:flutter/material.dart';

import '../../../../core/constants/firestore_enums.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/repositories/project_members_repository.dart';
import '../../../../core/repositories/projects_repository.dart';
import '../../../../core/repositories/site_reports_repository.dart';
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
import '../../../../shared/widgets/report_comment_dialog.dart';

class SiteReportsScreen extends StatefulWidget {
  const SiteReportsScreen({
    required SiteReportsRouteArguments arguments,
    FirebaseAuthService? authService,
    ProjectsRepository? projectsRepository,
    ProjectMembersRepository? projectMembersRepository,
    SiteReportsRepository? siteReportsRepository,
    super.key,
  }) : _arguments = arguments,
       _authService = authService,
       _projectsRepository = projectsRepository,
       _projectMembersRepository = projectMembersRepository,
       _siteReportsRepository = siteReportsRepository;

  final SiteReportsRouteArguments _arguments;
  final FirebaseAuthService? _authService;
  final ProjectsRepository? _projectsRepository;
  final ProjectMembersRepository? _projectMembersRepository;
  final SiteReportsRepository? _siteReportsRepository;

  @override
  State<SiteReportsScreen> createState() => _SiteReportsScreenState();
}

class _SiteReportsScreenState extends State<SiteReportsScreen> {
  late final FirebaseAuthService _authService;
  late final ProjectsRepository _projectsRepository;
  late final ProjectMembersRepository _projectMembersRepository;
  late final SiteReportsRepository _siteReportsRepository;
  late final Future<AppUser> _profileFuture;
  late Future<Project?> _projectFuture;
  _ReportFilter _reportFilter = _ReportFilter.all;
  _DiaryWindow _selectedWindow = _DiaryWindow.last90Days;
  String _searchQuery = '';
  DateTimeRange? _selectedReportRange;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _projectsRepository = widget._projectsRepository ?? ProjectsRepository();
    _projectMembersRepository =
        widget._projectMembersRepository ?? ProjectMembersRepository();
    _siteReportsRepository =
        widget._siteReportsRepository ?? SiteReportsRepository();
    _profileFuture = _authService.fetchCurrentUserProfile();
    _projectFuture = _loadProject();
  }

  Future<Project?> _loadProject() {
    if (widget._arguments.project != null) {
      return Future<Project?>.value(widget._arguments.project);
    }

    return _projectsRepository.findById(widget._arguments.projectId);
  }

  Future<void> _openReportForm({
    required Project project,
    SiteReport? report,
  }) async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.siteReportForm,
      arguments: SiteReportFormRouteArguments(
        projectId: project.id,
        project: project,
        report: report,
      ),
    );

    if (!mounted || result is! String) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  Future<void> _openReportDetails({
    required Project project,
    required SiteReport report,
  }) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.reportDetails,
      arguments: ReportDetailsRouteArguments(
        reportId: report.id,
        projectId: project.id,
        report: report,
        project: project,
      ),
    );
  }

  Future<void> _pickReportRange() async {
    final now = DateTime.now();
    final selectedRange = await showDateRangePicker(
      context: context,
      initialDateRange:
          _selectedReportRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 2, 12, 31),
    );

    if (selectedRange == null || !mounted) {
      return;
    }

    setState(() {
      _selectedReportRange = DateTimeRange(
        start: _startOfDay(selectedRange.start),
        end: _startOfDay(selectedRange.end),
      );
      _reportFilter = _ReportFilter.all;
    });
  }

  void _clearReportRange() {
    setState(() => _selectedReportRange = null);
  }

  Future<void> _receiveReport({
    required AppUser profile,
    required SiteReport report,
  }) async {
    final feedback = await _commentDialog(
      title: 'Receive report',
      actionLabel: 'Receive',
      initialComment: report.reviewFeedback,
    );
    if (feedback == null) {
      return;
    }

    await _settleDialogRoute();
    if (!mounted) {
      return;
    }

    try {
      await _siteReportsRepository.receiveReport(
        report: report,
        receivedBy: profile.uid,
        comment: _blankToNull(feedback),
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
    }
  }

  Future<void> _commentOnReport({
    required AppUser profile,
    required SiteReport report,
  }) async {
    final feedback = await _commentDialog(
      title: 'Comment on report',
      actionLabel: 'Save comment',
      initialComment: report.reviewFeedback,
    );
    if (feedback == null) {
      return;
    }

    await _settleDialogRoute();
    if (!mounted) {
      return;
    }

    try {
      await _siteReportsRepository.commentOnReport(
        reportId: report.id,
        comment: _blankToNull(feedback),
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

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _canCoordinateReports(AppUser profile, Project project) {
    if (profile.role != UserRole.projectManager) {
      return false;
    }

    return project.projectManagerId == profile.uid ||
        project.createdBy == profile.uid;
  }

  bool _canReviewReports({
    required AppUser profile,
    required Project project,
    required List<ProjectMember> members,
  }) {
    if (profile.role != UserRole.districtEngineer) {
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

  bool _canCreateReport({
    required AppUser profile,
    required Project project,
    required List<ProjectMember> members,
  }) {
    if (_canCoordinateReports(profile, project)) {
      return true;
    }

    return members.any((member) {
      return member.userId == profile.uid &&
          member.status == ProjectMemberStatus.active &&
          (member.role == UserRole.siteEngineer ||
              member.role == UserRole.clerkOfWorks);
    });
  }

  bool _canEditReport({
    required AppUser profile,
    required Project project,
    required SiteReport report,
  }) {
    if (_canCoordinateReports(profile, project)) {
      return true;
    }

    return report.createdBy == profile.uid &&
        report.status == ReportStatus.draft;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Reports',
      body: FutureBuilder<AppUser>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Checking access');
          }

          if (profileSnapshot.hasError || profileSnapshot.data == null) {
            return const _ReportsError(message: 'Unable to load access.');
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
                return _ReportsError(
                  message: 'Unable to load this project.',
                  onRetry: () {
                    setState(() => _projectFuture = _loadProject());
                  },
                );
              }

              return StreamBuilder<List<ProjectMember>>(
                stream: _projectMembersRepository.watchQuery(
                  _projectMembersRepository.allMembersForProject(project.id),
                ),
                builder: (context, membersSnapshot) {
                  if (membersSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const AppLoadingIndicator(
                      message: 'Loading project team',
                    );
                  }

                  if (membersSnapshot.hasError) {
                    return const _ReportsError(
                      message: 'Unable to load project team access.',
                    );
                  }

                  final members =
                      membersSnapshot.data ?? const <ProjectMember>[];
                  final selectedRange = _selectedReportRange;
                  final startDate = selectedRange == null
                      ? _selectedWindow.startDate
                      : _startOfDay(selectedRange.start);
                  final endDateExclusive = selectedRange == null
                      ? _selectedWindow.endDateExclusive
                      : _startOfDay(
                          selectedRange.end,
                        ).add(const Duration(days: 1));
                  final queryLimit = selectedRange == null
                      ? _selectedWindow.limit
                      : 1000;

                  return StreamBuilder<List<SiteReport>>(
                    stream: _siteReportsRepository.watchQuery(
                      _siteReportsRepository.reportsForProjectWindow(
                        project.id,
                        startDate: startDate,
                        endDateExclusive: endDateExclusive,
                        limit: queryLimit,
                      ),
                    ),
                    builder: (context, reportsSnapshot) {
                      if (reportsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const AppLoadingIndicator(
                          message: 'Loading reports',
                        );
                      }

                      if (reportsSnapshot.hasError) {
                        return const _ReportsError(
                          message: 'Unable to load reports.',
                        );
                      }

                      final reports =
                          reportsSnapshot.data ?? const <SiteReport>[];
                      final canReview = _canReviewReports(
                        profile: profile,
                        project: project,
                        members: members,
                      );

                      return _SiteReportsBody(
                        profile: profile,
                        project: project,
                        reports: reports,
                        selectedFilter: _reportFilter,
                        selectedWindow: _selectedWindow,
                        selectedReportRange: _selectedReportRange,
                        searchQuery: _searchQuery,
                        canCreate: _canCreateReport(
                          profile: profile,
                          project: project,
                          members: members,
                        ),
                        canReview: canReview,
                        canEditReport: (report) => _canEditReport(
                          profile: profile,
                          project: project,
                          report: report,
                        ),
                        onCreateReport: () => _openReportForm(project: project),
                        onEditReport: (report) =>
                            _openReportForm(project: project, report: report),
                        onOpenReport: (report) => _openReportDetails(
                          project: project,
                          report: report,
                        ),
                        onReceiveReport: (report) =>
                            _receiveReport(profile: profile, report: report),
                        onCommentReport: (report) =>
                            _commentOnReport(profile: profile, report: report),
                        onFilterChanged: (filter) {
                          setState(() => _reportFilter = filter);
                        },
                        onWindowChanged: (window) {
                          setState(() {
                            _selectedWindow = window;
                            _selectedReportRange = null;
                            _reportFilter = _ReportFilter.all;
                          });
                        },
                        onSearchChanged: (query) {
                          setState(() => _searchQuery = query);
                        },
                        onPickDateRange: _pickReportRange,
                        onClearDateRange: _clearReportRange,
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
}

class _SiteReportsBody extends StatelessWidget {
  const _SiteReportsBody({
    required this.profile,
    required this.project,
    required this.reports,
    required this.selectedFilter,
    required this.selectedWindow,
    required this.selectedReportRange,
    required this.searchQuery,
    required this.canCreate,
    required this.canReview,
    required this.canEditReport,
    required this.onCreateReport,
    required this.onEditReport,
    required this.onOpenReport,
    required this.onReceiveReport,
    required this.onCommentReport,
    required this.onFilterChanged,
    required this.onWindowChanged,
    required this.onSearchChanged,
    required this.onPickDateRange,
    required this.onClearDateRange,
  });

  final AppUser profile;
  final Project project;
  final List<SiteReport> reports;
  final _ReportFilter selectedFilter;
  final _DiaryWindow selectedWindow;
  final DateTimeRange? selectedReportRange;
  final String searchQuery;
  final bool canCreate;
  final bool canReview;
  final bool Function(SiteReport report) canEditReport;
  final VoidCallback onCreateReport;
  final ValueChanged<SiteReport> onEditReport;
  final ValueChanged<SiteReport> onOpenReport;
  final ValueChanged<SiteReport> onReceiveReport;
  final ValueChanged<SiteReport> onCommentReport;
  final ValueChanged<_ReportFilter> onFilterChanged;
  final ValueChanged<_DiaryWindow> onWindowChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;

  @override
  Widget build(BuildContext context) {
    final statusCounts = _ReportFilter.countsFor(reports);
    final filteredReports = selectedFilter
        .apply(reports)
        .where((report) => _matchesSearch(report, searchQuery))
        .toList(growable: false);
    final groupedReports = _DiaryMonthGroup.fromReports(filteredReports);

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
                child: _ReportsHeader(
                  profile: profile,
                  project: project,
                  reportCount: reports.length,
                  canCreate: canCreate,
                  onCreateReport: onCreateReport,
                ),
              ),
              const SizedBox(height: 16),
              AppAnimatedEntry(
                index: 1,
                child: _DiaryRetrievalControls(
                  selectedWindow: selectedWindow,
                  loadedCount: reports.length,
                  selectedReportRange: selectedReportRange,
                  searchQuery: searchQuery,
                  onWindowChanged: onWindowChanged,
                  onSearchChanged: onSearchChanged,
                  onPickDateRange: onPickDateRange,
                  onClearDateRange: onClearDateRange,
                ),
              ),
              const SizedBox(height: 14),
              AppAnimatedEntry(
                index: 2,
                child: _ReportFilterBar(
                  selectedFilter: selectedFilter,
                  counts: statusCounts,
                  onChanged: onFilterChanged,
                ),
              ),
              const SizedBox(height: 14),
              if (selectedReportRange == null &&
                  reports.length >= selectedWindow.limit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _DiaryLimitNotice(window: selectedWindow),
                ),
              if (reports.isEmpty)
                AppAnimatedEntry(
                  index: 3,
                  child: AppEmptyState(
                    icon: Icons.assignment_late_outlined,
                    title: selectedReportRange == null
                        ? selectedWindow.emptyTitle
                        : 'No reports found for ${_dateRangeLabel(selectedReportRange!)}.',
                    message: selectedReportRange == null
                        ? selectedWindow.emptyMessage
                        : 'Choose another date range or clear the filter.',
                    action: canCreate
                        ? FilledButton.icon(
                            onPressed: onCreateReport,
                            icon: const Icon(Icons.note_add_outlined),
                            label: const Text('Submit first PDF'),
                          )
                        : null,
                  ),
                )
              else if (filteredReports.isEmpty)
                AppAnimatedEntry(
                  index: 3,
                  child: AppEmptyState(
                    icon: selectedFilter.icon,
                    title: _emptyFilteredTitle(searchQuery, selectedFilter),
                    message:
                        'Try a different status, search term, or retrieval window.',
                  ),
                )
              else
                ...groupedReports.asMap().entries.map(
                  (groupEntry) => AppAnimatedEntry(
                    index: groupEntry.key + 3,
                    child: _DiaryMonthSection(
                      group: groupEntry.value,
                      canReview: canReview,
                      canEditReport: canEditReport,
                      onEditReport: onEditReport,
                      onOpenReport: onOpenReport,
                      onReceiveReport: onReceiveReport,
                      onCommentReport: onCommentReport,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesSearch(SiteReport report, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchableText = [
      report.title,
      report.summary,
      report.pdfFileName,
      report.reviewFeedback,
      report.status.label,
    ].whereType<String>().join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }

  String _emptyFilteredTitle(String query, _ReportFilter filter) {
    if (query.trim().isNotEmpty) {
      return 'No reports match this search.';
    }

    return filter.emptyTitle;
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({
    required this.profile,
    required this.project,
    required this.reportCount,
    required this.canCreate,
    required this.onCreateReport,
  });

  final AppUser profile;
  final Project project;
  final int reportCount;
  final bool canCreate;
  final VoidCallback onCreateReport;

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
                const AppIconBadge(
                  icon: Icons.assignment_outlined,
                  color: AppColors.fieldBlue,
                  size: 48,
                  filled: true,
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
                        '${profile.role.label} - ${project.district}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoChip(
                        icon: Icons.fact_check_outlined,
                        label:
                            '$reportCount report${reportCount == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (canCreate) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onCreateReport,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Submit report'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiaryRetrievalControls extends StatelessWidget {
  const _DiaryRetrievalControls({
    required this.selectedWindow,
    required this.loadedCount,
    required this.selectedReportRange,
    required this.searchQuery,
    required this.onWindowChanged,
    required this.onSearchChanged,
    required this.onPickDateRange,
    required this.onClearDateRange,
  });

  final _DiaryWindow selectedWindow;
  final int loadedCount;
  final DateTimeRange? selectedReportRange;
  final String searchQuery;
  final ValueChanged<_DiaryWindow> onWindowChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AppIconBadge(
                  icon: Icons.manage_search_outlined,
                  color: AppColors.fieldBlue,
                  size: 40,
                  iconSize: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Retrieve reports',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedReportRange == null
                            ? selectedWindow.detail
                            : 'Showing reports for ${_dateRangeLabel(selectedReportRange!)}.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppStatusChip(
                  icon: Icons.inventory_2_outlined,
                  label: '$loadedCount loaded',
                  color: AppColors.primaryGreen,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onPickDateRange,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    selectedReportRange == null
                        ? 'Date range'
                        : _dateRangeLabel(selectedReportRange!),
                  ),
                ),
                if (selectedReportRange != null)
                  IconButton.outlined(
                    tooltip: 'Clear date range',
                    onPressed: onClearDateRange,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _DiaryWindow.values
                  .map((window) {
                    final selected = window == selectedWindow;

                    return ChoiceChip(
                      avatar: Icon(
                        window.icon,
                        size: 18,
                        color: selected
                            ? AppColors.fieldBlue
                            : AppColors.mutedInk,
                      ),
                      label: Text(window.label),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: AppColors.fieldBlue.withValues(
                        alpha: 0.12,
                      ),
                      side: BorderSide(
                        color: selected
                            ? AppColors.fieldBlue.withValues(alpha: 0.45)
                            : AppColors.border,
                      ),
                      onSelected: (_) => onWindowChanged(window),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: searchQuery,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Search loaded reports',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: onSearchChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryLimitNotice extends StatelessWidget {
  const _DiaryLimitNotice({required this.window});

  final _DiaryWindow window;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.fieldBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Showing the latest ${window.limit} reports for this window. Narrow the period or search within the loaded results for cleaner retrieval.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportFilterBar extends StatelessWidget {
  const _ReportFilterBar({
    required this.selectedFilter,
    required this.counts,
    required this.onChanged,
  });

  final _ReportFilter selectedFilter;
  final Map<_ReportFilter, int> counts;
  final ValueChanged<_ReportFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _ReportFilter.values
              .map((filter) {
                final isSelected = filter == selectedFilter;

                return ChoiceChip(
                  avatar: Icon(
                    filter.icon,
                    size: 18,
                    color: isSelected ? filter.color : AppColors.mutedInk,
                  ),
                  label: Text('${filter.label} (${counts[filter] ?? 0})'),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: filter.color.withValues(alpha: 0.12),
                  side: BorderSide(
                    color: isSelected
                        ? filter.color.withValues(alpha: 0.45)
                        : AppColors.border,
                  ),
                  onSelected: (_) => onChanged(filter),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _DiaryMonthSection extends StatelessWidget {
  const _DiaryMonthSection({
    required this.group,
    required this.canReview,
    required this.canEditReport,
    required this.onEditReport,
    required this.onOpenReport,
    required this.onReceiveReport,
    required this.onCommentReport,
  });

  final _DiaryMonthGroup group;
  final bool canReview;
  final bool Function(SiteReport report) canEditReport;
  final ValueChanged<SiteReport> onEditReport;
  final ValueChanged<SiteReport> onOpenReport;
  final ValueChanged<SiteReport> onReceiveReport;
  final ValueChanged<SiteReport> onCommentReport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                AppStatusChip(
                  icon: Icons.event_note_outlined,
                  label:
                      '${group.reports.length} report${group.reports.length == 1 ? '' : 's'}',
                  color: AppColors.fieldBlue,
                ),
              ],
            ),
          ),
          ...group.reports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportCard(
                report: report,
                canReview: canReview,
                canEdit: canEditReport(report),
                onOpen: () => onOpenReport(report),
                onEdit: () => onEditReport(report),
                onReceive: () => onReceiveReport(report),
                onComment: () => onCommentReport(report),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.canReview,
    required this.canEdit,
    required this.onOpen,
    required this.onEdit,
    required this.onReceive,
    required this.onComment,
  });

  final SiteReport report;
  final bool canReview;
  final bool canEdit;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onReceive;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final hasPdf = (report.pdfDownloadUrl ?? '').trim().isNotEmpty;
    final reviewFeedback = report.reviewFeedback?.trim() ?? '';
    final submittedAt = report.submittedAt;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              AppIconBadge(
                icon: report.status == ReportStatus.received
                    ? Icons.mark_email_read_outlined
                    : Icons.description_outlined,
                color: _statusColor(report.status),
                size: 42,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      submittedAt == null
                          ? _date(report.reportDate)
                          : '${_date(report.reportDate)} • submitted ${_time(submittedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppStatusChip(
                    icon: Icons.flag_outlined,
                    label: report.status.label,
                    color: _statusColor(report.status),
                  ),
                  if (hasPdf)
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.civicRed,
                      size: 20,
                    ),
                  if (reviewFeedback.isNotEmpty)
                    const Icon(
                      Icons.forum_outlined,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                ],
              ),
              if (canEdit || canReview) ...[
                const SizedBox(width: 2),
                PopupMenuButton<_ReportAction>(
                  tooltip: 'Report actions',
                  onSelected: (action) {
                    switch (action) {
                      case _ReportAction.open:
                        onOpen();
                      case _ReportAction.edit:
                        onEdit();
                      case _ReportAction.receive:
                        onReceive();
                      case _ReportAction.comment:
                        onComment();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<_ReportAction>(
                      value: _ReportAction.open,
                      child: Text('Open details'),
                    ),
                    if (canEdit)
                      const PopupMenuItem<_ReportAction>(
                        value: _ReportAction.edit,
                        child: Text('Edit'),
                      ),
                    if (canReview && report.status == ReportStatus.submitted)
                      const PopupMenuItem<_ReportAction>(
                        value: _ReportAction.receive,
                        child: Text('Receive'),
                      ),
                    if (canReview)
                      const PopupMenuItem<_ReportAction>(
                        value: _ReportAction.comment,
                        child: Text('Comment'),
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ReportStatus status) {
    return switch (status) {
      ReportStatus.draft => AppColors.mutedInk,
      ReportStatus.submitted => AppColors.fieldBlue,
      ReportStatus.received => AppColors.primaryGreen,
    };
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

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}

enum _ReportAction { open, edit, receive, comment }

DateTime _startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
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

String _dateRangeLabel(DateTimeRange range) {
  final start = _startOfDay(range.start);
  final end = _startOfDay(range.end);

  if (start == end) {
    return _date(start);
  }

  return '${_date(start)} - ${_date(end)}';
}

enum _DiaryWindow {
  thisMonth,
  last30Days,
  last90Days,
  thisYear,
  latestArchive;

  String get label {
    return switch (this) {
      _DiaryWindow.thisMonth => 'This month',
      _DiaryWindow.last30Days => 'Last 30 days',
      _DiaryWindow.last90Days => 'Last 90 days',
      _DiaryWindow.thisYear => 'This year',
      _DiaryWindow.latestArchive => 'Latest 500',
    };
  }

  String get detail {
    return switch (this) {
      _DiaryWindow.thisMonth =>
        'Loads reports recorded from the start of this month.',
      _DiaryWindow.last30Days =>
        'Loads the latest reports from the last 30 days.',
      _DiaryWindow.last90Days =>
        'Loads the latest reports from the last 90 days.',
      _DiaryWindow.thisYear => 'Loads reports recorded from January this year.',
      _DiaryWindow.latestArchive =>
        'Loads the latest 500 reports for archive lookup.',
    };
  }

  IconData get icon {
    return switch (this) {
      _DiaryWindow.thisMonth => Icons.calendar_month_outlined,
      _DiaryWindow.last30Days => Icons.date_range_outlined,
      _DiaryWindow.last90Days => Icons.view_timeline_outlined,
      _DiaryWindow.thisYear => Icons.calendar_today_outlined,
      _DiaryWindow.latestArchive => Icons.inventory_2_outlined,
    };
  }

  int get limit {
    return switch (this) {
      _DiaryWindow.thisMonth => 80,
      _DiaryWindow.last30Days => 80,
      _DiaryWindow.last90Days => 140,
      _DiaryWindow.thisYear => 380,
      _DiaryWindow.latestArchive => 500,
    };
  }

  DateTime? get startDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (this) {
      _DiaryWindow.thisMonth => DateTime(now.year, now.month),
      _DiaryWindow.last30Days => today.subtract(const Duration(days: 30)),
      _DiaryWindow.last90Days => today.subtract(const Duration(days: 90)),
      _DiaryWindow.thisYear => DateTime(now.year),
      _DiaryWindow.latestArchive => null,
    };
  }

  DateTime? get endDateExclusive {
    if (this == _DiaryWindow.latestArchive) {
      return null;
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  String get emptyTitle {
    return switch (this) {
      _DiaryWindow.latestArchive => 'No reports yet.',
      _ => 'No reports found in this period.',
    };
  }

  String get emptyMessage {
    return switch (this) {
      _DiaryWindow.latestArchive =>
        'Submit the first report or check that the project assignment is correct.',
      _ => 'Try another retrieval window or submit a new report.',
    };
  }
}

enum _ReportFilter {
  all,
  awaitingReceipt,
  received,
  draft;

  String get label {
    return switch (this) {
      _ReportFilter.all => 'All',
      _ReportFilter.awaitingReceipt => 'Awaiting receipt',
      _ReportFilter.received => 'Received',
      _ReportFilter.draft => 'Draft',
    };
  }

  IconData get icon {
    return switch (this) {
      _ReportFilter.all => Icons.list_alt_outlined,
      _ReportFilter.awaitingReceipt => Icons.mark_email_unread_outlined,
      _ReportFilter.received => Icons.mark_email_read_outlined,
      _ReportFilter.draft => Icons.edit_note_outlined,
    };
  }

  Color get color {
    return switch (this) {
      _ReportFilter.all => AppColors.ink,
      _ReportFilter.awaitingReceipt => AppColors.fieldBlue,
      _ReportFilter.received => AppColors.primaryGreen,
      _ReportFilter.draft => AppColors.mutedInk,
    };
  }

  String get emptyTitle {
    return switch (this) {
      _ReportFilter.all => 'No reports yet.',
      _ReportFilter.awaitingReceipt =>
        'No reports are awaiting receipt for this project.',
      _ReportFilter.received => 'No received reports for this project yet.',
      _ReportFilter.draft => 'No draft reports for this project.',
    };
  }

  ReportStatus? get _status {
    return switch (this) {
      _ReportFilter.all => null,
      _ReportFilter.awaitingReceipt => ReportStatus.submitted,
      _ReportFilter.received => ReportStatus.received,
      _ReportFilter.draft => ReportStatus.draft,
    };
  }

  List<SiteReport> apply(List<SiteReport> reports) {
    final status = _status;
    if (status == null) {
      return reports;
    }

    return reports
        .where((report) => report.status == status)
        .toList(growable: false);
  }

  static Map<_ReportFilter, int> countsFor(List<SiteReport> reports) {
    final counts = {
      for (final filter in _ReportFilter.values)
        filter: filter == _ReportFilter.all ? reports.length : 0,
    };

    for (final report in reports) {
      final filter = switch (report.status) {
        ReportStatus.submitted => _ReportFilter.awaitingReceipt,
        ReportStatus.received => _ReportFilter.received,
        ReportStatus.draft => _ReportFilter.draft,
      };

      counts.update(filter, (value) => value + 1);
    }

    return counts;
  }
}

class _DiaryMonthGroup {
  const _DiaryMonthGroup({required this.label, required this.reports});

  final String label;
  final List<SiteReport> reports;

  static List<_DiaryMonthGroup> fromReports(List<SiteReport> reports) {
    final groups = <String, List<SiteReport>>{};

    for (final report in reports) {
      final key = '${report.reportDate.year}-${report.reportDate.month}';
      groups.putIfAbsent(key, () => <SiteReport>[]).add(report);
    }

    return groups.entries
        .map((entry) {
          final firstReport = entry.value.first;
          return _DiaryMonthGroup(
            label: _monthLabel(firstReport.reportDate),
            reports: entry.value,
          );
        })
        .toList(growable: false);
  }

  static String _monthLabel(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[value.month - 1]} ${value.year}';
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

class _ReportsError extends StatelessWidget {
  const _ReportsError({required this.message, this.onRetry});

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
