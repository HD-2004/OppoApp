import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/amplify_config.dart';
import '../../../core/errors/auth_exception_mapper.dart';
import '../../../core/errors/auth_failure.dart';
import '../../../shared/domain/app_role.dart';
import '../domain/auth_user_profile.dart';

class AuthService {
  Future<void> configureAmplify() async {
    if (Amplify.isConfigured) {
      return;
    }

    logAmplifyConfigForDebug();

    if (!hasCognitoAppClientId || !hasCognitoUserPoolId || !hasCognitoRegion) {
      safePrint(
        'Amplify Auth skipped: thiếu config.\n'
        '  region valid: $hasCognitoRegion ($cognitoRegion)\n'
        '  poolId valid: $hasCognitoUserPoolId ($cognitoUserPoolId)\n'
        '  clientId valid: $hasCognitoAppClientId',
      );
      // Don't throw here — treat missing config as unconfigured,
      // _ensureConfigured() will catch Amplify.isConfigured == false.
      return;
    }

    safePrint(
      '[AuthService] configureAmplify: '
      'poolId=$cognitoUserPoolId '
      'clientId=$cognitoUserPoolClientId '
      'region=$cognitoRegion '
      'hostedUiDomain=$cognitoHostedUiDomain '
      'redirectUri=$cognitoSignInRedirectUri',
    );

    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(amplifyconfig);
      safePrint('[AuthService] configureAmplify: success.');
    } on AmplifyAlreadyConfiguredException {
      return;
    } on Exception catch (error) {
      safePrint(
        '[AuthService] configureAmplify FAILED: $error\n'
        'userPoolId=$cognitoUserPoolId '
        'clientId=$cognitoUserPoolClientId '
        'region=$cognitoRegion',
      );
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
      safePrint(
        '[AuthService] signInWithSocialProvider: no Hosted UI domain configured.',
      );
      throw AuthFailure.socialSignInConfiguration;
    }

    safePrint(
      '[AuthService] signInWithSocialProvider: '
      'provider=$provider '
      'hostedUiDomain=$cognitoHostedUiDomain '
      'redirectUri=$cognitoSignInRedirectUri',
    );

    try {
      final existingSession = await Amplify.Auth.fetchAuthSession();
      if (existingSession.isSignedIn) {
        await Amplify.Auth.signOut();
      }

      // Trên Web: signInWithWebUI() sẽ redirect toàn trang sang Cognito
      // Hosted UI (qua window.open(url, '_self')). Trang sẽ bị unload nên
      // await này không bao giờ complete. Khi Cognito redirect về với ?code=,
      // app load lại và Amplify tự xử lý exchange token trong configure().
      return await Amplify.Auth.signInWithWebUI(provider: provider);
    } on AuthFailure {
      rethrow;
    } on Exception catch (error) {
      // ── Log chi tiết lỗi gốc để debug ──────────────────────────────────
      safePrint(
        '[AuthService] signInWithSocialProvider error '
        'type=${error.runtimeType}: $error',
      );
      if (error is AuthException) {
        safePrint('[AuthService]   .message        = ${error.message}');
        safePrint(
          '[AuthService]   .recoverySuggestion = '
          '${error.recoverySuggestion}',
        );
        safePrint(
          '[AuthService]   .underlyingException = '
          '${error.underlyingException}',
        );
      }
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

  Future<AuthSession> checkAuthSession() async {
    // configureAmplify is idempotent — safe to call here for mobile where
    // Amplify is configured lazily (not eagerly in main() like on web).
    await configureAmplify();
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

    // Try custom attribute first (only when enabled), then fall back to groups
    // decoded directly from the access token — no GetUser API call needed.
    final roleFromAttributes = await _fetchRoleFromUserAttributes();
    if (roleFromAttributes != null) {
      return roleFromAttributes;
    }

    try {
      final cognitoPlugin = Amplify.Auth.getPlugin(
        AmplifyAuthCognito.pluginKey,
      );
      final session = await cognitoPlugin.fetchAuthSession();
      final tokens = session.userPoolTokensResult.valueOrNull;
      final accessClaims = _decodeJwtClaims(tokens?.accessToken.raw ?? '');
      final groups =
          (accessClaims['cognito:groups'] as List<dynamic>?)?.cast<String>() ??
          const <String>[];

      for (final group in groups) {
        return AppRoleParser.fromCognitoValue(group);
      }

      return AppRole.candidate;
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
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
    await _ensureConfigured();

    try {
      final cognitoPlugin = Amplify.Auth.getPlugin(
        AmplifyAuthCognito.pluginKey,
      );
      final session = await cognitoPlugin.fetchAuthSession();

      // Not signed in — no profile to return.
      if (!session.isSignedIn) {
        return null;
      }

      final tokens = session.userPoolTokensResult.valueOrNull;
      if (tokens == null) {
        return null;
      }

      // ── Read everything from the ID token (JWT claims) ──────────────────
      // This avoids calling GetUser API (which needs the
      // aws.cognito.signin.user.admin scope and would 400 if the token was
      // issued before that scope was added or the Cognito console wasn't
      // saved yet).
      final idClaims = _decodeJwtClaims(tokens.idToken.raw);

      final userId = (idClaims['sub'] as String?) ?? '';
      final username =
          (idClaims['cognito:username'] as String?) ??
          (idClaims['email'] as String?) ??
          userId;
      final email = (idClaims['email'] as String?) ?? '';
      final fullName =
          (idClaims['name'] as String?) ??
          (idClaims['given_name'] as String?) ??
          '';
      final dateOfBirth = idClaims['birthdate'] as String?;

      // ── Determine role from access token groups (no extra network call) ──
      final accessClaims = _decodeJwtClaims(tokens.accessToken.raw);
      final groups =
          (accessClaims['cognito:groups'] as List<dynamic>?)?.cast<String>() ??
          const <String>[];

      AppRole role = AppRole.candidate;
      for (final group in groups) {
        role = AppRoleParser.fromCognitoValue(group);
        break;
      }

      if (kDebugMode) {
        safePrint(
          'fetchCurrentProfile: userId=$userId email=$email '
          'role=${role.cognitoValue} groups=$groups',
        );
      }

      return AuthUserProfile(
        userId: userId,
        username: username,
        role: role,
        email: email,
        fullName: fullName,
        kycCompleted: false,
        profileCompleted: false,
        dateOfBirth: dateOfBirth,
      );
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  /// Decode the payload section of a JWT without verifying the signature.
  /// We trust Amplify has already verified the token; we only need the claims.
  static Map<String, dynamic> _decodeJwtClaims(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return {};
      // Base64url → base64 padding
      var payload = parts[1];
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
        case 3:
          payload += '=';
      }
      final decoded = utf8.decode(base64.decode(payload));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String routeAfterLogin(AuthUserProfile profile) {
    return '/candidate';
  }

  Future<AppRole?> _fetchRoleFromUserAttributes() async {
    if (!useCognitoCustomRoleAttribute) {
      return null;
    }

    // fetchUserAttributes() calls GetUser API — only used when the custom
    // attribute feature is explicitly enabled.
    try {
      final attributes = await fetchUserAttributes();
      for (final attribute in attributes) {
        if (attribute.userAttributeKey.key == 'custom:role' ||
            attribute.userAttributeKey.key == 'role') {
          return AppRoleParser.fromCognitoValue(attribute.value);
        }
      }
      return null;
    } on Exception catch (error) {
      throw _mapAuthError(error);
    }
  }

  Future<void> _ensureConfigured() async {
    // Kiểm tra đủ 3 giá trị bắt buộc trước khi gọi Amplify.configure()
    if (!hasCognitoAppClientId || !hasCognitoUserPoolId || !hasCognitoRegion) {
      safePrint(
        '[AuthService] _ensureConfigured: thiếu/sai config → throwing configuration failure.\n'
        '  region: "$cognitoRegion" (valid=$hasCognitoRegion)\n'
        '  poolId: "$cognitoUserPoolId" (valid=$hasCognitoUserPoolId)\n'
        '  clientId: "$cognitoUserPoolClientId" (valid=$hasCognitoAppClientId)',
      );
      throw AuthFailure.configuration;
    }

    await configureAmplify();

    if (!Amplify.isConfigured) {
      safePrint(
        '[AuthService] _ensureConfigured: Amplify still not configured after configureAmplify() → throwing configuration failure.\n'
        '  clientId: "${cognitoUserPoolClientId.substring(0, cognitoUserPoolClientId.length > 10 ? 10 : cognitoUserPoolClientId.length)}..."\n'
        '  region: "$cognitoRegion"\n'
        '  poolId: "$cognitoUserPoolId"',
      );
      throw AuthFailure.configuration;
    }
  }

  AuthFailure _mapAuthError(Exception error) {
    return AuthExceptionMapper.map(error);
  }
}
