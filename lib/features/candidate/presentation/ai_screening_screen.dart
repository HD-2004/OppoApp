import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/ai_interview_providers.dart';
import '../data/aws_application_repository.dart';
import '../domain/ai_interview_models.dart';
import '../domain/application_repository.dart';
import '../domain/job_post.dart';
import 'ai_interview_chat_screen.dart';

class AIScreeningScreen extends ConsumerStatefulWidget {
  final JobPost job;
  final String cvFileName;
  final String cvUrl;
  final String? cvS3Key;

  const AIScreeningScreen({
    super.key,
    required this.job,
    required this.cvFileName,
    required this.cvUrl,
    this.cvS3Key,
  });

  @override
  ConsumerState<AIScreeningScreen> createState() => _AIScreeningScreenState();
}

class _AIScreeningScreenState extends ConsumerState<AIScreeningScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  int _score = 0;
  String _result = "review";
  List<String> _strengths = [];
  List<String> _weaknesses = [];
  String _reason = "";
  String? _applicationId;
  String? _applicationNotice;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
    _runCVScreening();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _runCVScreening() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _applicationNotice = null;
    });

    late CvScreeningResult screeningResult;
    try {
      final user = ref.read(authControllerProvider).asData?.value.user;
      final fullName = user?.fullName.isNotEmpty == true
          ? user!.fullName
          : 'Ứng viên';
      final title = widget.job.title;
      final skills = (user?.skills != null && user!.skills!.isNotEmpty)
          ? user.skills!.join(', ')
          : 'Nhanh nhẹn, chăm chỉ, có trách nhiệm';
      final bio = (user?.bio != null && user!.bio!.isNotEmpty)
          ? user.bio!
          : 'Chưa cập nhật';

      final cvText =
          '''
Họ tên: $fullName
Vị trí mong muốn: $title
Kinh nghiệm làm việc: Đã có kinh nghiệm làm việc ở vị trí tương đương.
Học vấn: Chưa cập nhật
Kỹ năng: $skills
Giới thiệu bản thân: $bio
'''
              .trim();

      final jdText =
          """
Tiêu đề công việc: ${widget.job.title}
Mô tả công việc: ${widget.job.description}
Yêu cầu: ${widget.job.requirements ?? "Có kinh nghiệm lập trình và thiết kế ứng dụng di động."}
Nhiệm vụ: ${widget.job.responsibilities ?? "Phát triển và bảo trì các tính năng ứng dụng."}
""";

      screeningResult = await ref
          .read(aiInterviewRepositoryProvider)
          .screenCv(
            jobDescription: jdText,
            cvText: cvText,
            cvUrl: widget.cvUrl,
          );

      setState(() {
        _score = screeningResult.score;
        _result = screeningResult.result;
        _strengths = screeningResult.strengths;
        _weaknesses = screeningResult.weaknesses;
        _reason = screeningResult.reason;
        _isLoading = false;

        _progressAnimation = Tween<double>(begin: 0, end: _score / 100.0)
            .animate(
              CurvedAnimation(
                parent: _progressController,
                curve: Curves.easeOutCubic,
              ),
            );
        _progressController.forward();
      });
    } catch (_) {
      screeningResult = CvScreeningResult.websiteMockFallback(
        jobTitle: widget.job.title,
      );
      if (!mounted) return;
      setState(() {
        _score = screeningResult.score;
        _result = screeningResult.result;
        _strengths = screeningResult.strengths;
        _weaknesses = screeningResult.weaknesses;
        _reason = screeningResult.reason;
        _isLoading = false;
        _errorMessage = null;
        _applicationNotice =
            'Dịch vụ AI đang bận, app tạm dùng quy trình mô phỏng để bạn tiếp tục vòng phỏng vấn.';

        _progressAnimation = Tween<double>(begin: 0, end: _score / 100.0)
            .animate(
              CurvedAnimation(
                parent: _progressController,
                curve: Curves.easeOutCubic,
              ),
            );
        _progressController.forward(from: 0);
      });
    }

    if (screeningResult.canContinueToInterview) {
      try {
        await _submitRoundOneApplication(screeningResult);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _applicationNotice =
              'AI đã phân tích xong, nhưng chưa thể tạo hồ sơ ứng tuyển. '
              'Vui lòng thử lại sau.\nChi tiết: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  Future<void> _submitRoundOneApplication(CvScreeningResult result) async {
    if (_applicationId != null) return;

    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user == null) {
      throw Exception('Vui lòng đăng nhập để ứng tuyển.');
    }

    final repository = ref.read(applicationRepositoryProvider);
    try {
      final response = await repository.submitApplication(
        jobId: widget.job.idJob,
        cvUrl: widget.cvUrl,
        cvFilename: widget.cvFileName,
        cvS3Key: widget.cvS3Key,
        notification: ApplicationNotificationDetails(
          employerId: widget.job.employerId,
          candidateId: user.userId,
          candidateName: user.fullName,
          jobTitle: widget.job.title,
          companyName: widget.job.companyName ?? widget.job.employerName,
          isQuickJob: widget.job.isQuickJob,
        ),
        extraFields: result.toApplicationExtraFields(),
      );

      final id = applicationIdFromSubmitResponse(response);
      if (id == null) {
        throw Exception('Không nhận được mã hồ sơ ứng tuyển từ máy chủ.');
      }
      if (mounted) {
        setState(() => _applicationId = id);
      }
    } catch (e) {
      if (!isAlreadyAppliedApplicationError(e)) rethrow;

      final applications = await repository.getCandidateApplications(
        user.userId,
      );
      final existingId =
          existingApplicationIdForJob(applications, widget.job.idJob) ??
          existingApplicationIdForJob(applications, widget.job.id);

      if (!mounted) return;
      setState(() {
        _applicationId = existingId;
        _applicationNotice = existingId == null
            ? 'Bạn đã ứng tuyển công việc này rồi. App chưa lấy được mã hồ sơ hiện có nên chưa thể mở vòng phỏng vấn tiếp theo.'
            : 'Bạn đã ứng tuyển công việc này rồi. App sẽ dùng hồ sơ hiện có để tiếp tục vòng phỏng vấn AI.';
      });
    }
  }

  Color _getResultColor() {
    switch (_result.toLowerCase()) {
      case "pass":
        return Colors.green;
      case "review":
        return Colors.amber;
      case "fail":
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getResultText() {
    switch (_result.toLowerCase()) {
      case "pass":
        return "ĐẠT YÊU CẦU";
      case "review":
        return "CẦN XEM XÉT THÊM";
      case "fail":
        return "CHƯA PHÙ HỢP";
      default:
        return "ĐANG ĐÁNH GIÁ";
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultColor = _getResultColor();
    final resultText = _getResultText();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn lọc hồ sơ bằng AI'),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : _buildSuccessState(resultColor, resultText),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'AI đang phân tích hồ sơ...',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Đối chiếu CV "${widget.cvFileName}" với yêu cầu công việc từ nhà tuyển dụng.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 72,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'Lỗi kết nối AI',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? "",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _runCVScreening,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(Color resultColor, String resultText) {
    final bool isPassed = _result.toLowerCase() != "fail";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Score ───────────────────────────────────────────────
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  Text(
                    widget.job.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.job.companyName ?? widget.job.employerName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Vòng tròn điểm số Animated
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: CircularProgressIndicator(
                              value: _progressAnimation.value,
                              strokeWidth: 12,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                resultColor,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(_progressAnimation.value * 100).toInt()}',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: resultColor,
                                ),
                              ),
                              const Text(
                                '/100 Điểm',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: resultColor, width: 1.5),
                    ),
                    child: Text(
                      resultText,
                      style: TextStyle(
                        color: resultColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Reason ──────────────────────────────────────────────────────
          _buildSectionCard(
            title: "Đánh giá chi tiết của AI",
            icon: Icons.psychology_outlined,
            iconColor: Colors.purple,
            child: Text(
              _reason,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),

          // ── Strengths ───────────────────────────────────────────────────
          if (_strengths.isNotEmpty) ...[
            _buildSectionCard(
              title: "Điểm mạnh nổi bật",
              icon: Icons.check_circle_outline,
              iconColor: Colors.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _strengths
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.arrow_right, color: Colors.green),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                s,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Weaknesses ──────────────────────────────────────────────────
          if (_weaknesses.isNotEmpty) ...[
            _buildSectionCard(
              title: "Điểm cần cải thiện / Thiếu sót",
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.amber[700]!,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _weaknesses
                    .map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.arrow_right, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                w,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (_applicationNotice != null) ...[
            Card(
              color: _applicationId == null
                  ? Colors.orange[50]
                  : Colors.blue[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _applicationId == null
                      ? Colors.orange
                      : AppColors.secondary,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _applicationId == null
                          ? Icons.info_outline
                          : Icons.check_circle_outline,
                      color: _applicationId == null
                          ? Colors.orange[800]
                          : AppColors.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _applicationNotice!,
                        style: TextStyle(
                          color: _applicationId == null
                              ? Colors.orange[900]
                              : Colors.blue[900],
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Action Button ──────────────────────────────────────────────
          if (isPassed)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _applicationId == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AIInterviewChatScreen(
                            job: widget.job,
                            cvFileName: widget.cvFileName,
                            cvUrl: widget.cvUrl,
                            cvS3Key: widget.cvS3Key,
                            applicationId: _applicationId,
                            aiScreeningScore: _score,
                            aiScreeningResult: _result,
                            aiScreeningReason: _reason,
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.forum_outlined),
              label: const Text(
                'Bắt đầu Vòng 2: Phỏng vấn với AI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )
          else
            Card(
              color: Colors.red[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.red, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hồ sơ của bạn chưa đạt mức độ phù hợp tối thiểu để bước vào vòng phỏng vấn AI. Đơn ứng tuyển của bạn đã được lưu lại để nhà tuyển dụng xem xét thủ công.',
                        style: TextStyle(color: Colors.red[900], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}
