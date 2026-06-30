import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../../../core/config/amplify_config.dart';
import '../../../core/errors/auth_exception_mapper.dart';
import '../../../core/errors/auth_failure.dart';
import '../../../shared/domain/app_role.dart';
import '../domain/auth_user_profile.dart';

class AuthService {
  Future<void> configureAmplify() async {
    logAmplifyConfigForDebug();

    if (Amplify.isConfigured) {
      safePrint('Amplify Auth already configured.');
      return;
    }

    if (!hasCognitoAppClientId) {
      safePrint('Amplify Auth skipped: missing Cognito App Client ID.');
      return;
    }

    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(amplifyconfig);
      safePrint('Amplify Auth configured for $cognitoUserPoolId.');
    } on AmplifyAlreadyConfiguredException {
      return;
    } on Exception catch (error) {
      safePrint('Amplify Auth configuration failed: $error');
      throw AuthFailure.configuration;
    }
  }

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    required String dateOfBirth,
  }) async {
    await _ensureConfigured();

    try {
      final userAttributes = <AuthUserAttributeKey, String>{
        AuthUserAttributeKey.email: email.trim(),
        AuthUserAttributeKey.name: fullName.trim(),
        AuthUserAttributeKey.birthdate: dateOfBirth.trim(),
        if (useCognitoCustomRoleAttribute)
          const CognitoUserAttributeKey.custom('role'): role,
      };

      return await Amplify.Auth.signUp(
        username: email.trim(),
        password: password,
        options: SignUpOptions(
          userAttributes: userAttributes,
          pluginOptions: CognitoSignUpPluginOptions(
            clientMetadata: {'role': role},
          ),
        ),
      );
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<SignUpResult> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    await _ensureConfigured();

    try {
      return await Amplify.Auth.confirmSignUp(
        username: email.trim(),
        confirmationCode: confirmationCode.trim(),
      );
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    await _ensureConfigured();

    try {
      final existingSession = await Amplify.Auth.fetchAuthSession();
      if (existingSession.isSignedIn) {
        await Amplify.Auth.signOut();
      }

      return await Amplify.Auth.signIn(
        username: email.trim(),
        password: password,
      );
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<SignInResult> signInWithSocialProvider({
    required AuthProvider provider,
  }) async {
    await _ensureConfigured();

    if (!hasHostedUiConfig) {
      throw AuthFailure.socialSignInConfiguration;
    }

    try {
      final existingSession = await Amplify.Auth.fetchAuthSession();
      if (existingSession.isSignedIn) {
        await Amplify.Auth.signOut();
      }

      return await Amplify.Auth.signInWithWebUI(provider: provider);
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<void> signOut() async {
    await _ensureConfigured();
    await Amplify.Auth.signOut();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _ensureConfigured();

    try {
      await Amplify.Auth.updatePassword(
        oldPassword: currentPassword,
        newPassword: newPassword,
      );
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<AuthUser?> getCurrentUser() async {
    await _ensureConfigured();

    try {
      return await Amplify.Auth.getCurrentUser();
    } on SignedOutException {
      return null;
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<AuthSession> fetchAuthSession() async {
    await _ensureConfigured();

    try {
      return await Amplify.Auth.fetchAuthSession();
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<AuthSession> checkAuthSession() {
    return fetchAuthSession();
  }

  Future<List<AuthUserAttribute>> fetchUserAttributes() async {
    await _ensureConfigured();

    try {
      return await Amplify.Auth.fetchUserAttributes();
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<AppRole?> fetchUserRole() async {
    await _ensureConfigured();

    final roleFromAttributes = await _fetchRoleFromUserAttributes();
    if (roleFromAttributes != null) {
      return roleFromAttributes;
    }

    return await _fetchRoleFromCognitoGroups() ?? AppRole.candidate;
  }

  Future<void> resetPassword({required String email}) async {
    await _ensureConfigured();

    try {
      await Amplify.Auth.resetPassword(username: email.trim());
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<void> confirmResetPassword({
    required String email,
    required String confirmationCode,
    required String newPassword,
  }) async {
    await _ensureConfigured();

    try {
      await Amplify.Auth.confirmResetPassword(
        username: email.trim(),
        confirmationCode: confirmationCode.trim(),
        newPassword: newPassword,
      );
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<ResendSignUpCodeResult> resendSignUpCode({
    required String email,
  }) async {
    await _ensureConfigured();

    try {
      return await Amplify.Auth.resendSignUpCode(username: email.trim());
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<AuthUserProfile?> fetchCurrentProfile() async {
    final user = await getCurrentUser();
    if (user == null) {
      return null;
    }

    final role = await fetchUserRole();
    final attributes = await fetchUserAttributes();
    String email = '';
    String fullName = '';
    String? dateOfBirth;
    for (final attribute in attributes) {
      if (attribute.userAttributeKey.key == 'email') {
        email = attribute.value;
      }
      if (attribute.userAttributeKey.key == 'name') {
        fullName = attribute.value;
      }
      if (attribute.userAttributeKey.key == 'birthdate') {
        dateOfBirth = attribute.value;
      }
    }

    return AuthUserProfile(
      userId: user.userId,
      username: user.username,
      role: role,
      email: email,
      fullName: fullName,
      kycCompleted: false,
      profileCompleted: false,
      dateOfBirth: dateOfBirth,
    );
  }

  String routeAfterLogin(AuthUserProfile profile) {
    return '/candidate';
  }

  Future<AppRole?> _fetchRoleFromUserAttributes() async {
    if (!useCognitoCustomRoleAttribute) {
      return null;
    }

    final attributes = await fetchUserAttributes();
    for (final attribute in attributes) {
      if (attribute.userAttributeKey.key == 'custom:role' ||
          attribute.userAttributeKey.key == 'role') {
        return AppRoleParser.fromCognitoValue(attribute.value);
      }
    }

    return null;
  }

  Future<AppRole?> _fetchRoleFromCognitoGroups() async {
    try {
      final cognitoPlugin = Amplify.Auth.getPlugin(
        AmplifyAuthCognito.pluginKey,
      );
      final session = await cognitoPlugin.fetchAuthSession();
      final tokens = session.userPoolTokensResult.valueOrNull;
      final groups = tokens?.accessToken.groups ?? const <String>[];

      for (final group in groups) {
        return AppRoleParser.fromCognitoValue(group);
      }

      return null;
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<void> _ensureConfigured() async {
    if (!hasCognitoAppClientId) {
      throw AuthFailure.configuration;
    }

    await configureAmplify();

    if (!Amplify.isConfigured) {
      throw AuthFailure.configuration;
    }
  }

  AuthFailure _mapAuthError(Exception error) {
    return AuthExceptionMapper.map(error);
  }
}
