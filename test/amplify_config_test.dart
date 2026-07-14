import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/config/amplify_config.dart';

void main() {
  group('Cognito OAuth redirect URI resolution', () {
    test('uses the HTTPS redirect URI for native (Android) builds', () {
      final uri = resolveCognitoRedirectUri(
        isWeb: false,
        androidRedirectUri: 'https://hd-2004.github.io/OppoApp/',
      );

      expect(uri, 'https://hd-2004.github.io/OppoApp/');
    });

    test('uses the configured HTTPS redirect for web builds', () {
      final uri = resolveCognitoRedirectUri(
        isWeb: true,
        webRedirectUri: 'https://hd-2004.github.io/OppoApp',
        androidRedirectUri: 'https://hd-2004.github.io/OppoApp/',
      );

      expect(uri, 'https://hd-2004.github.io/OppoApp/');
    });

    test(
      'derives the current base URL for web when no override is supplied',
      () {
        final uri = resolveCognitoRedirectUri(
          isWeb: true,
          baseUri: Uri.parse('https://hd-2004.github.io/OppoApp/#/login'),
          androidRedirectUri: 'https://hd-2004.github.io/OppoApp/',
        );

        expect(uri, 'https://hd-2004.github.io/OppoApp/');
      },
    );

    test('keeps the app path when the web URL has no trailing slash', () {
      final uri = resolveCognitoRedirectUri(
        isWeb: true,
        baseUri: Uri.parse('https://hd-2004.github.io/OppoApp'),
        androidRedirectUri: 'https://hd-2004.github.io/OppoApp/',
      );

      expect(uri, 'https://hd-2004.github.io/OppoApp/');
    });
  });
}
