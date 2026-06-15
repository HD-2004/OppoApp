import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  test('mobile role parser resolves every backend role as candidate', () {
    expect(AppRole.values, const [AppRole.candidate]);
    expect(AppRoleParser.fromCognitoValue(null), AppRole.candidate);
    expect(AppRoleParser.fromCognitoValue(''), AppRole.candidate);
    expect(AppRoleParser.fromCognitoValue('user'), AppRole.candidate);
    expect(AppRoleParser.fromCognitoValue('candidate'), AppRole.candidate);
    expect(AppRoleParser.fromCognitoValue('employer'), AppRole.candidate);
    expect(AppRoleParser.fromCognitoValue('admin'), AppRole.candidate);
  });
}
