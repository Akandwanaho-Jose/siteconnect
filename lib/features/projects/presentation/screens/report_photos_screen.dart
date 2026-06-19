import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/firestore_enums.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/repositories/project_members_repository.dart';
import '../../../../core/repositories/projects_repository.dart';
import '../../../../core/repositories/report_photos_repository.dart';
import '../../../../core/repositories/site_reports_repository.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/report_photo_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../routes/app_route_arguments.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/models/project_member.dart';
import '../../../../shared/models/report_photo.dart';
import '../../../../shared/models/site_report.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_motion.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_visuals.dart';

class ReportPhotosScreen extends StatefulWidget {
  const ReportPhotosScreen({
    required ReportPhotosRouteArguments arguments,
    FirebaseAuthService? authService,
    ProjectsRepository? projectsRepository,
    ProjectMembersRepository? projectMembersRepository,
    SiteReportsRepository? siteReportsRepository,
    ReportPhotosRepository? reportPhotosRepository,
    ReportPhotoStorageService? storageService,
    ImagePicker? imagePicker,
    super.key,
  }) : _arguments = arguments,
       _authService = authService,
       _projectsRepository = projectsRepository,
       _projectMembersRepository = projectMembersRepository,
       _siteReportsRepository = siteReportsRepository,
       _reportPhotosRepository = reportPhotosRepository,
       _storageService = storageService,
       _imagePicker = imagePicker;

  final ReportPhotosRouteArguments _arguments;
  final FirebaseAuthService? _authService;
  final ProjectsRepository? _projectsRepository;
  final ProjectMembersRepository? _projectMembersRepository;
  final SiteReportsRepository? _siteReportsRepository;
  final ReportPhotosRepository? _reportPhotosRepository;
  final ReportPhotoStorageService? _storageService;
  final ImagePicker? _imagePicker;

  @override
  State<ReportPhotosScreen> createState() => _ReportPhotosScreenState();
}

class _ReportPhotosScreenState extends State<ReportPhotosScreen> {
  late final FirebaseAuthService _authService;
  late final ProjectsRepository _projectsRepository;
  late final ProjectMembersRepository _projectMembersRepository;
  late final SiteReportsRepository _siteReportsRepository;
  late final ReportPhotosRepository _reportPhotosRepository;
  late final ReportPhotoStorageService _storageService;
  late final ImagePicker _imagePicker;
  late final Future<AppUser> _profileFuture;
  late Future<Project?> _projectFuture;
  late Future<SiteReport?> _reportFuture;
  late Future<List<ProjectMember>> _membersFuture;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _projectsRepository = widget._projectsRepository ?? ProjectsRepository();
    _projectMembersRepository =
        widget._projectMembersRepository ?? ProjectMembersRepository();
    _siteReportsRepository =
        widget._siteReportsRepository ?? SiteReportsRepository();
    _reportPhotosRepository =
        widget._reportPhotosRepository ?? ReportPhotosRepository();
    _storageService = widget._storageService ?? ReportPhotoStorageService();
    _imagePicker = widget._imagePicker ?? ImagePicker();
    _profileFuture = _authService.fetchCurrentUserProfile();
    _projectFuture = _loadProject();
    _reportFuture = _loadReport();
    _membersFuture = _projectMembersRepository.getQuery(
      _projectMembersRepository.allMembersForProject(
        widget._arguments.projectId,
      ),
    );
  }

  Future<Project?> _loadProject() {
    if (widget._arguments.project != null) {
      return Future<Project?>.value(widget._arguments.project);
    }

    return _projectsRepository.findById(widget._arguments.projectId);
  }

  Future<SiteReport?> _loadReport() {
    if (widget._arguments.report != null) {
      return Future<SiteReport?>.value(widget._arguments.report);
    }

    return _siteReportsRepository.findById(widget._arguments.reportId);
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

  bool _canAddPhoto({
    required AppUser profile,
    required Project project,
    required SiteReport report,
    required List<ProjectMember> members,
  }) {
    if (_canManageProject(profile, project) ||
        report.createdBy == profile.uid) {
      return true;
    }

    return members.any((member) {
      return member.userId == profile.uid &&
          member.status == ProjectMemberStatus.active &&
          (member.role == UserRole.siteEngineer ||
              member.role == UserRole.clerkOfWorks);
    });
  }

  bool _canEditPhoto({
    required AppUser profile,
    required Project project,
    required ReportPhoto photo,
  }) {
    return _canManageProject(profile, project) ||
        photo.createdBy == profile.uid;
  }

  Future<void> _choosePhotoSource({
    required AppUser profile,
    required Project project,
    required SiteReport report,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }

    await _pickAndUploadPhoto(
      source: source,
      profile: profile,
      project: project,
      report: report,
    );
  }

  Future<void> _pickAndUploadPhoto({
    required ImageSource source,
    required AppUser profile,
    required Project project,
    required SiteReport report,
  }) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );

    if (image == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final caption = await _captionDialog(title: 'Photo caption');
    if (caption == null || !mounted) {
      return;
    }

    setState(() => _isUploading = true);

    try {
      final now = DateTime.now();
      final photoId = _reportPhotosRepository.newDocumentId();
      final upload = await _storageService.uploadReportPhoto(
        image: image,
        projectId: project.id,
        reportId: report.id,
        photoId: photoId,
      );
      final photo = ReportPhoto(
        id: photoId,
        projectId: project.id,
        reportId: report.id,
        storagePath: upload.storagePath,
        downloadUrl: upload.downloadUrl,
        caption: _blankToNull(caption),
        takenAt: now,
        createdAt: now,
        updatedAt: now,
        createdBy: profile.uid,
      );

      await _reportPhotosRepository.save(photo);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo evidence uploaded.')));
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_storageErrorMessage(error))));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to upload photo evidence.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _editCaption(ReportPhoto photo) async {
    final caption = await _captionDialog(
      title: 'Edit caption',
      initialValue: photo.caption ?? '',
    );
    if (caption == null) {
      return;
    }

    try {
      await _reportPhotosRepository.save(
        ReportPhoto(
          id: photo.id,
          projectId: photo.projectId,
          reportId: photo.reportId,
          storagePath: photo.storagePath,
          downloadUrl: photo.downloadUrl,
          caption: _blankToNull(caption),
          takenAt: photo.takenAt,
          latitude: photo.latitude,
          longitude: photo.longitude,
          createdAt: photo.createdAt,
          updatedAt: DateTime.now(),
          createdBy: photo.createdBy,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Caption updated.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update caption.')),
      );
    }
  }

  Future<void> _deletePhoto(ReportPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text(
          'This removes the photo evidence from this report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _storageService.deleteReportPhoto(photo.storagePath);
      await _reportPhotosRepository.deleteById(photo.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo evidence deleted.')));
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_storageErrorMessage(error))));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete photo evidence.')),
      );
    }
  }

  Future<String?> _captionDialog({
    required String title,
    String initialValue = '',
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _CaptionDialog(title: title, initialValue: initialValue),
    );
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _storageErrorMessage(FirebaseException error) {
    return switch (error.code) {
      'unauthorized' => 'Storage permission denied. Deploy storage rules.',
      'object-not-found' => 'Photo file could not be found.',
      'quota-exceeded' => 'Storage quota exceeded.',
      _ => 'Storage error: ${error.message ?? error.code}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Photo evidence',
      body: FutureBuilder<AppUser>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Checking access');
          }

          if (profileSnapshot.hasError || profileSnapshot.data == null) {
            return const _PhotoEvidenceError(message: 'Unable to load access.');
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
                return _PhotoEvidenceError(
                  message: 'Unable to load this project.',
                  onRetry: () {
                    setState(() => _projectFuture = _loadProject());
                  },
                );
              }

              return FutureBuilder<SiteReport?>(
                future: _reportFuture,
                builder: (context, reportSnapshot) {
                  if (reportSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const AppLoadingIndicator(message: 'Loading report');
                  }

                  final report = reportSnapshot.data;
                  if (reportSnapshot.hasError || report == null) {
                    return _PhotoEvidenceError(
                      message: 'Unable to load this report.',
                      onRetry: () {
                        setState(() => _reportFuture = _loadReport());
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
                      final canAdd = _canAddPhoto(
                        profile: profile,
                        project: project,
                        report: report,
                        members: members,
                      );

                      return StreamBuilder<List<ReportPhoto>>(
                        stream: _reportPhotosRepository.watchQuery(
                          _reportPhotosRepository.photosForReport(report.id),
                        ),
                        builder: (context, photosSnapshot) {
                          if (photosSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const AppLoadingIndicator(
                              message: 'Loading photo evidence',
                            );
                          }

                          if (photosSnapshot.hasError) {
                            return const _PhotoEvidenceError(
                              message: 'Unable to load photo evidence.',
                            );
                          }

                          final photos =
                              photosSnapshot.data ?? const <ReportPhoto>[];
                          return _PhotoEvidenceBody(
                            profile: profile,
                            project: project,
                            report: report,
                            photos: photos,
                            canAdd: canAdd,
                            isUploading: _isUploading,
                            canEditPhoto: (photo) => _canEditPhoto(
                              profile: profile,
                              project: project,
                              photo: photo,
                            ),
                            onAddPhoto: () => _choosePhotoSource(
                              profile: profile,
                              project: project,
                              report: report,
                            ),
                            onEditCaption: _editCaption,
                            onDeletePhoto: _deletePhoto,
                          );
                        },
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

class _PhotoEvidenceBody extends StatelessWidget {
  const _PhotoEvidenceBody({
    required this.profile,
    required this.project,
    required this.report,
    required this.photos,
    required this.canAdd,
    required this.isUploading,
    required this.canEditPhoto,
    required this.onAddPhoto,
    required this.onEditCaption,
    required this.onDeletePhoto,
  });

  final AppUser profile;
  final Project project;
  final SiteReport report;
  final List<ReportPhoto> photos;
  final bool canAdd;
  final bool isUploading;
  final bool Function(ReportPhoto photo) canEditPhoto;
  final VoidCallback onAddPhoto;
  final ValueChanged<ReportPhoto> onEditCaption;
  final ValueChanged<ReportPhoto> onDeletePhoto;

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
                child: _PhotoEvidenceHeader(
                  profile: profile,
                  project: project,
                  report: report,
                  photoCount: photos.length,
                  canAdd: canAdd,
                  isUploading: isUploading,
                  onAddPhoto: onAddPhoto,
                ),
              ),
              const SizedBox(height: 16),
              if (photos.isEmpty)
                AppAnimatedEntry(
                  index: 1,
                  child: AppEmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'No photo evidence yet.',
                    action: canAdd
                        ? FilledButton.icon(
                            onPressed: isUploading ? null : onAddPhoto,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Add first photo'),
                          )
                        : null,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final spacing = 12.0;
                    final columns = constraints.maxWidth >= 860
                        ? 3
                        : constraints.maxWidth >= 560
                        ? 2
                        : 1;
                    final tileWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: photos
                          .asMap()
                          .entries
                          .map((entry) {
                            final photo = entry.value;
                            return SizedBox(
                              width: tileWidth,
                              child: AppAnimatedEntry(
                                key: ValueKey(photo.id),
                                index: entry.key + 1,
                                child: _PhotoCard(
                                  photo: photo,
                                  canEdit: canEditPhoto(photo),
                                  onEditCaption: () => onEditCaption(photo),
                                  onDelete: () => onDeletePhoto(photo),
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionDialog extends StatefulWidget {
  const _CaptionDialog({required this.title, required this.initialValue});

  final String title;
  final String initialValue;

  @override
  State<_CaptionDialog> createState() => _CaptionDialogState();
}

class _CaptionDialogState extends State<_CaptionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Caption',
          prefixIcon: Icon(Icons.short_text_outlined),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PhotoEvidenceHeader extends StatelessWidget {
  const _PhotoEvidenceHeader({
    required this.profile,
    required this.project,
    required this.report,
    required this.photoCount,
    required this.canAdd,
    required this.isUploading,
    required this.onAddPhoto,
  });

  final AppUser profile;
  final Project project;
  final SiteReport report;
  final int photoCount;
  final bool canAdd;
  final bool isUploading;
  final VoidCallback onAddPhoto;

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
                  icon: Icons.photo_library_outlined,
                  color: AppColors.primaryGreen,
                  size: 48,
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
                      const SizedBox(height: 4),
                      Text(
                        '${project.name} - ${profile.role.label}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoChip(
                        icon: Icons.photo_camera_outlined,
                        label: '$photoCount photo${photoCount == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (canAdd) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: isUploading ? null : onAddPhoto,
                  icon: isUploading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_a_photo_outlined),
                  label: Text(isUploading ? 'Uploading' : 'Add photo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.canEdit,
    required this.onEditCaption,
    required this.onDelete,
  });

  final ReportPhoto photo;
  final bool canEdit;
  final VoidCallback onEditCaption;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final caption = photo.caption?.trim() ?? '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: InkWell(
              onTap: () => _openPreview(context),
              child: _NetworkPhoto(url: photo.downloadUrl, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caption.isEmpty ? 'No caption' : caption,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            icon: Icons.event_outlined,
                            label: _dateTime(photo.takenAt ?? photo.createdAt),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (canEdit)
                  PopupMenuButton<_PhotoAction>(
                    tooltip: 'Photo actions',
                    onSelected: (action) {
                      switch (action) {
                        case _PhotoAction.editCaption:
                          onEditCaption();
                        case _PhotoAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<_PhotoAction>(
                        value: _PhotoAction.editCaption,
                        child: Text('Edit caption'),
                      ),
                      PopupMenuItem<_PhotoAction>(
                        value: _PhotoAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPreview(BuildContext context) {
    final caption = photo.caption?.trim() ?? '';
    return showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: _NetworkPhoto(
                      url: photo.downloadUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                if (caption.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          caption,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
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
}

enum _PhotoAction { editCaption, delete }

class _NetworkPhoto extends StatelessWidget {
  const _NetworkPhoto({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.pageBackground,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.mutedInk,
              size: 42,
            ),
          ),
        );
      },
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

class _PhotoEvidenceError extends StatelessWidget {
  const _PhotoEvidenceError({required this.message, this.onRetry});

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
