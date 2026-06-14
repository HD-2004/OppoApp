import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/auth/data/aws_user_profile_repository.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  test(
    'new profile payload uses the Cognito role instead of hardcoding candidate',
    () {
      final payload = buildProfileCreatePayload(
        userId: 'employer-1',
        email: 'owner@example.com',
        fullName: 'Owner',
        role: AppRole.employer,
        createdAt: DateTime.parse('2026-06-14T08:00:00Z'),
      );

      expect(payload['role'], 'employer');
    },
  );

  test('new profile payload keeps missing role explicit', () {
    final payload = buildProfileCreatePayload(
      userId: 'unknown-1',
      email: 'unknown@example.com',
      fullName: 'Unknown',
      role: null,
      createdAt: DateTime.parse('2026-06-14T08:00:00Z'),
    );

    expect(payload.containsKey('role'), isFalse);
  });
}
