import 'package:flutter/foundation.dart';

// Region và User Pool ID có thể override qua --dart-define nếu cần đổi
// environment (staging/production). Default là giá trị production hiện tại.
const cognitoRegion = String.fromEnvironment(
  'COGNITO_REGION',
  defaultValue: 'ap-southeast-1',
);
const cognitoUserPoolId = String.fromEnvironment(
  'COGNITO_USER_POOL_ID',
  defaultValue: 'ap-southeast-1_ShCajkmJd',
);
const cognitoUserPoolName = 'OpPoWebUserPool';
const cognitoEndpoint =
    'https://cognito-idp.$cognitoRegion.amazonaws.com/$cognitoUserPoolId';
const cognitoJwksUrl = '$cognitoEndpoint/.well-known/jwks.json';

// This User Pool currently does not define custom:role. Keep this false until
// custom attribute `role` is created and the App Client can read/write it.
const useCognitoCustomRoleAttribute = false;

// App Client IDs are public identifiers. Mobile apps must not use client
// secrets.
// ── Web client (OpPoWebClient) ──
const _cognitoWebClientId = String.fromEnvironment(
  'COGNITO_WEB_CLIENT_ID',
  defaultValue: '2mv7qt4gpmq03dmlm0or9724n8',
);
// ── Android client (OpPoAppClient) ──
const _cognitoAndroidClientId = String.fromEnvironment(
  'COGNITO_ANDROID_CLIENT_ID',
  defaultValue: '6o6jofrs8m69ls9rq4n9pvn9cl',
);
// Resolved at runtime based on platform.
String get cognitoUserPoolClientId =>
    kIsWeb ? _cognitoWebClientId : _cognitoAndroidClientId;

// ── Hosted UI / OAuth (Google sign-in) ──────────────────────────────────────
// Google federated sign-in goes through the SAME Cognito Hosted UI that the
// website already uses. The mobile app only needs to point at that Hosted UI
// domain and use an app-owned redirect URI that is also registered on the
// Cognito App Client's Allowed callback/sign-out URLs.
//
// The Hosted UI domain is a real, account-specific value. It is NOT hardcoded
// here; pass it at build/run time so we never ship a fabricated value:
//   --dart-define=COGNITO_HOSTED_UI_DOMAIN=your-domain.auth.ap-southeast-1.amazoncognito.com
// Provide the bare domain (no scheme, no path).
const cognitoHostedUiDomain = String.fromEnvironment(
  'COGNITO_HOSTED_UI_DOMAIN',
  defaultValue: 'opporeview.auth.ap-southeast-1.amazoncognito.com',
);

// Web deployments must redirect back to the HTTPS origin that hosts Flutter
// Web. For GitHub Pages this should be:
//   https://<owner>.github.io/<repo>/
// Native mobile keeps using the app-owned custom scheme below.
const cognitoWebRedirectUri = String.fromEnvironment(
  'COGNITO_WEB_REDIRECT_URI',
  defaultValue: '',
);

// App-owned redirect URI.
// - Web: detected from Uri.base or overridden via --dart-define.
// - Android: uses the HTTPS redirect URI registered on OpPoAppClient
//   (https://hd-2004.github.io/OppoApp/). This requires App Links
//   (Digital Asset Links) to be verified so Android routes the redirect
//   back to the app.
const cognitoAndroidRedirectUri = String.fromEnvironment(
  'COGNITO_ANDROID_REDIRECT_URI',
  defaultValue: 'https://hd-2004.github.io/OppoApp/',
);

// Legacy custom scheme kept for reference / fallback.
const cognitoRedirectScheme = String.fromEnvironment(
  'COGNITO_REDIRECT_SCHEME',
  defaultValue: 'com.oppo.tempjobs',
);

String get cognitoSignInRedirectUri => resolveCognitoRedirectUri(
  isWeb: kIsWeb,
  webRedirectUri: cognitoWebRedirectUri,
  androidRedirectUri: cognitoAndroidRedirectUri,
);

String get cognitoSignOutRedirectUri => cognitoSignInRedirectUri;

String resolveCognitoRedirectUri({
  required bool isWeb,
  required String androidRedirectUri,
  String? webRedirectUri,
  Uri? baseUri,
}) {
  if (!isWeb) {
    // Android: use the HTTPS redirect URI registered on OpPoAppClient.
    return androidRedirectUri;
  }

  final configuredUri = _normalizeWebRedirectUri(webRedirectUri);
  if (configuredUri != null) {
    return configuredUri;
  }

  final currentUri = baseUri ?? Uri.base;
  final basePath = _webBasePath(currentUri.path);
  return _normalizeWebRedirectUri('${currentUri.origin}$basePath') ??
      '${currentUri.origin}/';
}

String _webBasePath(String path) {
  if (path.isEmpty || path == '/') {
    return '/';
  }
  if (path.endsWith('/')) {
    return path;
  }

  final lastSegment = path.split('/').last;
  if (lastSegment.contains('.')) {
    return path.replaceFirst(RegExp(r'[^/]*$'), '');
  }
  return '$path/';
}

String? _normalizeWebRedirectUri(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text.endsWith('/') ? text : '$text/';
}

// Social sign-in (Hosted UI) can only be configured when we actually know the
// Hosted UI domain. Without it, Amplify would fail at signInWithWebUI time.
bool get hasHostedUiConfig => cognitoHostedUiDomain.trim().isNotEmpty;

bool get hasCognitoAppClientId {
  final id = cognitoUserPoolClientId;
  return id.trim().isNotEmpty &&
      id != 'REPLACE_WITH_COGNITO_APP_CLIENT_ID';
}

/// Kiểm tra User Pool ID có đúng format Cognito hay không.
/// Format hợp lệ: <region>_<alphanumeric>, vd: ap-southeast-1_ShCajkmJd
bool get hasCognitoUserPoolId {
  final id = cognitoUserPoolId.trim();
  if (id.isEmpty) return false;
  // Cognito User Pool ID luôn có dạng: region_id
  return RegExp(r'^[a-z]{2}-[a-z]+-\d+_\w+$').hasMatch(id);
}

/// Kiểm tra Region có đúng format AWS hay không.
bool get hasCognitoRegion {
  final region = cognitoRegion.trim();
  if (region.isEmpty) return false;
  return RegExp(r'^[a-z]{2}-[a-z]+-\d+$').hasMatch(region);
}

void logAmplifyConfigForDebug() {
  if (!kDebugMode) {
    return;
  }

  debugPrint('Amplify Auth config: region=$cognitoRegion (valid=$hasCognitoRegion)');
  debugPrint('Amplify Auth config: userPoolId=$cognitoUserPoolId (valid=$hasCognitoUserPoolId)');
  debugPrint('Amplify Auth config: endpoint=$cognitoEndpoint');
  debugPrint('Amplify Auth config: hasAppClientId=$hasCognitoAppClientId');
  debugPrint('Amplify Auth config: hasHostedUiConfig=$hasHostedUiConfig');
  debugPrint(
    'Amplify Auth config: useCustomRole=$useCognitoCustomRoleAttribute',
  );
}

// OAuth block is only emitted when a real Hosted UI domain is supplied, so we
// never ship a fabricated domain. When present, it mirrors the website's
// Hosted UI: Google as a supported provider, authorization code flow, and the
// app-owned redirect URIs.
String get _oauthBlock {
  if (!hasHostedUiConfig) {
    return '';
  }

  return '''
,
            "OAuth": {
              "WebDomain": "$cognitoHostedUiDomain",
              "AppClientId": "$cognitoUserPoolClientId",
              "SignInRedirectURI": "$cognitoSignInRedirectUri",
              "SignOutRedirectURI": "$cognitoSignOutRedirectUri",
              "Scopes": ["openid", "email", "profile", "aws.cognito.signin.user.admin"]
            }''';
}

String get _socialProviders => hasHostedUiConfig ? '"GOOGLE"' : '';

String get amplifyconfig =>
    '''
{
  "UserAgent": "aws-amplify-flutter/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "IdentityManager": {
          "Default": {}
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "$cognitoUserPoolId",
            "AppClientId": "$cognitoUserPoolClientId",
            "Region": "$cognitoRegion"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH",
            "socialProviders": [$_socialProviders],
            "usernameAttributes": ["EMAIL"],
            "signupAttributes": ["EMAIL"],
            "passwordProtectionSettings": {
              "passwordPolicyMinLength": 8,
              "passwordPolicyCharacters": [
                "REQUIRES_LOWERCASE",
                "REQUIRES_UPPERCASE",
                "REQUIRES_NUMBERS",
                "REQUIRES_SYMBOLS"
              ]
            },
            "mfaConfiguration": "OFF",
            "mfaTypes": [],
            "verificationMechanisms": ["EMAIL"]$_oauthBlock
          }
        }
      }
    }
  }
}
''';
