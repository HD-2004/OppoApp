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
  debugPrint(
    'Amplify Auth config: useCustomRole=$useCognitoCustomRoleAttribute',
  );
}

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
            "socialProviders": [],
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
            "verificationMechanisms": ["EMAIL"]
          }
        }
      }
    }
  }
}
''';
