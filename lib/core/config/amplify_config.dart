import 'package:flutter/foundation.dart';

const cognitoRegion = 'ap-southeast-1';
const cognitoUserPoolId = 'ap-southeast-1_ShCajkmJd';
const cognitoUserPoolName = 'OpPoWebUserPool';
const cognitoEndpoint =
    'https://cognito-idp.$cognitoRegion.amazonaws.com/$cognitoUserPoolId';
const cognitoJwksUrl = '$cognitoEndpoint/.well-known/jwks.json';

// This User Pool currently does not define custom:role. Keep this false until
// custom attribute `role` is created and the App Client can read/write it.
const useCognitoCustomRoleAttribute = false;

// App Client IDs are public identifiers. Mobile apps must not use client
// secrets. The default below was found read-only in OpPoWebUserPool.
const cognitoUserPoolClientId = String.fromEnvironment(
  'COGNITO_USER_POOL_CLIENT_ID',
  defaultValue: '2mv7qt4gpmq03dmlm0or9724n8',
);

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
  defaultValue: '',
);

// App-owned redirect URI. Derived from the Android applicationId / iOS bundle
// id (com.oppo.tempjobs) so it is a real scheme this app controls. This exact
// value must be added to the Cognito App Client's Allowed callback URLs and
// Allowed sign-out URLs for federated sign-in to return to the app.
const cognitoRedirectScheme = String.fromEnvironment(
  'COGNITO_REDIRECT_SCHEME',
  defaultValue: 'com.oppo.tempjobs',
);

String get cognitoSignInRedirectUri => '$cognitoRedirectScheme://';
String get cognitoSignOutRedirectUri => '$cognitoRedirectScheme://';

// Social sign-in (Hosted UI) can only be configured when we actually know the
// Hosted UI domain. Without it, Amplify would fail at signInWithWebUI time.
bool get hasHostedUiConfig => cognitoHostedUiDomain.trim().isNotEmpty;

bool get hasCognitoAppClientId {
  return cognitoUserPoolClientId.trim().isNotEmpty &&
      cognitoUserPoolClientId != 'REPLACE_WITH_COGNITO_APP_CLIENT_ID';
}

void logAmplifyConfigForDebug() {
  if (!kDebugMode) {
    return;
  }

  debugPrint('Amplify Auth config: region=$cognitoRegion');
  debugPrint('Amplify Auth config: userPoolId=$cognitoUserPoolId');
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

String get _socialProviders => hasHostedUiConfig ? '"Google"' : '';

final amplifyconfig =
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
