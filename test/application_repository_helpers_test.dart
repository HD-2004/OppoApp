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

  test(
    'builds AI interview continuation for accepted existing application',
    () {
      final continuation = aiInterviewContinuationForExistingApplication(
        applications: const [
          {
            'applicationId': 'app-ai',
            'jobId': 'job-ai',
            'status': 'accepted',
            'cvUrl': 'https://example.com/accepted-cv.pdf',
            'cvFilename': 'accepted-cv.pdf',
            'aiScreeningScore': 82,
            'aiScreeningResult': 'pass',
            'aiScreeningReason': 'CV đã được chấp nhận.',
          },
        ],
        jobId: 'job-ai',
        selectedCvUrl: 'https://example.com/selected.pdf',
        selectedCvFilename: 'selected.pdf',
      );

      expect(continuation, isNotNull);
      expect(continuation?.applicationId, 'app-ai');
      expect(continuation?.cvUrl, 'https://example.com/accepted-cv.pdf');
      expect(continuation?.cvFilename, 'accepted-cv.pdf');
      expect(continuation?.aiScreeningScore, 82);
      expect(continuation?.aiScreeningResult, 'pass');
    },
  );

  test('accepted application continues when the job AI flag is enabled', () {
    final continuation = aiInterviewContinuationForExistingApplication(
      applications: const [
        {
          'applicationId': 'app-web-ai',
          'jobId': 'job-web-ai',
          'status': 'cvAccepted',
        },
      ],
      jobId: 'job-web-ai',
      selectedCvUrl: 'https://example.com/selected.pdf',
      selectedCvFilename: 'selected.pdf',
      jobRequiresAiInterview: true,
    );

    expect(continuation?.applicationId, 'app-web-ai');
    expect(continuation?.aiScreeningResult, 'pass');
  });

  test('plain accepted application does not assume AI by default', () {
    final continuation = aiInterviewContinuationForExistingApplication(
      applications: const [
        {
          'applicationId': 'app-default-non-ai',
          'jobId': 'job-default-non-ai',
          'status': 'accepted',
        },
      ],
      jobId: 'job-default-non-ai',
      selectedCvUrl: 'https://example.com/selected.pdf',
      selectedCvFilename: 'selected.pdf',
    );

    expect(continuation, isNull);
  });

  test('plain accepted application does not continue when job is non-AI', () {
    final continuation = aiInterviewContinuationForExistingApplication(
      applications: const [
        {
          'applicationId': 'app-non-ai',
          'jobId': 'job-non-ai',
          'status': 'accepted',
        },
      ],
      jobId: 'job-non-ai',
      selectedCvUrl: 'https://example.com/selected.pdf',
      selectedCvFilename: 'selected.pdf',
      jobRequiresAiInterview: false,
    );

    expect(continuation, isNull);
  });

  test('application AI evidence continues even when job flag is missing', () {
    final continuation = aiInterviewContinuationForExistingApplication(
      applications: const [
        {
          'applicationId': 'app-ai-evidence',
          'jobId': 'job-ai-evidence',
          'status': 'accepted',
          'requiresAiInterview': true,
        },
      ],
      jobId: 'job-ai-evidence',
      selectedCvUrl: 'https://example.com/selected.pdf',
      selectedCvFilename: 'selected.pdf',
      jobRequiresAiInterview: false,
    );

    expect(continuation?.applicationId, 'app-ai-evidence');
  });

  test(
    'approved application continues AI interview when report is missing',
    () {
      final continuation = aiInterviewContinuationForExistingApplication(
        applications: const [
          {
            'applicationId': 'app-approved',
            'jobId': 'job-ai',
            'status': 'approved',
            'aiScreeningResult': 'pass',
          },
        ],
        jobId: 'job-ai',
        selectedCvUrl: 'https://example.com/selected.pdf',
        selectedCvFilename: 'selected.pdf',
      );

      expect(continuation?.applicationId, 'app-approved');
      expect(continuation?.aiScreeningResult, 'pass');
    },
  );

  test(
    'pending standard application does not continue AI interview when pending employer approval',
    () {
      final continuation = aiInterviewContinuationForExistingApplication(
        applications: const [
          {
            'applicationId': 'app-pending',
            'jobId': 'job-ai',
            'status': 'pending',
          },
        ],
        jobId: 'job-ai',
        selectedCvUrl: 'https://example.com/selected.pdf',
        selectedCvFilename: 'selected.pdf',
        jobRequiresAiInterview: true,
      );

      expect(continuation, isNull);
    },
  );

  test(
    'statusless standard application does not continue AI interview when pending employer approval',
    () {
      final continuation = aiInterviewContinuationForExistingApplication(
        applications: const [
          {'applicationId': 'app-statusless', 'jobId': 'job-ai'},
        ],
        jobId: 'job-ai',
        selectedCvUrl: 'https://example.com/selected.pdf',
        selectedCvFilename: 'selected.pdf',
        jobRequiresAiInterview: true,
      );

      expect(continuation, isNull);
    },
  );

  test('approved application does not continue after AI interview report', () {
    final continuation = aiInterviewContinuationForExistingApplication(
      applications: const [
        {
          'applicationId': 'app-approved-done',
          'jobId': 'job-ai',
          'status': 'approved',
          'aiScreeningResult': 'pass',
          'aiInterviewScore': 72,
          'aiInterviewReport': {'total_score': 72},
        },
      ],
      jobId: 'job-ai',
      selectedCvUrl: 'https://example.com/selected.pdf',
      selectedCvFilename: 'selected.pdf',
    );

    expect(continuation, isNull);
  });
}
