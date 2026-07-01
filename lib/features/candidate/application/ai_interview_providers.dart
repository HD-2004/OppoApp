import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/aws_ai_interview_repository.dart';
import '../domain/ai_interview_repository.dart';

final aiInterviewRepositoryProvider = Provider<AiInterviewRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AwsAiInterviewRepository(client: client);
});
