import 'dart:async';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/amplify_config.dart';
import 'features/auth/data/auth_service.dart';

/// Holds the Amplify configuration error (if any) so the UI can display it.
String? amplifyConfigError;

/// Debug info about the actual config values at runtime.
String? amplifyConfigDebugInfo;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hash-based URL strategy is kept (Flutter Web default) because GitHub Pages
  // does not support server-side rewrites needed for path strategy.
  // The OAuth redirect URI is always the origin + base path (before the #),
  // e.g. https://hd-2004.github.io/OppoApp/ — which must be registered in Cognito.

  // ── Eager Amplify configuration on Web ─────────────────────────────────────
  // Amplify MUST be configured before any UI renders on web so that it can
  // capture `initialParameters` (the ?code=&state= in the URL after an OAuth
  // redirect from Cognito Hosted UI). If Amplify is configured lazily (on first
  // auth action), the OAuth callback page load may complete the auth check before
  // Amplify has a chance to exchange the authorization code.
  //
  // On mobile, lazy configuration is fine because the app is never killed by an
  // OAuth redirect (the OS sends a deep link instead).
  if (kIsWeb) {
    // Capture actual runtime config values for debugging
    amplifyConfigDebugInfo =
        'region="$cognitoRegion" (valid=$hasCognitoRegion)\n'
        'poolId="$cognitoUserPoolId" (valid=$hasCognitoUserPoolId)\n'
        'clientId="$cognitoUserPoolClientId" (valid=$hasCognitoAppClientId)\n'
        'hostedUi="$cognitoHostedUiDomain"\n'
        'redirectUri="$cognitoSignInRedirectUri"\n'
        'Amplify.isConfigured=${Amplify.isConfigured}';
    try {
      await AuthService().configureAmplify();
      amplifyConfigDebugInfo =
          '$amplifyConfigDebugInfo\nAfter configure: Amplify.isConfigured=${Amplify.isConfigured}';
    } catch (e, st) {
      // Store error for UI display (console is unavailable in release mode)
      amplifyConfigError =
          'Amplify configure failed: $e\n'
          'stack=${st.toString().split('\n').take(5).join('\n')}';
      amplifyConfigDebugInfo =
          '$amplifyConfigDebugInfo\nEXCEPTION: $e';
    }

    // ── OAuth callback guard ──────────────────────────────────────────────────
    // After Google sign-in, Cognito redirects back with ?code=&state= in the
    // URL. Amplify needs a moment to exchange the authorization code for tokens
    // before the app's auth check runs. Without this delay, authController
    // calls checkAuthSession() while the exchange is still in-flight and gets
    // unauthenticated — causing GoRouter to navigate away and lose the ?code=.
    //
    // We only add the wait when the OAuth callback parameters are present so
    // normal app launches are unaffected.
    final uri = Uri.base;
    final hasOAuthCallback =
        uri.queryParameters.containsKey('code') &&
        uri.queryParameters.containsKey('state');
    if (hasOAuthCallback) {
      safePrint('[main] OAuth callback detected — waiting for token exchange.');
      // Wait for Amplify Hub to emit signedIn (token exchange complete)
      // with a 10 s safety-net timeout so the app never hangs.
      final completer = Completer<void>();
      StreamSubscription<AuthHubEvent>? sub;
      sub = Amplify.Hub.listen(HubChannel.Auth, (AuthHubEvent event) {
        if (event.type == AuthHubEventType.signedIn && !completer.isCompleted) {
          completer.complete();
          sub?.cancel();
        }
      });
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          sub?.cancel();
          safePrint(
            '[main] OAuth token exchange timeout — starting app anyway.',
          );
        },
      );
      safePrint('[main] OAuth token exchange complete — starting app.');
    }
  }

  runApp(const ProviderScope(child: TempJobsApp()));
}
