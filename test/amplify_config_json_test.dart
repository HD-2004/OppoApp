// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// Mirrors the production logic in lib/core/config/amplify_config.dart
/// but uses explicit values to validate the JSON template.
void main() {
  const region = 'ap-southeast-1';
  const userPoolId = 'ap-southeast-1_ShCajkmJd';
  const clientId = '2mv7qt4gpmq03dmlm0or9724n8';
  const hostedUiDomain =
      'opporeview.auth.ap-southeast-1.amazoncognito.com';
  const redirectUri = 'https://hd-2004.github.io/OppoApp/';

  String buildOAuthBlock() {
    if (hostedUiDomain.trim().isEmpty) return '';
    return '''
,
            "OAuth": {
              "WebDomain": "$hostedUiDomain",
              "AppClientId": "$clientId",
              "SignInRedirectURI": "$redirectUri",
              "SignOutRedirectURI": "$redirectUri",
              "Scopes": ["openid", "email", "profile", "aws.cognito.signin.user.admin"]
            }''';
  }

  String buildSocialProviders() =>
      hostedUiDomain.trim().isNotEmpty ? '"GOOGLE"' : '';

  String buildAmplifyConfig() {
    final oauthBlock = buildOAuthBlock();
    final socialProviders = buildSocialProviders();
    return '''
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
            "PoolId": "$userPoolId",
            "AppClientId": "$clientId",
            "Region": "$region"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH",
            "socialProviders": [$socialProviders],
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
            "verificationMechanisms": ["EMAIL"]$oauthBlock
          }
        }
      }
    }
  }
}
''';
  }

  test('amplifyconfig JSON is valid with OAuth block', () {
    final config = buildAmplifyConfig();
    print('=== Generated amplifyconfig JSON ===');
    print(config);
    print('=== END ===');

    // This must not throw
    final decoded = jsonDecode(config) as Map<String, dynamic>;

    // Verify structure
    expect(decoded['auth'], isNotNull);
    final plugins = decoded['auth']['plugins'] as Map<String, dynamic>;
    final cognitoPlugin =
        plugins['awsCognitoAuthPlugin'] as Map<String, dynamic>;
    final userPool =
        cognitoPlugin['CognitoUserPool']['Default'] as Map<String, dynamic>;
    expect(userPool['PoolId'], equals(userPoolId));
    expect(userPool['AppClientId'], equals(clientId));
    expect(userPool['Region'], equals(region));

    final auth = cognitoPlugin['Auth']['Default'] as Map<String, dynamic>;
    expect(auth['OAuth'], isNotNull);
    final oauth = auth['OAuth'] as Map<String, dynamic>;
    expect(oauth['WebDomain'], equals(hostedUiDomain));
    expect(oauth['SignInRedirectURI'], equals(redirectUri));
    expect(oauth['SignOutRedirectURI'], equals(redirectUri));
  });

  test('amplifyconfig JSON is valid without OAuth block (no domain)', () {
    // Simulate empty hosted UI domain
    const emptyDomain = '';
    String oauthBlock() {
      if (emptyDomain.trim().isEmpty) return '';
      return ',\n"OAuth": {}';
    }

    String socialProviders() =>
        emptyDomain.trim().isNotEmpty ? '"GOOGLE"' : '';

    final config = '''
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
            "PoolId": "$userPoolId",
            "AppClientId": "$clientId",
            "Region": "$region"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH",
            "socialProviders": [${socialProviders()}],
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
            "verificationMechanisms": ["EMAIL"]${oauthBlock()}
          }
        }
      }
    }
  }
}
''';
    print('=== Generated amplifyconfig JSON (no OAuth) ===');
    print(config);
    print('=== END ===');

    final decoded = jsonDecode(config) as Map<String, dynamic>;
    final auth = decoded['auth']['plugins']['awsCognitoAuthPlugin']['Auth']
        ['Default'] as Map<String, dynamic>;
    expect(auth.containsKey('OAuth'), isFalse);
  });
}
