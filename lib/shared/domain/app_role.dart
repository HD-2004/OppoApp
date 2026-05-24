enum AppRole { candidate, employer, admin }

extension AppRoleLabel on AppRole {
  String get label {
    return switch (this) {
      AppRole.candidate => 'Candidate',
      AppRole.employer => 'Employer',
      AppRole.admin => 'Admin',
    };
  }

  String get cognitoValue {
    return switch (this) {
      AppRole.candidate => 'user',
      AppRole.employer => 'employer',
      AppRole.admin => 'admin',
    };
  }
}

class AppRoleParser {
  const AppRoleParser._();

  static AppRole? fromCognitoValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'user' => AppRole.candidate,
      'candidate' => AppRole.candidate,
      'employer' => AppRole.employer,
      'admin' => AppRole.admin,
      _ => null,
    };
  }
}
