import 'package:flutter/material.dart';

import '../../../../core/constants/user_roles.dart';
import '../../../../core/repositories/users_repository.dart';
import '../../../../core/services/auth_failure.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../routes/app_route_arguments.dart';
import '../../../../routes/app_routes.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({
    FirebaseAuthService? authService,
    UsersRepository? usersRepository,
    super.key,
  }) : _authService = authService,
       _usersRepository = usersRepository;

  final FirebaseAuthService? _authService;
  final UsersRepository? _usersRepository;

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  late final FirebaseAuthService _authService;
  late final UsersRepository _usersRepository;
  late Future<AppUser> _currentProfileFuture;

  final _searchController = TextEditingController();
  String _searchTerm = '';
  UserRole? _roleFilter;
  bool? _activeFilter;
  String? _districtFilter;

  @override
  void initState() {
    super.initState();
    _authService = widget._authService ?? FirebaseAuthService();
    _usersRepository = widget._usersRepository ?? UsersRepository();
    _currentProfileFuture = _authService.fetchCurrentUserProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openUserForm({AppUser? user}) async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.adminUserForm,
      arguments: UserFormRouteArguments(user: user),
    );

    if (!mounted || result == null) {
      return;
    }

    final message = result is String
        ? result
        : user == null
        ? 'User created.'
        : 'User updated.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<AppUser> _filteredUsers(List<AppUser> users) {
    final query = _searchTerm.trim().toLowerCase();

    return users
        .where((user) {
          if (_roleFilter != null && user.role != _roleFilter) {
            return false;
          }

          if (_activeFilter != null && user.isActive != _activeFilter) {
            return false;
          }

          if (_districtFilter != null &&
              user.district.trim().toLowerCase() !=
                  _districtFilter!.trim().toLowerCase()) {
            return false;
          }

          if (query.isEmpty) {
            return true;
          }

          final haystack = [
            user.fullName,
            user.email,
            user.role.label,
            user.role.value,
            user.district,
          ].join(' ').toLowerCase();

          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  List<String> _districtsFor(List<AppUser> users) {
    final districts =
        users
            .map((user) => user.district.trim())
            .where((district) => district.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return districts;
  }

  bool get _hasActiveFilters {
    return _searchTerm.trim().isNotEmpty ||
        _roleFilter != null ||
        _activeFilter != null ||
        _districtFilter != null;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchTerm = '';
      _roleFilter = null;
      _activeFilter = null;
      _districtFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Users',
      body: FutureBuilder<AppUser>(
        future: _currentProfileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingIndicator(message: 'Checking access');
          }

          if (snapshot.hasError || snapshot.data == null) {
            return _AdminAccessError(
              message: _accessErrorMessage(snapshot.error),
              onRetry: () {
                setState(() {
                  _currentProfileFuture = _authService
                      .fetchCurrentUserProfile();
                });
              },
            );
          }

          final currentProfile = snapshot.data!;
          if (currentProfile.role != UserRole.administrator) {
            return const _AdminAccessDenied();
          }

          return StreamBuilder<List<AppUser>>(
            stream: _usersRepository.watchQuery(
              _usersRepository.allUsers(limit: 200),
            ),
            builder: (context, usersSnapshot) {
              if (usersSnapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingIndicator(message: 'Loading users');
              }

              if (usersSnapshot.hasError) {
                return _AdminAccessError(
                  message: 'Unable to load users.',
                  onRetry: () => setState(() {}),
                );
              }

              final allUsers = usersSnapshot.data ?? const <AppUser>[];
              final users = _filteredUsers(allUsers);
              final districts = _districtsFor(allUsers);

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
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => _openUserForm(),
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('Add user'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _UserFilters(
                          searchController: _searchController,
                          searchTerm: _searchTerm,
                          roleFilter: _roleFilter,
                          activeFilter: _activeFilter,
                          districtFilter: _districtFilter,
                          districts: districts,
                          hasActiveFilters: _hasActiveFilters,
                          onSearchChanged: (value) {
                            setState(() => _searchTerm = value);
                          },
                          onRoleChanged: (role) {
                            setState(() => _roleFilter = role);
                          },
                          onActiveChanged: (isActive) {
                            setState(() => _activeFilter = isActive);
                          },
                          onDistrictChanged: (district) {
                            setState(() => _districtFilter = district);
                          },
                          onClear: _clearFilters,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _hasActiveFilters
                              ? '${users.length} of ${allUsers.length} user${allUsers.length == 1 ? '' : 's'}'
                              : '${users.length} user${users.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (users.isEmpty)
                          _EmptyUsers(hasActiveFilters: _hasActiveFilters)
                        else
                          ...users.map(
                            (user) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _UserCard(
                                user: user,
                                isCurrentUser: user.uid == currentProfile.uid,
                                onEdit: () => _openUserForm(user: user),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _accessErrorMessage(Object? error) {
    if (error is AuthFailure) {
      return error.message;
    }

    return 'Unable to check your administrator access.';
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.onEdit,
  });

  final AppUser user;
  final bool isCurrentUser;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserAvatar(user: user),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.fullName.trim().isEmpty
                                ? user.email
                                : user.fullName,
                            style: textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentUser)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.verified_user_outlined,
                              color: AppColors.primaryGreen,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: user.isActive
                              ? Icons.check_circle_outline
                              : Icons.block_outlined,
                          label: user.isActive ? 'Active' : 'Inactive',
                        ),
                        _InfoChip(
                          icon: Icons.badge_outlined,
                          label: user.role.label,
                        ),
                        _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: user.district.trim().isEmpty
                              ? 'No district'
                              : user.district,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Edit user',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserFilters extends StatelessWidget {
  const _UserFilters({
    required this.searchController,
    required this.searchTerm,
    required this.roleFilter,
    required this.activeFilter,
    required this.districtFilter,
    required this.districts,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onActiveChanged,
    required this.onDistrictChanged,
    required this.onClear,
  });

  static const _allValue = '__all__';

  final TextEditingController searchController;
  final String searchTerm;
  final UserRole? roleFilter;
  final bool? activeFilter;
  final String? districtFilter;
  final List<String> districts;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<UserRole?> onRoleChanged;
  final ValueChanged<bool?> onActiveChanged;
  final ValueChanged<String?> onDistrictChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final roleValue = roleFilter?.value ?? _allValue;
    final statusValue = activeFilter == null
        ? _allValue
        : activeFilter!
        ? 'active'
        : 'inactive';
    final districtValue =
        districtFilter != null && districts.contains(districtFilter)
        ? districtFilter!
        : _allValue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final fieldWidth = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: constraints.maxWidth,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Search users',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchTerm.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('role-filter-$roleValue'),
                    initialValue: roleValue,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: _allValue,
                        child: Text('All roles'),
                      ),
                      ...UserRole.values
                          .where((role) => role != UserRole.unknown)
                          .map(
                            (role) => DropdownMenuItem<String>(
                              value: role.value,
                              child: Text(role.label),
                            ),
                          ),
                    ],
                    onChanged: (value) {
                      if (value == null || value == _allValue) {
                        onRoleChanged(null);
                        return;
                      }

                      onRoleChanged(UserRole.fromValue(value));
                    },
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('status-filter-$statusValue'),
                    initialValue: statusValue,
                    decoration: const InputDecoration(
                      labelText: 'Account status',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: _allValue,
                        child: Text('All users'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'active',
                        child: Text('Active only'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'inactive',
                        child: Text('Inactive only'),
                      ),
                    ],
                    onChanged: (value) {
                      onActiveChanged(switch (value) {
                        'active' => true,
                        'inactive' => false,
                        _ => null,
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('district-filter-$districtValue'),
                    initialValue: districtValue,
                    decoration: const InputDecoration(
                      labelText: 'District',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: _allValue,
                        child: Text('All districts'),
                      ),
                      ...districts.map(
                        (district) => DropdownMenuItem<String>(
                          value: district,
                          child: Text(district),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      onDistrictChanged(
                        value == null || value == _allValue ? null : value,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: compact ? constraints.maxWidth : fieldWidth,
                  child: OutlinedButton.icon(
                    onPressed: hasActiveFilters ? onClear : null,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear filters'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final imageUrl = user.profileImage?.trim() ?? '';
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return ClipOval(
        child: SizedBox(
          width: 46,
          height: 46,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _InitialsAvatar(
                initials: _initials(user.fullName, user.email),
              );
            },
          ),
        ),
      );
    }

    return _InitialsAvatar(initials: _initials(user.fullName, user.email));
  }

  static String _initials(String name, String email) {
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
      radius: 23,
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
      child: Text(initials),
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

class _EmptyUsers extends StatelessWidget {
  const _EmptyUsers({required this.hasActiveFilters});

  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.manage_accounts_outlined,
              color: AppColors.mutedInk,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              hasActiveFilters
                  ? 'No users match these filters.'
                  : 'No users have been added yet.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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

class _AdminAccessError extends StatelessWidget {
  const _AdminAccessError({required this.message, required this.onRetry});

  final String message;
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
              message,
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
