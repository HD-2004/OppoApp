import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/config/api_config.dart';

void main() {
  test('local web keeps AWS URLs when local API proxy is disabled', () {
    const profileUrl =
        'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod/profile/user-1';
    const applicationsUrl =
        'https://l1636ie205.execute-api.ap-southeast-1.amazonaws.com/applications/applications/candidate/user-1';

    expect(
      resolveUrlForEnvironment(
        profileUrl,
        localWeb: true,
        localApiProxyEnabled: false,
      ),
      profileUrl,
    );
    expect(
      resolveUrlForEnvironment(
        applicationsUrl,
        localWeb: true,
        localApiProxyEnabled: false,
      ),
      applicationsUrl,
    );
  });

  test('local web rewrites AWS URLs when local API proxy is enabled', () {
    const profileUrl =
        'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod/profile/user-1';
    const applicationsUrl =
        'https://l1636ie205.execute-api.ap-southeast-1.amazonaws.com/applications/applications/candidate/user-1';

    expect(
      resolveUrlForEnvironment(
        profileUrl,
        localWeb: true,
        localApiProxyEnabled: true,
      ),
      'http://localhost:3000/api-profile/profile/user-1',
    );
    expect(
      resolveUrlForEnvironment(
        applicationsUrl,
        localWeb: true,
        localApiProxyEnabled: true,
      ),
      'http://localhost:3000/api-applications/applications/candidate/user-1',
    );
  });

  test('non-web environments never rewrite API URLs', () {
    const url =
        'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod/profile/user-1';

    expect(
      resolveUrlForEnvironment(
        url,
        localWeb: false,
        localApiProxyEnabled: true,
      ),
      url,
    );
  });
}
