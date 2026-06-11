import 'package:web/web.dart' as web;

bool get isNetworkOnline => web.window.navigator.onLine;
