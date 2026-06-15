enum AppRole { candidate }

extension AppRoleLabel on AppRole {
  String get label {
    return switch (this) {
      AppRole.candidate => 'Candidate',
    };
  }

  String get cognitoValue {
    return switch (this) {
      AppRole.candidate => 'user',
    };
  }
}

class AppRoleParser {
  const AppRoleParser._();

  static AppRole fromCognitoValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'user' => AppRole.candidate,
      'candidate' => AppRole.candidate,
      _ => AppRole.candidate,
    };
  }
}
