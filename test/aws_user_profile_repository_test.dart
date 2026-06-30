import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/auth/data/aws_user_profile_repository.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  test(
    'new profile payload always stores candidate role in the mobile app',
    () {
      final payload = buildProfileCreatePayload(
        userId: 'user-1',
        email: 'candidate@example.com',
        fullName: 'Candidate',
        role: AppRole.candidate,
        createdAt: DateTime.parse('2026-06-14T08:00:00Z'),
      );

      expect(payload['role'], 'user');
    },
  );

  test('new profile payload defaults missing role to candidate', () {
    final payload = buildProfileCreatePayload(
      userId: 'unknown-1',
      email: 'unknown@example.com',
      fullName: 'Unknown',
      role: null,
      createdAt: DateTime.parse('2026-06-14T08:00:00Z'),
    );

    expect(payload['role'], 'user');
  });

  test('new profile payload stores date of birth when provided', () {
    final payload = buildProfileCreatePayload(
      userId: 'candidate-1',
      email: 'candidate@example.com',
      fullName: 'Candidate',
      role: AppRole.candidate,
      dateOfBirth: '2000-01-05',
      createdAt: DateTime.parse('2026-06-14T08:00:00Z'),
    );

    expect(payload['dateOfBirth'], '2000-01-05');
  });
}
