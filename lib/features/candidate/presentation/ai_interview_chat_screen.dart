import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/application_repository.dart';
import '../data/aws_application_repository.dart';
import '../domain/job_post.dart';

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime time;

  ChatMessage({required this.text, required this.isMe, required this.time});
}

class AIInterviewChatScreen extends ConsumerStatefulWidget {
  final JobPost job;
  final String cvFileName;
  final String cvUrl;
  final String? cvS3Key;
  final String? applicationId;
  final int aiScreeningScore;
  final String aiScreeningResult;
  final String aiScreeningReason;

  const AIInterviewChatScreen({
    super.key,
    required this.job,
    required this.cvFileName,
    required this.cvUrl,
    this.cvS3Key,
    this.applicationId,
    required this.aiScreeningScore,
    required this.aiScreeningResult,
    required this.aiScreeningReason,
  });

  @override
  ConsumerState<AIInterviewChatScreen> createState() =>
      _AIInterviewChatScreenState();
}

class _AIInterviewChatScreenState extends ConsumerState<AIInterviewChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;
  bool _finished = false;
  String? _sessionId;
  String? _errorMessage;

  // Đối tượng lưu báo cáo phỏng vấn
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _startInterviewSession();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startInterviewSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
""";

      final response = await http
          .post(
            Uri.parse("http://localhost:8000/api/v1/interview/start"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "job_title": widget.job.title,
              "job_description": jdText,
              "cv_text": cvText,
              "cv_url": widget.cvUrl,
              "custom_questions": widget.job.customQuestions,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _sessionId = data["session_id"];
          _isLoading = false;
          _messages.add(
            ChatMessage(
              text: data["question"] ?? "Chào bạn, hãy bắt đầu buổi phỏng vấn.",
              isMe: false,
              time: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      } else {
        throw Exception("Server trả về mã lỗi: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Không thể khởi động buổi phỏng vấn AI. Vui lòng kiểm tra kết nối mạng hoặc server Backend.\nChi tiết: $e";
      });
    }
  }

  Future<void> _handleSendAnswer() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending || _sessionId == null) return;

    _textController.clear();
    setState(() {
      _isSending = true;
      _messages.add(ChatMessage(text: text, isMe: true, time: DateTime.now()));
    });
    _scrollToBottom();

    try {
      final response = await http
          .post(
            Uri.parse("http://localhost:8000/api/v1/interview/respond"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"session_id": _sessionId, "answer": text}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _isSending = false;
          _finished = data["finished"] ?? false;

          if (_finished) {
            _report = data["report"];
            _messages.add(
              ChatMessage(
                text:
                    "Cảm ơn bạn đã tham gia buổi phỏng vấn. Hệ thống đang tổng hợp kết quả của bạn...",
                isMe: false,
                time: DateTime.now(),
              ),
            );
            _showReportDialog();
            _submitDeferredApplication();
          } else {
            _messages.add(
              ChatMessage(
                text: data["question"] ?? "",
                isMe: false,
                time: DateTime.now(),
              ),
            );
          }
        });
        _scrollToBottom();
      } else {
        throw Exception("Server trả về mã lỗi: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _isSending = false;
        _messages.add(
          ChatMessage(
            text:
                "⚠️ Lỗi: Không thể gửi câu trả lời đến AI. Vui lòng kiểm tra lại kết nối của bạn và thử lại.",
            isMe: false,
            time: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _submitDeferredApplication() async {
    if (_report == null) return;
    final score = _report!["total_score"] ?? 0;
    final recommend = _report!["recommend_to_employer"] ?? false;
    final isPassed = recommend || (score >= 70);

    if (!isPassed) {
      safePrint(
        "❌ [Deferred] Interview failed, skipping application submission",
      );
      return;
    }

    try {
      final user = ref.read(authControllerProvider).asData?.value.user;
      if (user == null) {
        throw Exception("Vui lòng đăng nhập để hoàn tất ứng tuyển.");
      }

      final repository = ref.read(applicationRepositoryProvider);

      final extraFields = {
        'aiScreeningScore': widget.aiScreeningScore,
        'aiScreeningResult': widget.aiScreeningResult,
        'aiScreeningReason': widget.aiScreeningReason,
        'aiInterviewScore': score,
        'aiInterviewReport': _report ?? {},
      };

      await repository.submitApplication(
        jobId: widget.job.idJob,
        cvUrl: widget.cvUrl,
        cvFilename: widget.cvFileName,
        notification: ApplicationNotificationDetails(
          employerId: widget.job.employerId,
          candidateId: user.userId,
          candidateName: user.fullName,
          jobTitle: widget.job.title,
          companyName: widget.job.companyName ?? widget.job.employerName,
          isQuickJob: widget.job.isQuickJob,
        ),
        extraFields: extraFields,
      );

      safePrint(
        "✅ [Deferred] Application submitted successfully after AI Interview",
      );
    } catch (e) {
      safePrint("❌ [Deferred] Failed to submit application: $e");
    }
  }

  void _showReportDialog() {
    if (_report == null) return;

    final score = _report!["total_score"] ?? 0;
    final recommend = _report!["recommend_to_employer"] ?? false;
    final strengths = List<String>.from(_report!["strengths"] ?? []);
    final weaknesses = List<String>.from(_report!["weaknesses"] ?? []);
    final reason = _report!["reason"] ?? "";

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Báo cáo kết quả phỏng vấn',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Điểm số và Đề xuất
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: score >= 70 ? Colors.green : Colors.red,
                          ),
                        ),
                        const Text(
                          'Điểm phỏng vấn',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 60, color: Colors.grey[300]),
                    Column(
                      children: [
                        Icon(
                          recommend ? Icons.check_circle : Icons.cancel,
                          size: 48,
                          color: recommend ? Colors.green : Colors.red,
                        ),
                        Text(
                          recommend ? 'Gửi CV thành công' : 'Chưa phù hợp',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: recommend ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // Nhận xét chi tiết
                const Text(
                  'Đánh giá chung:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(reason, style: const TextStyle(fontSize: 14, height: 1.4)),
                const SizedBox(height: 16),

                // Điểm mạnh
                if (strengths.isNotEmpty) ...[
                  const Text(
                    'Điểm mạnh:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...strengths.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Điểm yếu
                if (weaknesses.isNotEmpty) ...[
                  const Text(
                    'Điểm cần cải thiện:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...weaknesses.map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.arrow_right_alt_outlined,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              w,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                const Divider(),
                const SizedBox(height: 12),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(); // Đóng bottom sheet
                    Navigator.of(context).pop(); // Đóng chat screen
                    Navigator.of(context).pop(); // Đóng screening screen
                  },
                  child: const Text(
                    'Hoàn tất và Quay lại',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Phỏng vấn AI Interviewer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.job.title,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_finished && _report != null)
            IconButton(
              icon: const Icon(Icons.assignment_turned_in),
              tooltip: 'Xem kết quả phỏng vấn',
              onPressed: _showReportDialog,
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
                ),
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.secondary),
          const SizedBox(height: 20),
          Text(
            'Đang kết nối phiên phỏng vấn với AI...',
            style: TextStyle(color: Colors.grey[700], fontSize: 15),
          ),
        ],
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
            const SizedBox(height: 16),
            const Text(
              'Lỗi kết nối phiên phỏng vấn',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? "",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _startInterviewSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
              ),
              child: const Text(
                'Kết nối lại',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final alignment = message.isMe
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = message.isMe ? AppColors.secondary : Colors.grey[200];
    final textColor = message.isMe ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(message.isMe ? 16 : 0),
                bottomRight: Radius.circular(message.isMe ? 0 : 16),
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(message.time),
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'AI đang suy nghĩ...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textController,
                enabled: !_finished && !_isSending,
                decoration: const InputDecoration(
                  hintText: 'Nhập câu trả lời của bạn...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 15),
                onSubmitted: (_) => _handleSendAnswer(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.send,
              color: _finished || _isSending
                  ? Colors.grey
                  : AppColors.secondary,
            ),
            onPressed: _finished || _isSending ? null : _handleSendAnswer,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '${time.hour}:$minuteStr';
  }
}
