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

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({
    FirebaseAuthService? authService,
    ProjectsRepository? projectsRepository,
    ProjectMembersRepository? projectMembersRepository,
    SiteReportsRepository? siteReportsRepository,
    ReportsRouteArguments? arguments,
    super.key,
  }) : _authService = authService,
       _projectsRepository = projectsRepository,
       _projectMembersRepository = projectMembersRepository,
       _siteReportsRepository = siteReportsRepository,
       _arguments = arguments;

  final FirebaseAuthService? _authService;
  final ProjectsRepository? _projectsRepository;
  final ProjectMembersRepository? _projectMembersRepository;
  final SiteReportsRepository? _siteReportsRepository;
  final ReportsRouteArguments? _arguments;

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  late final FirebaseAuthService _authService;
  late final ProjectsRepository _projectsRepository;
  late final ProjectMembersRepository _projectMembersRepository;
  late final SiteReportsRepository _siteReportsRepository;
  late Future<_ReportsAccessData> _accessFuture;

  _ReportsWindow _window = _ReportsWindow.last90Days;
  _ReportsListFilter _filter = _ReportsListFilter.all;
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
    _accessFuture = _loadAccess();
  }

  Future<_ReportsAccessData> _loadAccess() async {
    final profile = await _authService.fetchCurrentUserProfile();
    final scopedProjectId = _scopedProjectId;
    final projectFuture = scopedProjectId == null
        ? Future<Project?>.value(widget._arguments?.project)
        : widget._arguments?.project != null
        ? Future<Project?>.value(widget._arguments!.project)
        : _projectsRepository.findById(scopedProjectId);
    final projectsFuture = _projectsRepository.getQuery(
      _projectsRepository.recent(limit: 200),
    );
    final membershipsFuture = _projectMembersRepository.getQuery(
      _projectMembersRepository.activeMembershipsForUser(
        profile.uid,
        limit: 200,
      ),
    );

    final results = await Future.wait([
      projectFuture,
      projectsFuture,
      membershipsFuture,
    ]);
    final scopedProject = results[0] as Project?;
    final projects = List<Project>.from(results[1] as List<Project>);
    final memberships = results[2] as List<ProjectMember>;

    if (scopedProject != null &&
        projects.every((project) => project.id != scopedProject.id)) {
      projects.add(scopedProject);
    }

    final projectsById = {for (final project in projects) project.id: project};
    final assignedProjectIds = memberships
        .where((member) => member.status == ProjectMemberStatus.active)
        .map((member) => member.projectId)
        .where((projectId) => projectId.trim().isNotEmpty)
        .toSet();

    Set<String>? visibleProjectIds;
    if (scopedProjectId != null) {
      visibleProjectIds = {scopedProjectId};
    } else if (profile.role == UserRole.districtEngineer) {
      final engineerDistrict = profile.district.trim().toLowerCase();
      visibleProjectIds = projects
          .where((project) {
            final projectDistrict = project.district.trim().toLowerCase();
            return engineerDistrict.isEmpty ||
                projectDistrict.isEmpty ||
                engineerDistrict == projectDistrict ||
                assignedProjectIds.contains(project.id);
          })
          .map((project) => project.id)
          .toSet();
    } else if (profile.role == UserRole.clerkOfWorks ||
        profile.role == UserRole.siteEngineer ||
        profile.role == UserRole.contractor ||
        profile.role == UserRole.consultant) {
      visibleProjectIds = assignedProjectIds;
    }

    return _ReportsAccessData(
      profile: profile,
      projectsById: projectsById,
      visibleProjectIds: visibleProjectIds,
      scopedProjectId: scopedProjectId,
      title: widget._arguments?.title ?? 'Reports',
    );
  }

  String? get _scopedProjectId {
    final projectId =
        widget._arguments?.project?.id ?? widget._arguments?.projectId;
    if (projectId == null || projectId.trim().isEmpty) {
      return null;
    }

    return projectId;
  }

  QuerySource _queryFor(_ReportsAccessData access) {
    final scopedProjectId = access.scopedProjectId;
    if (scopedProjectId != null) {
      return QuerySource.project(scopedProjectId);
    }

    return const QuerySource.all();
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
      _filter = _ReportsListFilter.all;
    });
  }

  void _clearReportRange() {
    setState(() => _selectedReportRange = null);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Reports',
      body: FutureBuilder<_ReportsAccessData>(
        future: _accessFuture,
        builder: (context, accessSnapshot) {
          if (accessSnapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Loading reports');
          }

          if (accessSnapshot.hasError || accessSnapshot.data == null) {
            return _ReportsListError(
              onRetry: () {
                setState(() => _accessFuture = _loadAccess());
              },
            );
          }

          final access = accessSnapshot.data!;
          final querySource = _queryFor(access);
          final selectedRange = _selectedReportRange;
          final startDate = selectedRange == null
              ? _window.startDate
              : _startOfDay(selectedRange.start);
          final endDateExclusive = selectedRange == null
              ? _window.endDateExclusive
              : _startOfDay(selectedRange.end).add(const Duration(days: 1));
          final queryLimit = selectedRange == null ? _window.limit : 1000;
          final query = switch (querySource) {
            QuerySourceAll() => _siteReportsRepository.reportsWindow(
              startDate: startDate,
              endDateExclusive: endDateExclusive,
              limit: queryLimit,
            ),
            QuerySourceProject(:final projectId) =>
              _siteReportsRepository.reportsForProjectWindow(
                projectId,
                startDate: startDate,
                endDateExclusive: endDateExclusive,
                limit: queryLimit,
              ),
          };

          return StreamBuilder<List<SiteReport>>(
            stream: _siteReportsRepository.watchQuery(query),
            builder: (context, reportsSnapshot) {
              if (reportsSnapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingIndicator(message: 'Loading reports');
              }

              if (reportsSnapshot.hasError) {
                return _ReportsListError(
                  onRetry: () {
                    setState(() => _accessFuture = _loadAccess());
                  },
                );
              }

              final reports = _visibleReports(
                reportsSnapshot.data ?? const <SiteReport>[],
                access,
              );
              final filteredReports = _filter
                  .apply(reports)
                  .where((report) => _matchesSearch(report, access))
                  .toList(growable: false);
              final counts = _ReportsListFilter.countsFor(reports);

              return _ReportsListBody(
                access: access,
                reports: reports,
                filteredReports: filteredReports,
                counts: counts,
                window: _window,
                filter: _filter,
                searchQuery: _searchQuery,
                selectedReportRange: _selectedReportRange,
                onWindowChanged: (window) {
                  setState(() {
                    _window = window;
                    _selectedReportRange = null;
                  });
                },
                onFilterChanged: (filter) => setState(() => _filter = filter),
                onSearchChanged: (value) {
                  setState(() => _searchQuery = value);
                },
                onPickDateRange: _pickReportRange,
                onClearDateRange: _clearReportRange,
              );
            },
          );
        },
      ),
    );
  }

  List<SiteReport> _visibleReports(
    List<SiteReport> reports,
    _ReportsAccessData access,
  ) {
    final visibleProjectIds = access.visibleProjectIds;
    return reports
        .where((report) {
          if (access.profile.role == UserRole.clerkOfWorks ||
              access.profile.role == UserRole.siteEngineer) {
            return report.createdBy == access.profile.uid ||
                (visibleProjectIds?.contains(report.projectId) ?? false);
          }

          if (visibleProjectIds == null) {
            return true;
          }

          return visibleProjectIds.contains(report.projectId);
        })
        .toList(growable: false);
  }

  bool _matchesSearch(SiteReport report, _ReportsAccessData access) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    final projectName = access.projectsById[report.projectId]?.name;
    final searchable = [
      report.title,
      projectName,
      report.pdfFileName,
      report.status.label,
      report.authorRole.label,
    ].whereType<String>().join(' ').toLowerCase();

    return searchable.contains(query);
  }
}

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

class _ReportsListBody extends StatelessWidget {
  const _ReportsListBody({
    required this.access,
    required this.reports,
    required this.filteredReports,
    required this.counts,
    required this.window,
    required this.filter,
    required this.searchQuery,
    required this.selectedReportRange,
    required this.onWindowChanged,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onPickDateRange,
    required this.onClearDateRange,
  });

  final _ReportsAccessData access;
  final List<SiteReport> reports;
  final List<SiteReport> filteredReports;
  final Map<_ReportsListFilter, int> counts;
  final _ReportsWindow window;
  final _ReportsListFilter filter;
  final String searchQuery;
  final DateTimeRange? selectedReportRange;
  final ValueChanged<_ReportsWindow> onWindowChanged;
  final ValueChanged<_ReportsListFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppAnimatedEntry(
                child: _ReportsModuleHeader(
                  title: access.title,
                  loadedCount: reports.length,
                ),
              ),
              const SizedBox(height: 14),
              AppAnimatedEntry(
                index: 1,
                child: _ReportsToolbar(
                  window: window,
                  filter: filter,
                  counts: counts,
                  searchQuery: searchQuery,
                  selectedReportRange: selectedReportRange,
                  onWindowChanged: onWindowChanged,
                  onFilterChanged: onFilterChanged,
                  onSearchChanged: onSearchChanged,
                  onPickDateRange: onPickDateRange,
                  onClearDateRange: onClearDateRange,
                ),
              ),
              const SizedBox(height: 14),
              if (filteredReports.isEmpty)
                AppAnimatedEntry(
                  index: 2,
                  child: AppEmptyState(
                    icon: filter.icon,
                    title: reports.isEmpty && selectedReportRange != null
                        ? 'No reports found for ${_dateRangeLabel(selectedReportRange!)}.'
                        : reports.isEmpty
                        ? 'No reports found.'
                        : 'No reports match this view.',
                  ),
                )
              else
                ...filteredReports.asMap().entries.map(
                  (entry) => AppAnimatedEntry(
                    index: entry.key + 2,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReportInboxTile(
                        report: entry.value,
                        project: access.projectsById[entry.value.projectId],
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

class _ReportsModuleHeader extends StatelessWidget {
  const _ReportsModuleHeader({required this.title, required this.loadedCount});

  final String title;
  final int loadedCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const AppIconBadge(
              icon: Icons.assignment_outlined,
              color: AppColors.fieldBlue,
              size: 48,
              filled: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            AppStatusChip(
              icon: Icons.inventory_2_outlined,
              label: '$loadedCount',
              color: AppColors.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsToolbar extends StatelessWidget {
  const _ReportsToolbar({
    required this.window,
    required this.filter,
    required this.counts,
    required this.searchQuery,
    required this.selectedReportRange,
    required this.onWindowChanged,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onPickDateRange,
    required this.onClearDateRange,
  });

  final _ReportsWindow window;
  final _ReportsListFilter filter;
  final Map<_ReportsListFilter, int> counts;
  final String searchQuery;
  final DateTimeRange? selectedReportRange;
  final ValueChanged<_ReportsWindow> onWindowChanged;
  final ValueChanged<_ReportsListFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              initialValue: searchQuery,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Search reports',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ReportsListFilter.values
                  .map((item) {
                    final selected = item == filter;
                    return ChoiceChip(
                      avatar: Icon(
                        item.icon,
                        size: 18,
                        color: selected ? item.color : AppColors.mutedInk,
                      ),
                      label: Text('${item.label} ${counts[item] ?? 0}'),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: item.color.withValues(alpha: 0.12),
                      side: BorderSide(
                        color: selected
                            ? item.color.withValues(alpha: 0.45)
                            : AppColors.border,
                      ),
                      onSelected: (_) => onFilterChanged(item),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ReportsWindow.values
                  .map((item) {
                    final selected = item == window;
                    return ChoiceChip(
                      avatar: Icon(
                        item.icon,
                        size: 18,
                        color: selected
                            ? AppColors.fieldBlue
                            : AppColors.mutedInk,
                      ),
                      label: Text(item.label),
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
                      onSelected: (_) => onWindowChanged(item),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportInboxTile extends StatelessWidget {
  const _ReportInboxTile({required this.report, required this.project});

  final SiteReport report;
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final hasPdf = (report.pdfDownloadUrl ?? '').trim().isNotEmpty;
    final hasComment = (report.reviewFeedback ?? '').trim().isNotEmpty;
    final projectName = project?.name ?? 'Project record';

    return Card(
      child: ListTile(
        leading: AppIconBadge(
          icon: report.status == ReportStatus.received
              ? Icons.mark_email_read_outlined
              : Icons.mark_email_unread_outlined,
          color: _statusColor(report.status),
          size: 42,
          iconSize: 22,
        ),
        title: Text(report.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '$projectName • ${_date(report.reportDate)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (hasPdf)
              const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.civicRed,
                size: 20,
              ),
            if (hasComment)
              const Icon(
                Icons.comment_outlined,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
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
}

class _ReportsListError extends StatelessWidget {
  const _ReportsListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResponsiveLayout.pagePadding(context),
        child: AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load reports.',
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

class _ReportsAccessData {
  const _ReportsAccessData({
    required this.profile,
    required this.projectsById,
    required this.visibleProjectIds,
    required this.scopedProjectId,
    required this.title,
  });

  final AppUser profile;
  final Map<String, Project> projectsById;
  final Set<String>? visibleProjectIds;
  final String? scopedProjectId;
  final String title;
}

sealed class QuerySource {
  const QuerySource();

  const factory QuerySource.all() = QuerySourceAll;
  const factory QuerySource.project(String projectId) = QuerySourceProject;
}

class QuerySourceAll extends QuerySource {
  const QuerySourceAll();
}

class QuerySourceProject extends QuerySource {
  const QuerySourceProject(this.projectId);

  final String projectId;
}

enum _ReportsWindow {
  last30Days,
  last90Days,
  thisYear,
  latest;

  String get label {
    return switch (this) {
      _ReportsWindow.last30Days => '30 days',
      _ReportsWindow.last90Days => '90 days',
      _ReportsWindow.thisYear => 'This year',
      _ReportsWindow.latest => 'Latest',
    };
  }

  IconData get icon {
    return switch (this) {
      _ReportsWindow.last30Days => Icons.date_range_outlined,
      _ReportsWindow.last90Days => Icons.view_timeline_outlined,
      _ReportsWindow.thisYear => Icons.calendar_today_outlined,
      _ReportsWindow.latest => Icons.inventory_2_outlined,
    };
  }

  int get limit {
    return switch (this) {
      _ReportsWindow.last30Days => 100,
      _ReportsWindow.last90Days => 180,
      _ReportsWindow.thisYear => 420,
      _ReportsWindow.latest => 500,
    };
  }

  DateTime? get startDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (this) {
      _ReportsWindow.last30Days => today.subtract(const Duration(days: 30)),
      _ReportsWindow.last90Days => today.subtract(const Duration(days: 90)),
      _ReportsWindow.thisYear => DateTime(now.year),
      _ReportsWindow.latest => null,
    };
  }

  DateTime? get endDateExclusive {
    if (this == _ReportsWindow.latest) {
      return null;
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }
}

enum _ReportsListFilter {
  all,
  awaitingReceipt,
  received,
  draft;

  String get label {
    return switch (this) {
      _ReportsListFilter.all => 'All',
      _ReportsListFilter.awaitingReceipt => 'Awaiting',
      _ReportsListFilter.received => 'Received',
      _ReportsListFilter.draft => 'Draft',
    };
  }

  IconData get icon {
    return switch (this) {
      _ReportsListFilter.all => Icons.list_alt_outlined,
      _ReportsListFilter.awaitingReceipt => Icons.mark_email_unread_outlined,
      _ReportsListFilter.received => Icons.mark_email_read_outlined,
      _ReportsListFilter.draft => Icons.edit_note_outlined,
    };
  }

  Color get color {
    return switch (this) {
      _ReportsListFilter.all => AppColors.ink,
      _ReportsListFilter.awaitingReceipt => AppColors.fieldBlue,
      _ReportsListFilter.received => AppColors.primaryGreen,
      _ReportsListFilter.draft => AppColors.mutedInk,
    };
  }

  ReportStatus? get _status {
    return switch (this) {
      _ReportsListFilter.all => null,
      _ReportsListFilter.awaitingReceipt => ReportStatus.submitted,
      _ReportsListFilter.received => ReportStatus.received,
      _ReportsListFilter.draft => ReportStatus.draft,
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

  static Map<_ReportsListFilter, int> countsFor(List<SiteReport> reports) {
    final counts = {
      for (final filter in _ReportsListFilter.values)
        filter: filter == _ReportsListFilter.all ? reports.length : 0,
    };

    for (final report in reports) {
      final filter = switch (report.status) {
        ReportStatus.submitted => _ReportsListFilter.awaitingReceipt,
        ReportStatus.received => _ReportsListFilter.received,
        ReportStatus.draft => _ReportsListFilter.draft,
      };

      counts.update(filter, (value) => value + 1);
    }

    return counts;
  }
}
