import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hash-based URL strategy is kept (Flutter Web default) because GitHub Pages
  // does not support server-side rewrites needed for path strategy.
  // The OAuth redirect URI is always the origin + base path (before the #),
  // e.g. https://hd-2004.github.io/OppoApp/ — which must be registered in Cognito.
  // Amplify is configured lazily on first auth access via AuthService._ensureConfigured().
  runApp(const ProviderScope(child: TempJobsApp()));
}
