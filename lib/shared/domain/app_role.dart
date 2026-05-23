enum AppRole { worker, employer, admin }

extension AppRoleLabel on AppRole {
  String get label {
    return switch (this) {
      AppRole.worker => 'Worker',
      AppRole.employer => 'Employer',
      AppRole.admin => 'Admin',
    };
  }
}
