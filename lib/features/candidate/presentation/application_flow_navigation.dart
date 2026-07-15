import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_user_profile.dart';
import '../application/ai_interview_providers.dart';
import '../data/aws_application_repository.dart';
import '../domain/application_repository.dart';
import '../domain/job_post.dart';
import 'ai_screening_screen.dart';
import 'ai_interview_chat_screen.dart';

Future<void> openAiApplicationFlow({
  required BuildContext context,
  required WidgetRef ref,
  required JobPost job,
  required AuthUserProfile user,
  required String selectedCvUrl,
  required String selectedCvFilename,
  String? selectedCvS3Key,
}) async {
  // ── 1. Check if candidate already has an application for this job ──
  final applications = await ref
      .read(applicationRepositoryProvider)
      .getCandidateApplications(user.userId);

  final existingApp =
      existingApplicationForJob(applications, job.idJob) ??
      existingApplicationForJob(applications, job.id);

  if (existingApp != null && context.mounted) {
    final status = (existingApp['status']?.toString().trim() ?? '')
        .toLowerCase();

    // ── pending: CV is waiting for employer review → block ──
    if (status == 'pending') {
      final hasAiScore =
          existingApp['aiScreeningScore'] != null &&
          existingApp['aiScreeningScore'].toString().trim().isNotEmpty &&
          existingApp['aiScreeningScore'].toString() != '0';

      if (hasAiScore) {
        // Show old AI screening results in read-only mode
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AIScreeningScreen(
              job: job,
              cvFileName:
                  existingApp['cvFilename']?.toString() ?? selectedCvFilename,
              cvUrl: existingApp['cvUrl']?.toString() ?? selectedCvUrl,
              cvS3Key: existingApp['cvS3Key']?.toString() ?? selectedCvS3Key,
              existingApplication: existingApp,
            ),
          ),
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Đã ứng tuyển'),
            content: const Text(
              'Bạn đã ứng tuyển công việc này. CV của bạn đang chờ Nhà tuyển dụng duyệt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // ── rejected: CV was rejected → block ──
    if (status == 'rejected') {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Không đạt yêu cầu'),
          content: const Text(
            'Rất tiếc, CV của bạn chưa phù hợp cho công việc này ở thời điểm hiện tại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      return;
    }

    // ── already completed AI interview → block ──
    final hasInterviewAudio =
        (existingApp['aiInterviewAudio']?.toString().trim() ?? '').isNotEmpty ||
        (existingApp['aiInterviewAudioKey']?.toString().trim() ?? '')
            .isNotEmpty;
    if (hasInterviewAudio) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đã hoàn thành'),
          content: const Text(
            'Bạn đã hoàn thành phỏng vấn AI cho công việc này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      return;
    }

    // ── approved/accepted: employer approved CV → go to Round 2 interview ──
    if (status == 'approved' || status == 'accepted') {
      if (job.isAiScreeningEnabled) {
        final continuation = aiInterviewContinuationForExistingApplication(
          applications: applications,
          jobId: job.idJob,
          alternateJobId: job.id,
          selectedCvUrl: selectedCvUrl,
          selectedCvFilename: selectedCvFilename,
          selectedCvS3Key: selectedCvS3Key,
          jobRequiresAiInterview: true,
        );

        if (continuation != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AIInterviewChatScreen(
                job: job,
                cvFileName: continuation.cvFilename,
                cvUrl: continuation.cvUrl,
                cvS3Key: continuation.cvS3Key,
                applicationId: continuation.applicationId,
                aiScreeningScore: continuation.aiScreeningScore,
                aiScreeningResult: continuation.aiScreeningResult,
                aiScreeningReason: continuation.aiScreeningReason,
              ),
            ),
          );
          return;
        }
      }

      // approved but no AI interview required
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('CV đã được duyệt'),
          content: const Text(
            'CV của bạn đã được nhà tuyển dụng duyệt cho công việc này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      return;
    }
  }

  // ── 2. No existing application → start fresh AI screening ──
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AIScreeningScreen(
        job: job,
        cvFileName: selectedCvFilename,
        cvUrl: selectedCvUrl,
        cvS3Key: selectedCvS3Key,
      ),
    ),
  );
}

/// Call this from [_handleApply] **before** showing the CV-picker dialog.
/// Returns `true` if the candidate already has an application for this job
/// and the flow was handled (dialog/screen shown) — the caller should then
/// skip the CV-selection step entirely. Returns `false` when there is no
/// existing application and the normal CV-picker flow should proceed.
Future<bool> checkExistingApplicationBeforeApply({
  required BuildContext context,
  required WidgetRef ref,
  required JobPost job,
  required AuthUserProfile user,
  VoidCallback? onBeforeHandleExistingApplication,
}) async {
  final applications = await ref
      .read(applicationRepositoryProvider)
      .getCandidateApplications(user.userId);

  final existingApp =
      existingApplicationForJob(applications, job.idJob) ??
      existingApplicationForJob(applications, job.id);

  if (existingApp == null) return false; // no existing application
  if (!context.mounted) return true;

  final status = (existingApp['status']?.toString().trim() ?? '').toLowerCase();
  final hasInterviewAudio =
      (existingApp['aiInterviewAudio']?.toString().trim() ?? '').isNotEmpty ||
      (existingApp['aiInterviewAudioKey']?.toString().trim() ?? '').isNotEmpty;

  if (status == 'pending' ||
      status == 'rejected' ||
      status == 'approved' ||
      status == 'accepted' ||
      hasInterviewAudio) {
    onBeforeHandleExistingApplication?.call();
    if (!context.mounted) return true;
  }

  // ── pending: CV is waiting for employer review ──
  if (status == 'pending') {
    final hasAiScore =
        existingApp['aiScreeningScore'] != null &&
        existingApp['aiScreeningScore'].toString().trim().isNotEmpty &&
        existingApp['aiScreeningScore'].toString() != '0';

    if (hasAiScore) {
      // Show old AI screening results in read-only mode
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AIScreeningScreen(
            job: job,
            cvFileName: existingApp['cvFilename']?.toString() ?? 'CV.pdf',
            cvUrl: existingApp['cvUrl']?.toString() ?? '',
            cvS3Key: existingApp['cvS3Key']?.toString(),
            existingApplication: existingApp,
          ),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đã ứng tuyển'),
          content: const Text(
            'Bạn đã ứng tuyển công việc này. CV của bạn đang chờ Nhà tuyển dụng duyệt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
    return true;
  }

  // ── rejected ──
  if (status == 'rejected') {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Không đạt yêu cầu'),
        content: const Text(
          'Rất tiếc, CV của bạn chưa phù hợp cho công việc này ở thời điểm hiện tại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    return true;
  }

  // ── already completed AI interview ──
  if (hasInterviewAudio) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đã hoàn thành'),
        content: const Text(
          'Bạn đã hoàn thành phỏng vấn AI cho công việc này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    return true;
  }

  // ── approved/accepted: employer approved CV → go to Round 2 interview ──
  if (status == 'approved' || status == 'accepted') {
    if (job.isAiScreeningEnabled) {
      final continuation = aiInterviewContinuationForExistingApplication(
        applications: applications,
        jobId: job.idJob,
        alternateJobId: job.id,
        selectedCvUrl: existingApp['cvUrl']?.toString() ?? '',
        selectedCvFilename: existingApp['cvFilename']?.toString() ?? 'CV.pdf',
        selectedCvS3Key: existingApp['cvS3Key']?.toString(),
        jobRequiresAiInterview: true,
      );

      if (continuation != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AIInterviewChatScreen(
              job: job,
              cvFileName: continuation.cvFilename,
              cvUrl: continuation.cvUrl,
              cvS3Key: continuation.cvS3Key,
              applicationId: continuation.applicationId,
              aiScreeningScore: continuation.aiScreeningScore,
              aiScreeningResult: continuation.aiScreeningResult,
              aiScreeningReason: continuation.aiScreeningReason,
            ),
          ),
        );
        return true;
      }
    }

    // approved but no AI interview required
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('CV đã được duyệt'),
          content: const Text(
            'CV của bạn đã được nhà tuyển dụng duyệt cho công việc này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
    return true;
  }

  return false; // unknown status → proceed normally
}

Future<bool> openExistingAiInterviewForDuplicateApplication({
  required BuildContext context,
  required WidgetRef ref,
  required JobPost job,
  required AuthUserProfile user,
  required String selectedCvUrl,
  required String selectedCvFilename,
  String? selectedCvS3Key,
}) async {
  final applications = await ref
      .read(applicationRepositoryProvider)
      .getCandidateApplications(user.userId);
  final continuation = aiInterviewContinuationForExistingApplication(
    applications: applications,
    jobId: job.idJob,
    alternateJobId: job.id,
    selectedCvUrl: selectedCvUrl,
    selectedCvFilename: selectedCvFilename,
    selectedCvS3Key: selectedCvS3Key,
    jobRequiresAiInterview: job.isAiScreeningEnabled,
  );
  if (continuation == null) return false;
  if (!context.mounted) return true;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AIInterviewChatScreen(
        job: job,
        cvFileName: continuation.cvFilename,
        cvUrl: continuation.cvUrl,
        cvS3Key: continuation.cvS3Key,
        applicationId: continuation.applicationId,
        aiScreeningScore: continuation.aiScreeningScore,
        aiScreeningResult: continuation.aiScreeningResult,
        aiScreeningReason: continuation.aiScreeningReason,
      ),
    ),
  );
  return true;
}

Future<bool> openRound2AiInterviewForJob({
  required BuildContext context,
  required WidgetRef ref,
  required JobPost job,
  required AuthUserProfile user,
}) async {
  final applications = await ref
      .read(applicationRepositoryProvider)
      .getCandidateApplications(user.userId);
  final continuation = aiInterviewContinuationForExistingApplication(
    applications: applications,
    jobId: job.idJob,
    alternateJobId: job.id,
    selectedCvUrl: '',
    selectedCvFilename: 'CV.pdf',
    jobRequiresAiInterview: job.isAiScreeningEnabled,
  );
  if (continuation == null) return false;
  if (!context.mounted) return true;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AIInterviewChatScreen(
        job: job,
        cvFileName: continuation.cvFilename,
        cvUrl: continuation.cvUrl,
        cvS3Key: continuation.cvS3Key,
        applicationId: continuation.applicationId,
        aiScreeningScore: continuation.aiScreeningScore,
        aiScreeningResult: continuation.aiScreeningResult,
        aiScreeningReason: continuation.aiScreeningReason,
      ),
    ),
  );
  return true;
}

Future<void> submitApplicationWithBackgroundEval({
  required BuildContext context,
  required WidgetRef ref,
  required JobPost job,
  required AuthUserProfile user,
  required String cvUrl,
  required String cvFilename,
  String? cvS3Key,
  required VoidCallback onSuccess,
  required void Function(String) onError,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final repository = ref.read(applicationRepositoryProvider);
    final response = await repository.submitApplication(
      jobId: job.idJob,
      cvUrl: cvUrl,
      cvFilename: cvFilename,
      cvS3Key: cvS3Key,
      notification: ApplicationNotificationDetails(
        employerId: job.employerId,
        candidateId: user.userId,
        candidateName: user.fullName,
        jobTitle: job.title,
        companyName: job.companyName ?? job.employerName,
        isQuickJob: job.isQuickJob,
      ),
    );

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    onSuccess();

    if (!job.isQuickJob) {
      _runBackgroundCvEvaluation(
        ref: ref,
        job: job,
        user: user,
        cvUrl: cvUrl,
        response: response,
      );
    }
  } catch (error) {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
    onError(error.toString());
  }
}

void _runBackgroundCvEvaluation({
  required WidgetRef ref,
  required JobPost job,
  required AuthUserProfile user,
  required String cvUrl,
  required Map<String, dynamic> response,
}) async {
  final applicationId = applicationIdFromSubmitResponse(response);
  if (applicationId == null) {
    debugPrint(
      '⚠️ [Background CV Evaluation] Skipped: applicationId is null in response',
    );
    return;
  }

  try {
    debugPrint(
      '🔍 [Background CV Evaluation] Starting for application $applicationId...',
    );

    final fullName = user.fullName.isNotEmpty ? user.fullName : 'Ứng viên';
    final title = job.title;
    final education = (user.education != null && user.education!.isNotEmpty)
        ? user.education!
        : 'Chưa cập nhật';
    final experience = (user.experience != null && user.experience!.isNotEmpty)
        ? user.experience!
        : 'Đã có kinh nghiệm làm việc ở vị trí tương đương.';
    final skills = (user.skills != null && user.skills!.isNotEmpty)
        ? user.skills!.join(', ')
        : 'Nhanh nhẹn, chăm chỉ, có trách nhiệm';
    final bio = (user.bio != null && user.bio!.isNotEmpty)
        ? user.bio!
        : 'Chưa cập nhật';

    final cvText =
        '''
Họ tên: $fullName
Vị trí mong muốn: $title
Kinh nghiệm làm việc: $experience
Học vấn: $education
Kỹ năng: $skills
Giới thiệu bản thân: $bio
'''
            .trim();

    final jdText =
        '''
Tiêu đề công việc: ${job.title}
Mô tả công việc: ${job.description}
Yêu cầu: ${job.requirements ?? "Có kinh nghiệm tương đương."}
Nhiệm vụ: ${job.responsibilities ?? "Hoàn thành các công việc được giao."}
'''
            .trim();

    final screeningResult = await ref
        .read(aiInterviewRepositoryProvider)
        .screenCv(jobDescription: jdText, cvText: cvText, cvUrl: cvUrl);

    final repository = ref.read(applicationRepositoryProvider);
    await repository.updateApplicationStatus(
      applicationId: applicationId,
      status: 'pending',
      extraFields: screeningResult.toApplicationExtraFields(),
    );

    debugPrint(
      '✅ [Background CV Evaluation] Successfully attached AI score to application: $applicationId',
    );
  } catch (error) {
    debugPrint('⚠️ [Background CV Evaluation] Failed silently: $error');
  }
}
