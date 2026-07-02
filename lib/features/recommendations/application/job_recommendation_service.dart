import '../../auth/domain/auth_user_profile.dart';
import '../../candidate/domain/job_post.dart';
import '../domain/job_recommendation.dart';

List<JobRecommendation> mapApiJobRecommendationsToJobs({
  required Iterable<dynamic> rawRecommendations,
  required List<JobPost> jobs,
}) {
  final jobMap = <String, JobPost>{};
  for (final job in jobs) {
    _putJobById(jobMap, job.id, job);
    _putJobById(jobMap, job.idJob, job);
  }

  final recommendations = <JobRecommendation>[];
  for (final raw in rawRecommendations) {
    if (raw is! Map) continue;
    final item = Map<dynamic, dynamic>.from(raw);
    final jobId = _recommendationJobId(item);
    if (jobId == null) continue;

    final matchedJob = jobMap[jobId];
    if (matchedJob == null) continue;

    recommendations.add(
      JobRecommendation(
        job: matchedJob,
        matchScore: _recommendationScore(item),
        reasons: _recommendationReasons(item),
      ),
    );
  }
  return recommendations;
}

void _putJobById(Map<String, JobPost> target, String rawId, JobPost job) {
  final id = rawId.trim();
  if (id.isEmpty) return;
  target[id] = job;
}

String? _recommendationJobId(Map<dynamic, dynamic> item) {
  final nestedJob = item['job'];
  return _firstNonEmpty([
    item['jobId'],
    item['jobID'],
    item['idJob'],
    item['id'],
    if (nestedJob is Map) ...[
      nestedJob['jobId'],
      nestedJob['jobID'],
      nestedJob['idJob'],
      nestedJob['id'],
    ],
  ]);
}

int _recommendationScore(Map<dynamic, dynamic> item) {
  final value = _firstNumber([
    item['matchScore'],
    item['score'],
    item['match'],
    item['percentage'],
  ]);
  return (value ?? 50).round().clamp(0, 100);
}

List<String> _recommendationReasons(Map<dynamic, dynamic> item) {
  final reasons = item['reasons'];
  if (reasons is List) {
    final parsed = reasons
        .map((reason) => reason?.toString().trim() ?? '')
        .where((reason) => reason.isNotEmpty)
        .toList(growable: false);
    if (parsed.isNotEmpty) return parsed;
  }

  final reason = _firstNonEmpty([
    item['matchReason'],
    item['reason'],
    item['explanation'],
    item['summary'],
  ]);
  return reason == null ? const [] : [reason];
}

String? _firstNonEmpty(Iterable<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return null;
}

num? _firstNumber(Iterable<dynamic> values) {
  for (final value in values) {
    if (value is num) return value;
    final parsed = num.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

class JobRecommendationService {
  const JobRecommendationService();

  List<JobRecommendation> recommend({
    required AuthUserProfile profile,
    required List<JobPost> jobs,
    List<Map<String, dynamic>> cvs = const [],
    List<Map<String, dynamic>> applications = const [],
    int limit = 8,
  }) {
    final appliedJobIds = applications
        .map((application) => application['jobId']?.toString())
        .whereType<String>()
        .toSet();
    final historyText = applications
        .where(_isUsefulHistory)
        .map((application) => application['jobTitle']?.toString() ?? '')
        .join(' ');
    final cvText = cvs
        .map(
          (cv) =>
              '${cv['cvFileName'] ?? ''} ${cv['summary'] ?? ''} ${cv['cvText'] ?? ''}',
        )
        .join(' ');

    final recommendations =
        jobs
            .where(
              (job) =>
                  !appliedJobIds.contains(job.id) &&
                  !appliedJobIds.contains(job.idJob),
            )
            .map(
              (job) => _score(
                profile: profile,
                job: job,
                historyText: historyText,
                cvText: cvText,
              ),
            )
            .toList()
          ..sort((a, b) {
            final scoreComparison = b.matchScore.compareTo(a.matchScore);
            if (scoreComparison != 0) return scoreComparison;
            return b.job.postedAt.compareTo(a.job.postedAt);
          });

    return recommendations.take(limit).toList(growable: false);
  }

  bool _isUsefulHistory(Map<String, dynamic> application) {
    final status = application['status']?.toString().toLowerCase().trim();
    return status == 'accepted' ||
        status == 'completed' ||
        status == 'completed_pending_candidate';
  }

  JobRecommendation _score({
    required AuthUserProfile profile,
    required JobPost job,
    required String historyText,
    required String cvText,
  }) {
    var score = 8;
    final reasons = <String>[];
    final jobText = _normalize(
      [
        job.title,
        job.description,
        job.requirements ?? '',
        job.tags.join(' '),
      ].join(' '),
    );

    final matchedSkills = (profile.skills ?? [])
        .where((skill) => _containsMeaningful(jobText, skill))
        .toList();
    if (matchedSkills.isNotEmpty) {
      score += (matchedSkills.length * 15).clamp(0, 45);
      reasons.add('Khớp kỹ năng: ${matchedSkills.take(3).join(', ')}');
    }

    final title = profile.title?.trim() ?? '';
    if (title.isNotEmpty && _textsOverlap(title, jobText)) {
      score += 24;
      reasons.add('Phù hợp với vị trí mong muốn "$title"');
    }

    if (historyText.trim().isNotEmpty && _textsOverlap(historyText, jobText)) {
      score += 18;
      reasons.add('Liên quan đến kinh nghiệm làm việc trước đây');
    }

    if (cvText.trim().isNotEmpty && _textsOverlap(cvText, jobText)) {
      score += 8;
      reasons.add('Có từ khóa phù hợp trong CV');
    }

    final location = profile.location?.trim() ?? '';
    if (location.isNotEmpty &&
        (_textsOverlap(location, job.location) ||
            _textsOverlap(job.location, location))) {
      score += 10;
      reasons.add('Địa điểm phù hợp với hồ sơ');
    }

    if ((profile.savedJobs ?? []).contains(job.id) ||
        (profile.savedJobs ?? []).contains(job.idJob)) {
      score += 5;
      reasons.add('Tương tự công việc bạn đã quan tâm');
    }

    if (DateTime.now().difference(job.postedAt).inDays <= 7) {
      score += 3;
    }

    if (reasons.isEmpty) {
      reasons.add('Tin tuyển dụng mới phù hợp để bạn khám phá');
    }

    return JobRecommendation(
      job: job,
      matchScore: score.clamp(0, 100),
      reasons: reasons.take(3).toList(growable: false),
    );
  }

  bool _containsMeaningful(String normalizedText, String value) {
    final normalizedValue = _normalize(value);
    if (normalizedValue.length < 2) return false;
    if (normalizedText.contains(normalizedValue)) return true;
    return _tokenize(
      normalizedValue,
    ).any((token) => token.length >= 3 && normalizedText.contains(token));
  }

  bool _textsOverlap(String left, String right) {
    final leftTokens = _tokenize(_normalize(left));
    final rightTokens = _tokenize(_normalize(right)).toSet();
    return leftTokens.any(
      (token) => token.length >= 3 && rightTokens.contains(token),
    );
  }

  List<String> _tokenize(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty && !_stopWords.contains(token))
        .toList(growable: false);
  }

  String _normalize(String value) {
    var result = value.toLowerCase();
    const replacements = <String, String>{
      'àáạảãâầấậẩẫăằắặẳẵ': 'a',
      'èéẹẻẽêềếệểễ': 'e',
      'ìíịỉĩ': 'i',
      'òóọỏõôồốộổỗơờớợởỡ': 'o',
      'ùúụủũưừứựửữ': 'u',
      'ỳýỵỷỹ': 'y',
      'đ': 'd',
    };
    for (final entry in replacements.entries) {
      for (final character in entry.key.split('')) {
        result = result.replaceAll(character, entry.value);
      }
    }
    return result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static const _stopWords = <String>{
    'and',
    'cho',
    'cua',
    'tai',
    'the',
    'thi',
    'this',
    'trong',
    'va',
    'voi',
  };
}
