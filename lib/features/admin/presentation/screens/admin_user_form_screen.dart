import 'package:flutter/material.dart';

import '../../../../core/constants/user_roles.dart';
import '../../../../core/services/admin_user_service.dart';
import '../../../../core/services/auth_failure.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../routes/app_route_arguments.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class AdminUserFormScreen extends StatefulWidget {
  const AdminUserFormScreen({
    UserFormRouteArguments? arguments,
    FirebaseAuthService? authService,
    AdminUserService? adminUserService,
    super.key,
  }) : _arguments = arguments,
       _authService = authService,
       _adminUserService = adminUserService;

  final UserFormRouteArguments? _arguments;
  final FirebaseAuthService? _authService;
  final AdminUserService? _adminUserService;

  @override
  State<AdminUserFormScreen> createState() => _AdminUserFormScreenState();
}

class _AdminUserFormScreenState extends State<AdminUserFormScreen> {
  late final FirebaseAuthService _authService;
  late final AdminUserService _adminUserService;
  late final Future<AppUser> _currentProfileFuture;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _districtController = TextEditingController();
  final _profileImageController = TextEditingController();

  late UserRole _selectedRole;
  late bool _isActive;
  bool _obscurePassword = true;
  bool _isSaving = false;

  AppUser? get _existingUser => widget._arguments?.user;
  bool get _isEditing => _existingUser != null;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _adminUserService = widget._adminUserService ?? AdminUserService();
    _currentProfileFuture = _authService.fetchCurrentUserProfile();

    final user = _existingUser;
    _selectedRole = user?.role == UserRole.unknown || user == null
        ? UserRole.siteEngineer
        : user.role;
    _isActive = user?.isActive ?? true;

    if (user != null) {
      _emailController.text = user.email;
      _fullNameController.text = user.fullName;
      _phoneController.text = user.phoneNumber;
      _districtController.text = user.district;
      _profileImageController.text = user.profileImage ?? '';
    }

    _emailController.addListener(_handleEmailChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _districtController.dispose();
    _profileImageController.dispose();
    super.dispose();
  }

  void _handleEmailChanged() {
    if (!_isEditing) {
      return;
    }

    setState(() {});
  }

  Future<void> _save(AppUser currentAdmin) async {
    if (_isSaving) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final existingUser = _existingUser;
      late final String successMessage;
      if (existingUser == null) {
        await _adminUserService.createManagedUser(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text,
          role: _selectedRole,
          phoneNumber: _phoneController.text,
          district: _districtController.text,
          profileImage: _profileImageController.text,
        );
        successMessage = 'User created.';
      } else {
        final isSelf = existingUser.uid == currentAdmin.uid;
        final updatedUser = existingUser.copyWith(
          fullName: _fullNameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          district: _districtController.text.trim(),
          profileImage: _profileImageController.text.trim(),
          role: isSelf ? existingUser.role : _selectedRole,
          isActive: isSelf ? existingUser.isActive : _isActive,
        );

        if (_isLoginEmailChanged) {
          await _adminUserService.replaceManagedUserLoginEmail(
            user: updatedUser,
            email: _emailController.text,
            password: _passwordController.text,
          );
          successMessage = 'New login created. Old email has been deactivated.';
        } else {
          await _adminUserService.updateManagedUser(updatedUser);
          successMessage = 'User updated.';
        }
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(successMessage);
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  bool get _isLoginEmailChanged {
    final existingUser = _existingUser;
    if (existingUser == null) {
      return false;
    }

    return _normalizedEmail(_emailController.text) !=
        _normalizedEmail(existingUser.email);
  }

  bool get _requiresTemporaryPassword {
    return !_isEditing || _isLoginEmailChanged;
  }

  String _normalizedEmail(String value) => value.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isEditing ? 'Edit user' : 'Add user',
      body: FutureBuilder<AppUser>(
        future: _currentProfileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Checking access');
          }

          if (snapshot.hasError ||
              snapshot.data == null ||
              snapshot.data!.role != UserRole.administrator) {
            return const _AdminAccessDenied();
          }

          final currentAdmin = snapshot.data!;
          return _buildForm(currentAdmin);
        },
      ),
    );
  }

  Widget _buildForm(AppUser currentAdmin) {
    final existingUser = _existingUser;
    final isSelf = existingUser?.uid == currentAdmin.uid;
    final canEditRole = !isSelf;
    final canEditEmail = !_isEditing || !isSelf;

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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            enabled: canEditEmail,
                            autofillHints: const [AutofillHints.email],
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: const Icon(Icons.mail_outline),
                              helperText: _emailHelperText(isSelf),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) {
                                return 'Email address is required.';
                              }
                              if (!email.contains('@')) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          if (_requiresTemporaryPassword) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: _isEditing
                                    ? 'Temporary password for new login'
                                    : 'Temporary password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final password = value ?? '';
                                if (password.isEmpty) {
                                  return 'Temporary password is required.';
                                }
                                if (password.length < 6) {
                                  return 'Use at least 6 characters.';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _fullNameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Full name is required.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _profileImageController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Profile photo URL',
                              prefixIcon: Icon(Icons.image_outlined),
                            ),
                            validator: (value) {
                              final imageUrl = value?.trim() ?? '';
                              if (imageUrl.isEmpty) {
                                return null;
                              }
                              final uri = Uri.tryParse(imageUrl);
                              if (uri == null ||
                                  !(uri.scheme == 'http' ||
                                      uri.scheme == 'https')) {
                                return 'Enter a valid image URL.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _districtController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'District',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'District is required.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<UserRole>(
                            initialValue: _selectedRole,
                            decoration: InputDecoration(
                              labelText: 'Role',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              helperText: isSelf
                                  ? 'Your own administrator role is locked here.'
                                  : null,
                            ),
                            items: UserRole.values
                                .where((role) => role != UserRole.unknown)
                                .map(
                                  (role) => DropdownMenuItem<UserRole>(
                                    value: role,
                                    child: Text(role.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: canEditRole
                                ? (role) {
                                    if (role == null) {
                                      return;
                                    }
                                    setState(() => _selectedRole = role);
                                  }
                                : null,
                          ),
                          if (_isEditing) ...[
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _isActive,
                              onChanged: isSelf
                                  ? null
                                  : (value) {
                                      setState(() => _isActive = value);
                                    },
                              title: const Text('Active account'),
                              subtitle: Text(
                                isSelf
                                    ? 'Your own account cannot be deactivated here.'
                                    : 'Inactive users cannot open SiteConnect.',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: _isEditing ? 'Save user' : 'Create user',
                    icon: _isEditing
                        ? Icons.save_outlined
                        : Icons.person_add_alt_1_outlined,
                    isLoading: _isSaving,
                    onPressed: () => _save(currentAdmin),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _emailHelperText(bool isSelf) {
    if (!_isEditing) {
      return 'This is the user login email.';
    }

    if (isSelf) {
      return 'Your own login email cannot be changed here.';
    }

    if (_isLoginEmailChanged) {
      return 'A new login will be created and the old email will be deactivated.';
    }

    return 'Edit this to replace the user login email.';
  }
}

class _AdminAccessDenied extends StatelessWidget {
  const _AdminAccessDenied();

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
              'Administrator access is required.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
