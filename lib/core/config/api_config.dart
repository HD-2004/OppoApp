import 'package:flutter/foundation.dart';

const cvAiApiBaseUrl = String.fromEnvironment(
  'CV_AI_API_URL',
  defaultValue:
      'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod',
);

/// Base URL cho API kiểm tra email trùng lặp (dùng chung web + app).
/// API Gateway HTTP API — CheckEmailAPI (ap-southeast-1), stage $default.
const checkEmailApiBaseUrl = String.fromEnvironment(
  'CHECK_EMAIL_API_URL',
  defaultValue: 'https://hwo6w5ngyg.execute-api.ap-southeast-1.amazonaws.com',
);

const useLocalApiProxy = bool.fromEnvironment(
  'USE_LOCAL_API_PROXY',
  defaultValue: false,
);

// Check if we are running in Web mode and on localhost (local development)
bool get isLocalWeb {
  if (!kIsWeb) return false;
  final uri = Uri.base;
  return uri.host == 'localhost' || uri.host == '127.0.0.1';
}

String resolveUrl(String originalUrl) {
  return resolveUrlForEnvironment(
    originalUrl,
    localWeb: isLocalWeb,
    localApiProxyEnabled: useLocalApiProxy,
  );
}

@visibleForTesting
String resolveUrlForEnvironment(
  String originalUrl, {
  required bool localWeb,
  required bool localApiProxyEnabled,
}) {
  if (localWeb && localApiProxyEnabled) {
    // 0. CV AI (Local Python Backend)
    if (originalUrl.contains(
      'sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod/api/v1',
    )) {
      return originalUrl.replaceFirst(
        'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod',
        'http://localhost:8000',
      );
    }
    // 1. Candidate profile / EKYC: sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod
    if (originalUrl.contains(
      'sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod',
    )) {
      return originalUrl.replaceFirst(
        'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod',
        'http://localhost:3000/api-profile',
      );
    }
    // 2. Applications (requires mapping to l1636ie205.execute-api.ap-southeast-1.amazonaws.com/applications)
    if (originalUrl.contains(
      'l1636ie205.execute-api.ap-southeast-1.amazonaws.com/applications',
    )) {
      return originalUrl.replaceFirst(
        'https://l1636ie205.execute-api.ap-southeast-1.amazonaws.com/applications',
        'http://localhost:3000/api-applications',
      );
    }
    if (originalUrl.contains(
      'l1636ie205.execute-api.ap-southeast-1.amazonaws.com',
    )) {
      return originalUrl.replaceFirst(
        'https://l1636ie205.execute-api.ap-southeast-1.amazonaws.com',
        'http://localhost:3000/api-applications',
      );
    }
    // 3. Notifications: iuo7ofruu6.execute-api.ap-southeast-1.amazonaws.com
    if (originalUrl.contains(
      'iuo7ofruu6.execute-api.ap-southeast-1.amazonaws.com',
    )) {
      return originalUrl.replaceFirst(
        'https://iuo7ofruu6.execute-api.ap-southeast-1.amazonaws.com',
        'http://localhost:3000/api-notifications',
      );
    }
    // 4. CV Upload/Delete: v56v542h8f.execute-api.ap-southeast-1.amazonaws.com/prod
    if (originalUrl.contains(
      'v56v542h8f.execute-api.ap-southeast-1.amazonaws.com/prod',
    )) {
      return originalUrl.replaceFirst(
        'https://v56v542h8f.execute-api.ap-southeast-1.amazonaws.com/prod',
        'http://localhost:3000/api-cv',
      );
    }
    // 5. Jobs API: dlidp35x33.execute-api.ap-southeast-1.amazonaws.com/prod
    if (originalUrl.contains(
      'dlidp35x33.execute-api.ap-southeast-1.amazonaws.com/prod',
    )) {
      return originalUrl.replaceFirst(
        'https://dlidp35x33.execute-api.ap-southeast-1.amazonaws.com/prod',
        'http://localhost:3000/api-employer',
      );
    }
    // 6. Candidates list API: xyp4wkszi7.execute-api.ap-southeast-1.amazonaws.com/prod/candidates
    if (originalUrl.contains(
      'xyp4wkszi7.execute-api.ap-southeast-1.amazonaws.com/prod/candidates',
    )) {
      return originalUrl.replaceFirst(
        'https://xyp4wkszi7.execute-api.ap-southeast-1.amazonaws.com/prod/candidates',
        'http://localhost:3000/api',
      );
    }
    if (originalUrl.contains(
      'xyp4wkszi7.execute-api.ap-southeast-1.amazonaws.com/prod',
    )) {
      return originalUrl.replaceFirst(
        'https://xyp4wkszi7.execute-api.ap-southeast-1.amazonaws.com/prod',
        'http://localhost:3000/api',
      );
    }
  }
  return originalUrl;
}
