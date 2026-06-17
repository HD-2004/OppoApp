import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
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
    });

    try {
      final user = ref.read(authControllerProvider).asData?.value.user;
      final fullName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Ứng viên';
      final title = widget.job.title;
      final skills = (user?.skills != null && user!.skills!.isNotEmpty)
          ? user.skills!.join(', ')
          : 'Nhanh nhẹn, chăm chỉ, có trách nhiệm';
      final bio = (user?.bio != null && user!.bio!.isNotEmpty) ? user.bio! : 'Chưa cập nhật';

      final cvText = '''
Họ tên: $fullName
Vị trí mong muốn: $title
Kinh nghiệm làm việc: Đã có kinh nghiệm làm việc ở vị trí tương đương.
Học vấn: Chưa cập nhật
Kỹ năng: $skills
Giới thiệu bản thân: $bio
'''.trim();

      final jdText = """
Tiêu đề công việc: ${widget.job.title}
Mô tả công việc: ${widget.job.description}
Yêu cầu: ${widget.job.requirements ?? "Có kinh nghiệm lập trình và thiết kế ứng dụng di động."}
Nhiệm vụ: ${widget.job.responsibilities ?? "Phát triển và bảo trì các tính năng ứng dụng."}
""";

      // Gọi API FastAPI Backend
      // Flutter Web chạy trên localhost, chúng ta sẽ gọi đến backend localhost:8000
      final response = await http.post(
        Uri.parse("http://localhost:8000/api/v1/cv/screen"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "job_description": jdText,
          "cv_text": cvText,
          "cv_url": widget.cvUrl,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _score = data["score"] ?? 0;
          _result = data["result"] ?? "review";
          _strengths = List<String>.from(data["strengths"] ?? []);
          _weaknesses = List<String>.from(data["weaknesses"] ?? []);
          _reason = data["reason"] ?? "";
          _isLoading = false;

          // Chạy animation vòng tròn điểm số
          _progressAnimation = Tween<double>(
            begin: 0,
            end: _score / 100.0,
          ).animate(
            CurvedAnimation(
              parent: _progressController,
              curve: Curves.easeOutCubic,
            ),
          );
          _progressController.forward();
        });
      } else {
        throw Exception("Server trả về mã lỗi: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Không thể kết nối đến máy chủ AI. Vui lòng đảm bảo Backend FastAPI đang chạy tại cổng 8000.\nChi tiết: $e";
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
            const Icon(Icons.error_outline_rounded, size: 72, color: Colors.red),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(resultColor),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    .map((s) => Padding(
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
                        ))
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
                    .map((w) => Padding(
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
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
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
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AIInterviewChatScreen(
                      job: widget.job,
                      cvFileName: widget.cvFileName,
                      cvUrl: widget.cvUrl,
                      cvS3Key: widget.cvS3Key,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
