import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/firestore_enums.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/repositories/project_members_repository.dart';
import '../../../../core/repositories/projects_repository.dart';
import '../../../../core/repositories/site_reports_repository.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/site_report_pdf_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../routes/app_route_arguments.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/models/project_member.dart';
import '../../../../shared/models/site_report.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class SiteReportFormScreen extends StatefulWidget {
  const SiteReportFormScreen({
    required SiteReportFormRouteArguments arguments,
    FirebaseAuthService? authService,
    ProjectsRepository? projectsRepository,
    ProjectMembersRepository? projectMembersRepository,
    SiteReportsRepository? siteReportsRepository,
    SiteReportPdfStorageService? pdfStorageService,
    super.key,
  }) : _arguments = arguments,
       _authService = authService,
       _projectsRepository = projectsRepository,
       _projectMembersRepository = projectMembersRepository,
       _siteReportsRepository = siteReportsRepository,
       _pdfStorageService = pdfStorageService;

  final SiteReportFormRouteArguments _arguments;
  final FirebaseAuthService? _authService;
  final ProjectsRepository? _projectsRepository;
  final ProjectMembersRepository? _projectMembersRepository;
  final SiteReportsRepository? _siteReportsRepository;
  final SiteReportPdfStorageService? _pdfStorageService;

  @override
  State<SiteReportFormScreen> createState() => _SiteReportFormScreenState();
}

class _SiteReportFormScreenState extends State<SiteReportFormScreen> {
  late final FirebaseAuthService _authService;
  late final ProjectsRepository _projectsRepository;
  late final ProjectMembersRepository _projectMembersRepository;
  late final SiteReportsRepository _siteReportsRepository;
  late final SiteReportPdfStorageService _pdfStorageService;
  late final Future<AppUser> _profileFuture;
  late Future<Project?> _projectFuture;
  late Future<List<ProjectMember>> _membersFuture;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();

  DateTime _reportDate = DateTime.now();
  PlatformFile? _selectedPdfFile;
  String? _loadedReportId;
  bool _isSaving = false;

  SiteReport? get _existingReport => widget._arguments.report;
  bool get _isEditing => _existingReport != null;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _projectsRepository = widget._projectsRepository ?? ProjectsRepository();
    _projectMembersRepository =
        widget._projectMembersRepository ?? ProjectMembersRepository();
    _siteReportsRepository =
        widget._siteReportsRepository ?? SiteReportsRepository();
    _pdfStorageService =
        widget._pdfStorageService ?? SiteReportPdfStorageService();
    _profileFuture = _authService.fetchCurrentUserProfile();
    _projectFuture = _loadProject();
    _membersFuture = _projectMembersRepository.getQuery(
      _projectMembersRepository.allMembersForProject(
        widget._arguments.projectId,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<Project?> _loadProject() {
    if (widget._arguments.project != null) {
      return Future<Project?>.value(widget._arguments.project);
    }

    return _projectsRepository.findById(widget._arguments.projectId);
  }

  void _populateForm() {
    final report = _existingReport;
    final loadedId = report?.id ?? '__new_report__';
    if (_loadedReportId == loadedId) {
      return;
    }

    _loadedReportId = loadedId;
    if (report == null) {
      _reportDate = DateTime.now();
      return;
    }

    _titleController.text = report.title;
    _summaryController.text = report.summary;
    _reportDate = report.reportDate;
  }

  Future<void> _save({
    required AppUser profile,
    required Project project,
    required ReportStatus status,
  }) async {
    if (_isSaving) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    if (status == ReportStatus.submitted &&
        _selectedPdfFile == null &&
        (_existingReport?.pdfDownloadUrl ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attach the prepared PDF before submitting.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final existingReport = _existingReport;
      final baseReport = SiteReport(
        id: existingReport?.id ?? _siteReportsRepository.newDocumentId(),
        projectId: project.id,
        title: _titleController.text.trim(),
        summary: _summaryText(),
        reportDate: DateTime(
          _reportDate.year,
          _reportDate.month,
          _reportDate.day,
        ),
        progressPercent: 0,
        status: status,
        authorRole:
            existingReport?.authorRole == UserRole.unknown ||
                existingReport == null
            ? profile.role
            : existingReport.authorRole,
        submittedAt: status == ReportStatus.submitted
            ? existingReport?.status == ReportStatus.submitted
                  ? existingReport?.submittedAt ?? now
                  : now
            : existingReport?.submittedAt,
        createdAt: existingReport?.createdAt ?? now,
        updatedAt: now,
        createdBy: existingReport?.createdBy ?? profile.uid,
        pdfStoragePath: existingReport?.pdfStoragePath,
        pdfDownloadUrl: existingReport?.pdfDownloadUrl,
        pdfFileName: existingReport?.pdfFileName,
        pdfGeneratedAt: existingReport?.pdfGeneratedAt,
        pdfVersion: existingReport?.pdfVersion ?? 0,
        pdfFileSizeBytes: existingReport?.pdfFileSizeBytes,
        reviewFeedback: existingReport?.reviewFeedback,
        receivedAt: existingReport?.receivedAt,
        receivedBy: existingReport?.receivedBy,
      );
      final report = _selectedPdfFile != null
          ? await _attachUploadedPdf(
              report: baseReport,
              project: project,
              uploadedAt: now,
            )
          : baseReport;

      await _siteReportsRepository.save(report);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        status == ReportStatus.submitted
            ? 'Report submitted for review.'
            : existingReport == null
            ? 'Report saved as draft.'
            : 'Report updated.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save this report.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<SiteReport> _attachUploadedPdf({
    required SiteReport report,
    required Project project,
    required DateTime uploadedAt,
  }) async {
    final selectedPdf = _selectedPdfFile;
    if (selectedPdf == null) {
      return report;
    }
    final pdfBytes = selectedPdf.bytes;
    if (pdfBytes == null) {
      throw StateError('Selected PDF bytes are unavailable.');
    }

    final version = report.pdfVersion + 1;
    final upload = await _pdfStorageService.uploadReportPdf(
      bytes: pdfBytes,
      projectId: project.id,
      reportId: report.id,
      version: version,
      fileName: selectedPdf.name,
    );

    return report.copyWith(
      pdfStoragePath: upload.storagePath,
      pdfDownloadUrl: upload.downloadUrl,
      pdfFileName: upload.fileName,
      pdfGeneratedAt: uploadedAt,
      pdfVersion: version,
      pdfFileSizeBytes: upload.fileSizeBytes,
    );
  }

  Future<void> _pickPdfReport() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: true,
    );

    final file = result?.files.single;
    if (file == null) {
      return;
    }

    if ((file.extension ?? '').toLowerCase() != 'pdf') {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file.')),
      );
      return;
    }

    if (file.bytes == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read the selected PDF file.')),
      );
      return;
    }

    setState(() {
      _selectedPdfFile = file;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = _titleFromFile(file.name);
      }
    });
  }

  bool _canCoordinateReports(AppUser profile, Project project) {
    if (profile.role != UserRole.projectManager) {
      return false;
    }

    return project.projectManagerId == profile.uid ||
        project.createdBy == profile.uid;
  }

  bool _canWriteReport({
    required AppUser profile,
    required Project project,
    required List<ProjectMember> members,
  }) {
    final report = _existingReport;
    if (_canCoordinateReports(profile, project)) {
      return true;
    }

    if (report != null &&
        report.createdBy == profile.uid &&
        report.status == ReportStatus.draft) {
      return true;
    }

    if (report != null) {
      return false;
    }

    return members.any((member) {
      return member.userId == profile.uid &&
          member.status == ProjectMemberStatus.active &&
          (member.role == UserRole.siteEngineer ||
              member.role == UserRole.clerkOfWorks);
    });
  }

  Future<void> _pickReportDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _reportDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
    });
  }

  String _summaryText() {
    final note = _summaryController.text.trim();
    if (note.isNotEmpty) {
      return note;
    }

    final selectedFileName = _selectedPdfFile?.name.trim() ?? '';
    if (selectedFileName.isNotEmpty) {
      return 'Report file: $selectedFileName';
    }

    final existingFileName = _existingReport?.pdfFileName?.trim() ?? '';
    if (existingFileName.isNotEmpty) {
      return 'Report file: $existingFileName';
    }

    return 'Report submitted through SiteConnect.';
  }

  String _titleFromFile(String fileName) {
    final withoutExtension = fileName.replaceFirst(
      RegExp(r'\.pdf$', caseSensitive: false),
      '',
    );
    final readable = withoutExtension
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return readable.isEmpty ? 'PDF site report' : readable;
  }

  @override
  Widget build(BuildContext context) {
    _populateForm();

    return AppScaffold(
      title: _isEditing ? 'Edit report' : 'Submit report',
      body: FutureBuilder<AppUser>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Checking access');
          }

          if (profileSnapshot.hasError || profileSnapshot.data == null) {
            return const _ReportFormError(message: 'Unable to load access.');
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
                return _ReportFormError(
                  message: 'Unable to load this project.',
                  onRetry: () {
                    setState(() => _projectFuture = _loadProject());
                  },
                );
              }

              return FutureBuilder<List<ProjectMember>>(
                future: _membersFuture,
                builder: (context, membersSnapshot) {
                  if (membersSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const AppLoadingIndicator(
                      message: 'Loading project access',
                    );
                  }

                  final members =
                      membersSnapshot.data ?? const <ProjectMember>[];
                  if (!_canWriteReport(
                    profile: profile,
                    project: project,
                    members: members,
                  )) {
                    return const _ReportFormError(
                      message:
                          'Only assigned site roles or project managers can submit reports.',
                    );
                  }

                  return _buildForm(profile: profile, project: project);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildForm({required AppUser profile, required Project project}) {
    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ResponsiveLayout.maxContentWidth,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionCard(
                  title: 'Report details',
                  children: [
                    _DiaryProjectHeader(
                      project: project,
                      report: _existingReport,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Report title',
                        prefixIcon: Icon(Icons.title_outlined),
                      ),
                      validator: _required('Report title is required.'),
                    ),
                    const SizedBox(height: 14),
                    _DatePickerField(
                      label: 'Report date',
                      value: _reportDate,
                      onTap: _pickReportDate,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _summaryController,
                      minLines: 3,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Reference note (optional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Prepared report file',
                  children: [
                    _PdfAttachmentCard(
                      selectedFile: _selectedPdfFile,
                      existingReport: _existingReport,
                      onPickPdf: _pickPdfReport,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _DiaryActionBar(
                  isSaving: _isSaving,
                  onSaveDraft: () => _save(
                    profile: profile,
                    project: project,
                    status: ReportStatus.draft,
                  ),
                  onSubmit: () => _save(
                    profile: profile,
                    project: project,
                    status: ReportStatus.submitted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  FormFieldValidator<String> _required(String message) {
    return (value) {
      if ((value ?? '').trim().isEmpty) {
        return message;
      }

      return null;
    };
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PdfAttachmentCard extends StatelessWidget {
  const _PdfAttachmentCard({
    required this.selectedFile,
    required this.existingReport,
    required this.onPickPdf,
  });

  final PlatformFile? selectedFile;
  final SiteReport? existingReport;
  final VoidCallback onPickPdf;

  @override
  Widget build(BuildContext context) {
    final existingFileName = existingReport?.pdfFileName?.trim() ?? '';
    final hasExistingPdf = (existingReport?.pdfDownloadUrl ?? '')
        .trim()
        .isNotEmpty;
    final fileName = selectedFile?.name ?? existingFileName;
    final fileSize = selectedFile?.size ?? existingReport?.pdfFileSizeBytes;
    final hasPdf = selectedFile != null || hasExistingPdf;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.upload_file_outlined,
                color: hasPdf ? AppColors.civicRed : AppColors.fieldBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPdf ? fileName : 'No file attached',
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasPdf
                          ? [
                              if (fileSize != null) _fileSize(fileSize),
                              selectedFile == null
                                  ? 'Existing submitted file'
                                  : 'Ready to upload',
                            ].join(' - ')
                          : 'Attach the PDF prepared outside SiteConnect.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onPickPdf,
              icon: const Icon(Icons.attach_file_outlined),
              label: Text(hasPdf ? 'Replace PDF' : 'Attach PDF'),
            ),
          ),
        ],
      ),
    );
  }

  String _fileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / 1024).ceil()} KB';
  }
}

class _DiaryProjectHeader extends StatelessWidget {
  const _DiaryProjectHeader({required this.project, required this.report});

  final Project project;
  final SiteReport? report;

  @override
  Widget build(BuildContext context) {
    final status = report?.status;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_city_outlined, color: AppColors.fieldBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  project.district,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 8),
            Chip(
              avatar: Icon(_statusIcon(status), size: 18),
              label: Text(status.label),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }

  IconData _statusIcon(ReportStatus status) {
    return switch (status) {
      ReportStatus.draft => Icons.edit_note_outlined,
      ReportStatus.submitted => Icons.outbox_outlined,
      ReportStatus.received => Icons.mark_email_read_outlined,
    };
  }
}

class _DiaryActionBar extends StatelessWidget {
  const _DiaryActionBar({
    required this.isSaving,
    required this.onSaveDraft,
    required this.onSubmit,
  });

  final bool isSaving;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 620) {
          return Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSaving ? null : onSaveDraft,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Submit report',
                  icon: Icons.send_outlined,
                  isLoading: isSaving,
                  onPressed: onSubmit,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: isSaving ? null : onSaveDraft,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save draft'),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Submit report',
              icon: Icons.send_outlined,
              isLoading: isSaving,
              onPressed: onSubmit,
            ),
          ],
        );
      },
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          _formatDate(value),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
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

class _ReportFormError extends StatelessWidget {
  const _ReportFormError({required this.message, this.onRetry});

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
