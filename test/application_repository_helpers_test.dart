import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/application_repository.dart';

void main() {
  test('detects duplicate application errors from shared API messages', () {
    expect(
      isAlreadyAppliedApplicationError(
        Exception('You have already applied to this job'),
      ),
      isTrue,
    );
    expect(
      isAlreadyAppliedApplicationError(Exception('ALREADY_APPLIED')),
      isTrue,
    );
    expect(
      isAlreadyAppliedApplicationError(Exception('Bạn đã ứng tuyển rồi')),
      isTrue,
    );
    expect(
      isAlreadyAppliedApplicationError(Exception('Network timeout')),
      isFalse,
    );
  });

  test('extracts application id from submit response shapes', () {
    expect(
      applicationIdFromSubmitResponse({'applicationId': 'app-1'}),
      'app-1',
    );
    expect(
      applicationIdFromSubmitResponse({
        'application': {'applicationId': 'app-2'},
      }),
      'app-2',
    );
    expect(applicationIdFromSubmitResponse({'ok': true}), isNull);
  });

  test('finds existing candidate application for a job', () {
    final applications = [
      {'applicationId': 'app-1', 'jobId': 'job-1'},
      {'id': 'app-2', 'idJob': 'job-2'},
      {'applicationId': 'app-3', 'jobID': 'job-3'},
    ];

    expect(existingApplicationIdForJob(applications, 'job-1'), 'app-1');
    expect(existingApplicationIdForJob(applications, 'job-2'), 'app-2');
    expect(existingApplicationIdForJob(applications, 'job-3'), 'app-3');
    expect(existingApplicationIdForJob(applications, 'job-x'), isNull);
  });
}
