import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/config/amplify_config.dart';

void main() {
  group('Cognito OAuth redirect URI resolution', () {
    test('uses custom scheme redirect URI for native builds', () {
      final uri = resolveCognitoRedirectUri(
        isWeb: false,
        redirectScheme: 'com.oppo.tempjobs',
      );

      expect(uri, 'com.oppo.tempjobs://');
    });

    test('uses the configured HTTPS redirect for web builds', () {
      final uri = resolveCognitoRedirectUri(
        isWeb: true,
        redirectScheme: 'com.oppo.tempjobs',
        webRedirectUri: 'https://hd-2004.github.io/OppoApp',
      );

      expect(uri, 'https://hd-2004.github.io/OppoApp/');
    });

    test(
      'derives the current base URL for web when no override is supplied',
      () {
        final uri = resolveCognitoRedirectUri(
          isWeb: true,
          redirectScheme: 'com.oppo.tempjobs',
          baseUri: Uri.parse('https://hd-2004.github.io/OppoApp/#/login'),
        );

        expect(uri, 'https://hd-2004.github.io/OppoApp/');
      },
    );

    test('keeps the app path when the web URL has no trailing slash', () {
      final uri = resolveCognitoRedirectUri(
        isWeb: true,
        redirectScheme: 'com.oppo.tempjobs',
        baseUri: Uri.parse('https://hd-2004.github.io/OppoApp'),
      );

      expect(uri, 'https://hd-2004.github.io/OppoApp/');
    });
  });
}
