enum UserRole {
  administrator('administrator', 'Administrator'),
  projectManager('project_manager', 'Project Manager'),
  siteEngineer('site_engineer', 'Site Engineer'),
  contractor('contractor', 'Contractor'),
  consultant('consultant', 'Consultant'),
  clerkOfWorks('clerk_of_works', 'Clerk of Works'),
  districtEngineer('district_engineer', 'District Engineer'),
  procurementOfficer('procurement_officer', 'Procurement Officer'),
  communityRepresentative(
    'community_representative',
    'Community Representative',
  ),
  environmentOfficer('environment_officer', 'Environment Officer'),
  communityDevelopmentOfficer(
    'community_development_officer',
    'Community Development Officer (CDO)',
  ),
  unknown('unknown', 'Role not assigned');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  static UserRole fromValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return UserRole.unknown;
    }

    final normalized = _normalize(value);

    if (normalized == 'cdo' ||
        normalized == 'community_development_officer_cdo') {
      return UserRole.communityDevelopmentOfficer;
    }

    for (final role in UserRole.values) {
      if (role.value == normalized || _normalize(role.label) == normalized) {
        return role;
      }
    }

    return UserRole.unknown;
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
