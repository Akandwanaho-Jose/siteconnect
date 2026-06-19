import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/auth_failure.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/profile_image_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    FirebaseAuthService? authService,
    ProfileImageStorageService? profileImageStorageService,
    ImagePicker? imagePicker,
    super.key,
  }) : _authService = authService,
       _profileImageStorageService = profileImageStorageService,
       _imagePicker = imagePicker;

  final FirebaseAuthService? _authService;
  final ProfileImageStorageService? _profileImageStorageService;
  final ImagePicker? _imagePicker;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final FirebaseAuthService _authService;
  late final ProfileImageStorageService _profileImageStorageService;
  late final ImagePicker _imagePicker;
  late Future<AppUser> _profileFuture;

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _districtController = TextEditingController();

  String? _loadedUid;
  String _profileImageUrl = '';
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _profileImageStorageService =
        widget._profileImageStorageService ?? ProfileImageStorageService();
    _imagePicker = widget._imagePicker ?? ImagePicker();
    _profileFuture = _authService.fetchCurrentUserProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      var profileImage = _profileImageUrl.trim();
      final selectedImage = _selectedImage;
      if (selectedImage != null) {
        final userId = _loadedUid ?? _authService.currentUser?.uid ?? '';
        if (userId.isEmpty) {
          throw const AuthFailure(
            code: 'profile-image-user-missing',
            message: 'Unable to confirm your account before uploading photo.',
          );
        }

        profileImage = await _profileImageStorageService.uploadProfileImage(
          image: selectedImage,
          userId: userId,
        );
      }

      await _authService.updateCurrentUserProfile(
        fullName: _fullNameController.text,
        phoneNumber: _phoneController.text,
        district: _districtController.text,
        profileImage: profileImage,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.of(context).pop(true);
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

  Future<void> _openPasswordChange() async {
    await Navigator.of(context).pushNamed(AppRoutes.passwordChange);
  }

  Future<void> _openImageSourceSheet() async {
    if (_isPickingImage || _isSaving) {
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

    await _pickProfileImage(source);
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    setState(() => _isPickingImage = true);

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 900,
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
        const SnackBar(content: Text('Unable to select this profile photo.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _removeProfileImage() {
    setState(() {
      _profileImageUrl = '';
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  void _populate(AppUser profile) {
    if (_loadedUid == profile.uid) {
      return;
    }

    _loadedUid = profile.uid;
    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phoneNumber;
    _districtController.text = profile.district;
    _profileImageUrl = profile.profileImage ?? '';
    _selectedImage = null;
    _selectedImageBytes = null;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Edit profile',
      body: FutureBuilder<AppUser>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Loading profile');
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _ProfileLoadError(
              onRetry: () {
                setState(() {
                  _loadedUid = null;
                  _profileFuture = _authService.fetchCurrentUserProfile();
                });
              },
            );
          }

          final profile = snapshot.data!;
          _populate(profile);

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
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ProfilePhotoEditor(
                                fullName: _fullNameController.text,
                                email: profile.email,
                                imageUrl: _profileImageUrl,
                                selectedImageBytes: _selectedImageBytes,
                                isBusy: _isSaving || _isPickingImage,
                                onChangePhoto: _openImageSourceSheet,
                                onRemovePhoto: _removeProfileImage,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                profile.email,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.role.label,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.mutedInk),
                              ),
                              const SizedBox(height: 18),
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
                                controller: _districtController,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _save(),
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppButton(
                        label: 'Save profile',
                        icon: Icons.save_outlined,
                        isLoading: _isSaving,
                        onPressed: _save,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openPasswordChange,
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Change password'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfilePhotoEditor extends StatelessWidget {
  const _ProfilePhotoEditor({
    required this.fullName,
    required this.email,
    required this.imageUrl,
    required this.selectedImageBytes,
    required this.isBusy,
    required this.onChangePhoto,
    required this.onRemovePhoto,
  });

  final String fullName;
  final String email;
  final String imageUrl;
  final Uint8List? selectedImageBytes;
  final bool isBusy;
  final VoidCallback onChangePhoto;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = selectedImageBytes != null || imageUrl.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ProfileAvatar(
          fullName: fullName,
          email: email,
          imageUrl: imageUrl,
          selectedImageBytes: selectedImageBytes,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: isBusy ? null : onChangePhoto,
                icon: Icon(
                  isBusy
                      ? Icons.hourglass_empty_outlined
                      : Icons.add_a_photo_outlined,
                ),
                label: Text(hasPhoto ? 'Change photo' : 'Add photo'),
              ),
              if (hasPhoto)
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onRemovePhoto,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.fullName,
    required this.email,
    required this.imageUrl,
    required this.selectedImageBytes,
  });

  final String fullName;
  final String email;
  final String imageUrl;
  final Uint8List? selectedImageBytes;

  @override
  Widget build(BuildContext context) {
    final selectedBytes = selectedImageBytes;
    Widget image;

    if (selectedBytes != null) {
      image = Image.memory(selectedBytes, fit: BoxFit.cover);
    } else if (imageUrl.trim().startsWith('http://') ||
        imageUrl.trim().startsWith('https://')) {
      image = Image.network(
        imageUrl.trim(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _InitialsAvatar(initials: _initials(fullName, email));
        },
      );
    } else {
      image = _InitialsAvatar(initials: _initials(fullName, email));
    }

    return ClipOval(child: SizedBox(width: 76, height: 76, child: image));
  }

  String _initials(String name, String email) {
    final source = name.trim().isEmpty ? email : name;
    final parts = source
        .split(RegExp(r'\s+|@|\.|-|_'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'U';
    }

    return parts.map((part) => part[0].toUpperCase()).join();
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

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
              'Unable to load your profile.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
