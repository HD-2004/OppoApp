import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/auth/data/auth_service.dart';

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
    try {
      await AuthService().configureAmplify();
    } catch (_) {
      // Configuration errors are handled later in authControllerProvider.build()
    }
  }

  runApp(const ProviderScope(child: TempJobsApp()));
}
