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
