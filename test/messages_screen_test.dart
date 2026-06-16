import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/messaging/application/messaging_providers.dart';
import 'package:oppo_temp_jobs/features/messaging/domain/candidate_application.dart';
import 'package:oppo_temp_jobs/features/messaging/presentation/pages/messages_screen.dart';

void main() {
  testWidgets('messages list does not show compose message action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateChatsProvider.overrideWithBuild(
            (_, _) => <CandidateApplication>[],
          ),
          activeJobsProvider.overrideWith((_) async => <JobPost>[]),
          activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
        ],
        child: const MaterialApp(home: MessagesScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('Soạn tin nhắn'), findsNothing);
    expect(find.byIcon(Icons.edit_square), findsNothing);
    expect(find.text('Tin nhắn'), findsOneWidget);
  });
}
