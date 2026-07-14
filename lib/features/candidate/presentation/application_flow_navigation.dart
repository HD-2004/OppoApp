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
  final openedExistingInterview =
      await openExistingAiInterviewForDuplicateApplication(
        context: context,
        ref: ref,
        job: job,
        user: user,
        selectedCvUrl: selectedCvUrl,
        selectedCvFilename: selectedCvFilename,
        selectedCvS3Key: selectedCvS3Key,
      );
  if (openedExistingInterview || !context.mounted) return;

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
    debugPrint('⚠️ [Background CV Evaluation] Skipped: applicationId is null in response');
    return;
  }

  try {
    debugPrint('🔍 [Background CV Evaluation] Starting for application $applicationId...');

    final fullName = user.fullName.isNotEmpty ? user.fullName : 'Ứng viên';
    final title = job.title;
    final education = (user.education != null && user.education!.isNotEmpty) ? user.education! : 'Chưa cập nhật';
    final experience = (user.experience != null && user.experience!.isNotEmpty) ? user.experience! : 'Đã có kinh nghiệm làm việc ở vị trí tương đương.';
    final skills = (user.skills != null && user.skills!.isNotEmpty) ? user.skills!.join(', ') : 'Nhanh nhẹn, chăm chỉ, có trách nhiệm';
    final bio = (user.bio != null && user.bio!.isNotEmpty) ? user.bio! : 'Chưa cập nhật';

    final cvText = '''
Họ tên: $fullName
Vị trí mong muốn: $title
Kinh nghiệm làm việc: $experience
Học vấn: $education
Kỹ năng: $skills
Giới thiệu bản thân: $bio
'''.trim();

    final jdText = '''
Tiêu đề công việc: ${job.title}
Mô tả công việc: ${job.description}
Yêu cầu: ${job.requirements ?? "Có kinh nghiệm tương đương."}
Nhiệm vụ: ${job.responsibilities ?? "Hoàn thành các công việc được giao."}
'''.trim();

    final screeningResult = await ref
        .read(aiInterviewRepositoryProvider)
        .screenCv(
          jobDescription: jdText,
          cvText: cvText,
          cvUrl: cvUrl,
        );

    final repository = ref.read(applicationRepositoryProvider);
    await repository.updateApplicationStatus(
      applicationId: applicationId,
      status: 'pending',
      extraFields: screeningResult.toApplicationExtraFields(),
    );

    debugPrint('✅ [Background CV Evaluation] Successfully attached AI score to application: $applicationId');
  } catch (error) {
    debugPrint('⚠️ [Background CV Evaluation] Failed silently: $error');
  }
}
