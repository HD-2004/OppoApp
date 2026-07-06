import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_user_profile.dart';
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
