import 'package:flutter/material.dart';

import '../../../../core/constants/firestore_enums.dart';
import '../../../../core/constants/user_roles.dart';
import '../../../../core/repositories/projects_repository.dart';
import '../../../../core/repositories/users_repository.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../routes/app_route_arguments.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class ProjectFormScreen extends StatefulWidget {
  const ProjectFormScreen({
    ProjectFormRouteArguments? arguments,
    FirebaseAuthService? authService,
    ProjectsRepository? projectsRepository,
    UsersRepository? usersRepository,
    super.key,
  }) : _arguments = arguments,
       _authService = authService,
       _projectsRepository = projectsRepository,
       _usersRepository = usersRepository;

  final ProjectFormRouteArguments? _arguments;
  final FirebaseAuthService? _authService;
  final ProjectsRepository? _projectsRepository;
  final UsersRepository? _usersRepository;

  @override
  State<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends State<ProjectFormScreen> {
  late final FirebaseAuthService _authService;
  late final ProjectsRepository _projectsRepository;
  late final UsersRepository _usersRepository;
  late final Future<AppUser> _profileFuture;
  late Future<Project?> _projectFuture;
  Future<List<AppUser>>? _projectManagersFuture;

  final _formKey = GlobalKey<FormState>();
  final _projectCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _districtController = TextEditingController();
  final _contractorController = TextEditingController();
  final _budgetController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  ProjectStatus _selectedStatus = ProjectStatus.planning;
  DateTime? _startDate;
  DateTime? _expectedEndDate;
  String _selectedProjectManagerId = '';
  String? _loadedProjectKey;
  bool _isSaving = false;

  bool get _isEditing {
    final project = widget._arguments?.project;
    final projectId = widget._arguments?.projectId?.trim() ?? '';
    return (project != null && project.id.trim().isNotEmpty) ||
        projectId.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _projectsRepository = widget._projectsRepository ?? ProjectsRepository();
    _usersRepository = widget._usersRepository ?? UsersRepository();
    _profileFuture = _authService.fetchCurrentUserProfile();
    _projectFuture = _loadProject();
  }

  @override
  void dispose() {
    _projectCodeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _districtController.dispose();
    _contractorController.dispose();
    _budgetController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<Project?> _loadProject() {
    final project = widget._arguments?.project;
    if (project != null) {
      return Future<Project?>.value(project);
    }

    final projectId = widget._arguments?.projectId?.trim() ?? '';
    if (projectId.isEmpty) {
      return Future<Project?>.value();
    }

    return _projectsRepository.findById(projectId);
  }

  void _populateForm({required AppUser profile, Project? project}) {
    final projectKey = project?.id ?? '__new_project__';
    if (_loadedProjectKey == projectKey) {
      return;
    }

    _loadedProjectKey = projectKey;

    if (project == null) {
      _districtController.text = profile.district;
      _selectedStatus = ProjectStatus.planning;
      _selectedProjectManagerId = profile.role == UserRole.projectManager
          ? profile.uid
          : '';
      return;
    }

    _projectCodeController.text = project.projectCode ?? '';
    _nameController.text = project.name;
    _descriptionController.text = project.description;
    _districtController.text = project.district;
    _contractorController.text = project.contractorName ?? '';
    _budgetController.text = _numberText(project.budgetAmount);
    _latitudeController.text = _numberText(project.latitude);
    _longitudeController.text = _numberText(project.longitude);
    _selectedStatus = project.status;
    _startDate = project.startDate;
    _expectedEndDate = project.expectedEndDate;
    _selectedProjectManagerId = project.projectManagerId ?? '';
  }

  Future<void> _save(AppUser profile, Project? existingProject) async {
    if (_isSaving) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    if (_startDate != null &&
        _expectedEndDate != null &&
        _expectedEndDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expected end date cannot be before the start date.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final project = Project(
        id: existingProject?.id ?? _projectsRepository.newDocumentId(),
        projectCode: _blankToNull(_projectCodeController.text),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        district: _districtController.text.trim(),
        status: _selectedStatus,
        contractorName: _blankToNull(_contractorController.text),
        projectManagerId: _projectManagerIdForSave(profile),
        startDate: _startDate,
        expectedEndDate: _expectedEndDate,
        budgetAmount: _optionalDouble(_budgetController.text),
        latitude: _optionalDouble(_latitudeController.text),
        longitude: _optionalDouble(_longitudeController.text),
        createdAt: existingProject?.createdAt ?? now,
        updatedAt: now,
        createdBy: _createdBy(profile, existingProject),
      );

      await _projectsRepository.save(project);

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pop(existingProject == null ? 'Project created.' : 'Project updated.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save this project.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _createdBy(AppUser profile, Project? existingProject) {
    final createdBy = existingProject?.createdBy.trim() ?? '';
    return createdBy.isEmpty ? profile.uid : createdBy;
  }

  String? _projectManagerIdForSave(AppUser profile) {
    if (profile.role == UserRole.projectManager) {
      return profile.uid;
    }

    return _blankToNull(_selectedProjectManagerId);
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _optionalDouble(String value) {
    final cleaned = value.trim().replaceAll(',', '');
    if (cleaned.isEmpty) {
      return null;
    }

    return double.tryParse(cleaned);
  }

  String _numberText(double? value) {
    if (value == null) {
      return '';
    }

    if (value == value.roundToDouble()) {
      return value.round().toString();
    }

    return value.toString();
  }

  Future<void> _pickDate({
    required DateTime? currentValue,
    required ValueChanged<DateTime?> onChanged,
  }) async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentValue ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      onChanged(
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
      );
    });
  }

  bool _canManageProject(AppUser profile, Project? project) {
    if (profile.role == UserRole.administrator) {
      return true;
    }

    if (profile.role != UserRole.projectManager) {
      return false;
    }

    return project == null ||
        project.projectManagerId == profile.uid ||
        project.createdBy == profile.uid;
  }

  Future<List<AppUser>> _projectManagers() {
    return _projectManagersFuture ??= _usersRepository.getQuery(
      _usersRepository.usersByRole(UserRole.projectManager, limit: 100),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEditing ? 'Edit project' : 'New project',
      body: FutureBuilder<AppUser>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Checking access');
          }

          if (profileSnapshot.hasError || profileSnapshot.data == null) {
            return const _ProjectFormError(message: 'Unable to load access.');
          }

          final profile = profileSnapshot.data!;

          return FutureBuilder<Project?>(
            future: _projectFuture,
            builder: (context, projectSnapshot) {
              if (projectSnapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingIndicator(message: 'Loading project');
              }

              if (projectSnapshot.hasError) {
                return _ProjectFormError(
                  message: 'Unable to load this project.',
                  onRetry: () {
                    setState(() => _projectFuture = _loadProject());
                  },
                );
              }

              final project = projectSnapshot.data;
              if (_isEditing && project == null) {
                return _ProjectFormError(
                  message: 'This project could not be found.',
                  onRetry: () {
                    setState(() => _projectFuture = _loadProject());
                  },
                );
              }

              if (!_canManageProject(profile, project)) {
                return const _ProjectFormError(
                  message:
                      'Administrator or project manager access is required.',
                );
              }

              _populateForm(profile: profile, project: project);

              if (profile.role != UserRole.administrator) {
                return _buildForm(
                  profile: profile,
                  project: project,
                  projectManagers: const <AppUser>[],
                );
              }

              return FutureBuilder<List<AppUser>>(
                future: _projectManagers(),
                builder: (context, managersSnapshot) {
                  if (managersSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const AppLoadingIndicator(
                      message: 'Loading project managers',
                    );
                  }

                  return _buildForm(
                    profile: profile,
                    project: project,
                    projectManagers: managersSnapshot.data ?? const <AppUser>[],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildForm({
    required AppUser profile,
    required Project? project,
    required List<AppUser> projectManagers,
  }) {
    return SingleChildScrollView(
      padding: ResponsiveLayout.pagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ResponsiveLayout.maxContentWidth,
          ),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Project basics',
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Project name',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        validator: _required('Project name is required.'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _projectCodeController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Project code',
                          prefixIcon: Icon(Icons.tag_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _districtController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'District',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: _required('District is required.'),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<ProjectStatus>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Project status',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: ProjectStatus.values
                            .map(
                              (status) => DropdownMenuItem<ProjectStatus>(
                                value: status,
                                child: Text(status.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (status) {
                          if (status == null) {
                            return;
                          }

                          setState(() => _selectedStatus = status);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Project description',
                          prefixIcon: Icon(Icons.notes_outlined),
                          alignLabelWithHint: true,
                        ),
                        validator: _required(
                          'Project description is required.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Contract details',
                    children: [
                      TextFormField(
                        controller: _contractorController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Contractor name',
                          prefixIcon: Icon(Icons.engineering_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _budgetController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Budget amount',
                          prefixIcon: Icon(Icons.payments_outlined),
                          prefixText: 'UGX ',
                        ),
                        validator: (value) => _validateOptionalNumber(
                          value,
                          label: 'budget amount',
                          min: 0,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _DatePickerField(
                        label: 'Start date',
                        icon: Icons.play_circle_outline,
                        value: _startDate,
                        onTap: () => _pickDate(
                          currentValue: _startDate,
                          onChanged: (value) => _startDate = value,
                        ),
                        onClear: _startDate == null
                            ? null
                            : () {
                                setState(() => _startDate = null);
                              },
                      ),
                      const SizedBox(height: 14),
                      _DatePickerField(
                        label: 'Expected end date',
                        icon: Icons.event_available_outlined,
                        value: _expectedEndDate,
                        onTap: () => _pickDate(
                          currentValue: _expectedEndDate,
                          onChanged: (value) => _expectedEndDate = value,
                        ),
                        onClear: _expectedEndDate == null
                            ? null
                            : () {
                                setState(() => _expectedEndDate = null);
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Location and ownership',
                    children: [
                      if (profile.role == UserRole.administrator)
                        _ProjectManagerField(
                          projectManagers: projectManagers,
                          selectedProjectManagerId: _selectedProjectManagerId,
                          onChanged: (value) {
                            setState(() {
                              _selectedProjectManagerId = value ?? '';
                            });
                          },
                        )
                      else
                        _LockedManagerTile(profile: profile),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _latitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          prefixIcon: Icon(Icons.explore_outlined),
                        ),
                        validator: (value) => _validateOptionalNumber(
                          value,
                          label: 'latitude',
                          min: -90,
                          max: 90,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _longitudeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _save(profile, project),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          prefixIcon: Icon(Icons.explore_outlined),
                        ),
                        validator: (value) => _validateOptionalNumber(
                          value,
                          label: 'longitude',
                          min: -180,
                          max: 180,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: project == null ? 'Create project' : 'Save project',
                    icon: project == null
                        ? Icons.add_business_outlined
                        : Icons.save_outlined,
                    isLoading: _isSaving,
                    onPressed: () => _save(profile, project),
                  ),
                ],
              ),
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

  String? _validateOptionalNumber(
    String? value, {
    required String label,
    double? min,
    double? max,
  }) {
    final cleaned = (value ?? '').trim().replaceAll(',', '');
    if (cleaned.isEmpty) {
      return null;
    }

    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return 'Enter a valid $label.';
    }

    if (min != null && parsed < min) {
      return 'Enter a $label of at least $min.';
    }

    if (max != null && parsed > max) {
      return 'Enter a $label of at most $max.';
    }

    return null;
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

class _ProjectManagerField extends StatelessWidget {
  const _ProjectManagerField({
    required this.projectManagers,
    required this.selectedProjectManagerId,
    required this.onChanged,
  });

  final List<AppUser> projectManagers;
  final String selectedProjectManagerId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: '', child: Text('Unassigned')),
      ...projectManagers
          .where((user) => user.isActive)
          .map(
            (user) => DropdownMenuItem<String>(
              value: user.uid,
              child: Text(_managerLabel(user)),
            ),
          ),
    ];

    final hasSelectedManager =
        selectedProjectManagerId.isEmpty ||
        items.any((item) => item.value == selectedProjectManagerId);

    if (!hasSelectedManager) {
      items.add(
        DropdownMenuItem<String>(
          value: selectedProjectManagerId,
          child: Text('Current manager ($selectedProjectManagerId)'),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: selectedProjectManagerId,
      decoration: const InputDecoration(
        labelText: 'Project manager',
        prefixIcon: Icon(Icons.supervisor_account_outlined),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  String _managerLabel(AppUser user) {
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

class _LockedManagerTile extends StatelessWidget {
  const _LockedManagerTile({required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Project manager',
        prefixIcon: Icon(Icons.supervisor_account_outlined),
      ),
      child: Text(
        profile.fullName.trim().isEmpty ? profile.email : profile.fullName,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final IconData icon;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final color = value == null
        ? Theme.of(context).hintColor
        : Theme.of(context).textTheme.bodyLarge?.color;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  tooltip: 'Clear date',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(
          value == null ? 'Select date' : _formatDate(value!),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color),
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

class _ProjectFormError extends StatelessWidget {
  const _ProjectFormError({required this.message, this.onRetry});

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
