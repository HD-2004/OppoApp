import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/ai_interview_providers.dart';
import '../data/aws_application_repository.dart';
import '../domain/ai_interview_models.dart';
import '../domain/job_post.dart';

enum _VoiceInterviewPhase {
  connecting,
  speaking,
  ready,
  listening,
  processing,
  finished,
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
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  _VoiceInterviewPhase _phase = _VoiceInterviewPhase.connecting;
  bool _speechReady = false;
  bool _ttsConfigured = false;
  bool _hasSubmittedCurrentUtterance = false;
  bool _finished = false;
  int _questionNumber = 0;
  double _soundLevel = 0;
  String _pendingAnswer = '';
  String? _sessionId;
  String? _currentQuestion;
  String? _errorMessage;
  String? _noticeMessage;
  String? _speechLocaleId;

  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _configureTextToSpeech();
    _startInterviewSession();
  }

  @override
  void dispose() {
    _speechToText.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _configureTextToSpeech() async {
    if (_ttsConfigured) return;

    _flutterTts.setStartHandler(() {
      if (!mounted) return;
      setState(() {
        _phase = _VoiceInterviewPhase.speaking;
        _noticeMessage = null;
      });
    });

    _flutterTts.setCompletionHandler(() {
      if (!mounted || _finished || _phase != _VoiceInterviewPhase.speaking) {
        return;
      }
      setState(() {
        _phase = _VoiceInterviewPhase.ready;
      });
    });

    _flutterTts.setCancelHandler(() {
      if (!mounted || _finished || _phase != _VoiceInterviewPhase.speaking) {
        return;
      }
      setState(() {
        _phase = _VoiceInterviewPhase.ready;
      });
    });

    _flutterTts.setErrorHandler((message) {
      if (!mounted) return;
      setState(() {
        _phase = _VoiceInterviewPhase.ready;
        _noticeMessage =
            'Không thể phát câu hỏi bằng giọng nói. Hãy bấm nghe lại.';
      });
    });

    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.setLanguage('vi-VN');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);

    _ttsConfigured = true;
  }

  Future<void> _startInterviewSession() async {
    await _speechToText.cancel();
    await _flutterTts.stop();

    if (!mounted) return;
    setState(() {
      _phase = _VoiceInterviewPhase.connecting;
      _errorMessage = null;
      _noticeMessage = null;
      _finished = false;
      _report = null;
      _currentQuestion = null;
      _pendingAnswer = '';
      _questionNumber = 0;
      _soundLevel = 0;
      _hasSubmittedCurrentUtterance = false;
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
          '''
Tiêu đề công việc: ${widget.job.title}
Mô tả công việc: ${widget.job.description}
Yêu cầu: ${widget.job.requirements ?? "Có kinh nghiệm lập trình và thiết kế ứng dụng di động."}
''';

      final result = await ref
          .read(aiInterviewRepositoryProvider)
          .startInterview(
            jobTitle: widget.job.title,
            jobDescription: jdText,
            cvText: cvText,
            cvUrl: widget.cvUrl,
            customQuestions: widget.job.customQuestions,
          );

      if (result.sessionId.isEmpty) {
        throw Exception('Không nhận được mã phiên phỏng vấn từ máy chủ.');
      }

      final question = result.question.trim().isNotEmpty
          ? result.question.trim()
          : 'Chào bạn, hãy bắt đầu buổi phỏng vấn.';

      if (!mounted) return;
      setState(() {
        _sessionId = result.sessionId;
        _currentQuestion = question;
        _questionNumber = 1;
      });

      await _speakQuestion(question);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Không thể khởi động buổi phỏng vấn AI. Vui lòng kiểm tra kết nối mạng và thử lại.\nChi tiết: $e';
      });
    }
  }

  Future<void> _speakQuestion(String question) async {
    if (question.trim().isEmpty) return;

    await _configureTextToSpeech();
    await _speechToText.cancel();
    await _flutterTts.stop();

    if (!mounted) return;
    setState(() {
      _phase = _VoiceInterviewPhase.speaking;
      _noticeMessage = null;
      _soundLevel = 0;
    });

    try {
      await _flutterTts.speak(question);
      if (!mounted || _finished || _phase != _VoiceInterviewPhase.speaking) {
        return;
      }
      setState(() {
        _phase = _VoiceInterviewPhase.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _VoiceInterviewPhase.ready;
        _noticeMessage =
            'Không thể phát câu hỏi bằng giọng nói. Hãy bấm nghe lại.';
      });
    }
  }

  Future<void> _replayCurrentQuestion() async {
    final question = _currentQuestion;
    if (question == null ||
        question.trim().isEmpty ||
        _phase == _VoiceInterviewPhase.processing ||
        _phase == _VoiceInterviewPhase.listening) {
      return;
    }
    await _speakQuestion(question);
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speechReady) return true;

    final available = await _speechToText.initialize(
      onStatus: _handleSpeechStatus,
      onError: _handleSpeechError,
    );

    if (!mounted) return false;
    if (!available) {
      setState(() {
        _errorMessage =
            'Thiết bị chưa cho phép hoặc không hỗ trợ nhận diện giọng nói. Vui lòng bật quyền microphone và thử lại.';
      });
      return false;
    }

    _speechReady = true;
    return true;
  }

  Future<String?> _preferredSpeechLocale() async {
    if (_speechLocaleId != null) return _speechLocaleId;

    try {
      final locales = await _speechToText.locales();
      for (final locale in locales) {
        final normalized = locale.localeId.toLowerCase().replaceAll('-', '_');
        if (normalized.startsWith('vi_')) {
          _speechLocaleId = locale.localeId;
          return _speechLocaleId;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> _handleMicPressed() async {
    if (_phase == _VoiceInterviewPhase.listening) {
      await _finishListeningAndSubmit();
      return;
    }

    if (_phase != _VoiceInterviewPhase.ready ||
        _finished ||
        _sessionId == null) {
      return;
    }

    await _startListening();
  }

  Future<void> _startListening() async {
    final ready = await _ensureSpeechReady();
    if (!ready || !mounted) return;

    await _flutterTts.stop();

    final localeId = await _preferredSpeechLocale();
    if (!mounted) return;

    setState(() {
      _phase = _VoiceInterviewPhase.listening;
      _pendingAnswer = '';
      _noticeMessage = null;
      _soundLevel = 0;
      _hasSubmittedCurrentUtterance = false;
    });

    try {
      await _speechToText.listen(
        onResult: _handleSpeechResult,
        onSoundLevelChange: (level) {
          if (!mounted || _phase != _VoiceInterviewPhase.listening) return;
          setState(() {
            _soundLevel = level;
          });
        },
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 45),
          localeId: localeId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _VoiceInterviewPhase.ready;
        _noticeMessage =
            'Không thể mở microphone. Vui lòng kiểm tra quyền microphone và thử lại.';
      });
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (!mounted || _phase != _VoiceInterviewPhase.listening) return;

    final recognized = result.recognizedWords.trim();
    if (recognized.isNotEmpty) {
      _pendingAnswer = recognized;
    }

    if (result.finalResult && _pendingAnswer.trim().isNotEmpty) {
      unawaited(_finishListeningAndSubmit());
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted || _phase != _VoiceInterviewPhase.listening) return;

    final normalized = status.toLowerCase();
    if (normalized == 'done' ||
        normalized == 'notlistening' ||
        normalized == 'not_listening') {
      unawaited(_finishListeningAndSubmit());
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted || _phase != _VoiceInterviewPhase.listening) return;

    setState(() {
      _phase = _VoiceInterviewPhase.ready;
      _noticeMessage = error.permanent
          ? 'Nhận diện giọng nói đang bị chặn. Vui lòng bật quyền microphone rồi thử lại.'
          : 'Mình chưa nghe rõ câu trả lời. Hãy bấm mic và nói lại.';
    });
  }

  Future<void> _finishListeningAndSubmit() async {
    if (_hasSubmittedCurrentUtterance ||
        _phase != _VoiceInterviewPhase.listening) {
      return;
    }

    _hasSubmittedCurrentUtterance = true;

    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {
      // The recognizer may already be closed by the platform timeout.
    }

    final answer = _pendingAnswer.trim();
    if (answer.isEmpty) {
      if (!mounted) return;
      setState(() {
        _phase = _VoiceInterviewPhase.ready;
        _noticeMessage =
            'Mình chưa nghe rõ câu trả lời. Hãy bấm mic và nói lại.';
      });
      _hasSubmittedCurrentUtterance = false;
      return;
    }

    await _submitSpokenAnswer(answer);
  }

  Future<void> _submitSpokenAnswer(String answer) async {
    final sessionId = _sessionId;
    if (sessionId == null || _finished) return;

    if (!mounted) return;
    setState(() {
      _phase = _VoiceInterviewPhase.processing;
      _noticeMessage = null;
      _soundLevel = 0;
    });

    try {
      final data = await ref
          .read(aiInterviewRepositoryProvider)
          .respondInterview(sessionId: sessionId, answer: answer);
      final report = data.report;

      if (!mounted) return;
      if (data.finished) {
        setState(() {
          _finished = true;
          _phase = _VoiceInterviewPhase.finished;
          _report = report?.toJson();
          _currentQuestion = null;
        });

        _showReportDialog();
        await _submitDeferredApplication(report);
        return;
      }

      final nextQuestion = data.question?.trim() ?? '';
      if (nextQuestion.isEmpty) {
        throw Exception('Không nhận được câu hỏi tiếp theo từ máy chủ.');
      }

      setState(() {
        _currentQuestion = nextQuestion;
        _questionNumber += 1;
        _pendingAnswer = '';
      });

      await _speakQuestion(nextQuestion);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _VoiceInterviewPhase.ready;
        _noticeMessage =
            'Không thể gửi câu trả lời đến AI. Vui lòng kiểm tra kết nối và trả lời lại.';
      });
    }
  }

  Future<void> _submitDeferredApplication(InterviewReport? report) async {
    if (report == null || !report.isPassed) {
      debugPrint('AI interview did not pass; skipping application update');
      return;
    }

    final applicationId = widget.applicationId;
    if (applicationId == null || applicationId.trim().isEmpty) {
      debugPrint(
        'AI interview finished without applicationId; skipping update',
      );
      return;
    }

    try {
      final repository = ref.read(applicationRepositoryProvider);

      final extraFields = {
        'aiScreeningScore': widget.aiScreeningScore,
        'aiScreeningResult': widget.aiScreeningResult,
        'aiScreeningReason': widget.aiScreeningReason,
        'aiInterviewScore': report.totalScore,
        'aiInterviewReport': report.toJson(),
      };

      await repository.updateApplicationStatus(
        applicationId: applicationId,
        status: 'approved',
        extraFields: extraFields,
      );

      debugPrint('AI interview application updated successfully');
    } catch (e) {
      debugPrint('Failed to update application after AI interview: $e');
    }
  }

  void _showReportDialog() {
    if (_report == null || !mounted) return;

    final score = _report!["total_score"] ?? 0;
    final recommend = _report!["recommend_to_employer"] ?? false;
    final isPassed = recommend || score >= 60;
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
                            color: isPassed ? Colors.green : Colors.red,
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
                          color: isPassed ? Colors.green : Colors.red,
                        ),
                        Text(
                          isPassed ? 'Gửi CV thành công' : 'Chưa phù hợp',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPassed ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Đánh giá chung:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(reason, style: const TextStyle(fontSize: 14, height: 1.4)),
                const SizedBox(height: 16),
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
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
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
      backgroundColor: const Color(0xFFF3FAFF),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Phỏng vấn AI bằng giọng nói',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.job.title,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
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
      body: _errorMessage != null
          ? _buildErrorState()
          : _phase == _VoiceInterviewPhase.connecting
          ? _buildLoadingState()
          : _buildVoiceInterview(),
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startInterviewSession,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Kết nối lại',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceInterview() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          children: [
            _buildQuestionPill(),
            const Spacer(),
            _buildVoiceCenterpiece(),
            const Spacer(),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPill() {
    final label = _finished
        ? 'Đã hoàn tất'
        : _questionNumber > 0
        ? 'Câu hỏi $_questionNumber'
        : 'Chuẩn bị phỏng vấn';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _finished ? Icons.check_circle_outline : Icons.graphic_eq,
            size: 18,
            color: _finished ? Colors.green : AppColors.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCenterpiece() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildVoiceOrb(),
        const SizedBox(height: 28),
        Text(
          _headlineText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _supportingText,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700], fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 24),
        _buildVoiceMeter(),
        if (_noticeMessage != null) ...[
          const SizedBox(height: 24),
          _buildNotice(),
        ],
      ],
    );
  }

  Widget _buildVoiceOrb() {
    final activeColor = switch (_phase) {
      _VoiceInterviewPhase.listening => Colors.red,
      _VoiceInterviewPhase.processing => const Color(0xFF6366F1),
      _VoiceInterviewPhase.finished => Colors.green,
      _ => AppColors.secondary,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: _phase == _VoiceInterviewPhase.listening ? 156 : 140,
      height: _phase == _VoiceInterviewPhase.listening ? 156 : 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: activeColor.withValues(alpha: 0.12),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.34),
          width: 2,
        ),
      ),
      child: Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activeColor,
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(_orbIcon, color: Colors.white, size: 42),
        ),
      ),
    );
  }

  Widget _buildVoiceMeter() {
    final listeningStrength = ((_soundLevel + 2) / 12).clamp(0.0, 1.0);
    final isActive =
        _phase == _VoiceInterviewPhase.listening ||
        _phase == _VoiceInterviewPhase.speaking ||
        _phase == _VoiceInterviewPhase.processing;

    return SizedBox(
      height: 42,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(9, (index) {
          final distance = (index - 4).abs();
          final base = 10 + (4 - distance).clamp(0, 4) * 4;
          final activeBoost = _phase == _VoiceInterviewPhase.listening
              ? listeningStrength * 26
              : isActive
              ? (index.isEven ? 10 : 18)
              : 0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 6,
            height: (base + activeBoost).toDouble(),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.secondary
                  : AppColors.secondary.withValues(alpha: 0.26),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _noticeMessage ?? '',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final canReplay =
        _currentQuestion != null &&
        !_finished &&
        _phase != _VoiceInterviewPhase.listening &&
        _phase != _VoiceInterviewPhase.processing;
    final isListening = _phase == _VoiceInterviewPhase.listening;
    final canUseMic =
        isListening || (_phase == _VoiceInterviewPhase.ready && !_finished);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Tooltip(
              message: 'Nghe lại câu hỏi',
              child: IconButton.filledTonal(
                onPressed: canReplay ? _replayCurrentQuestion : null,
                icon: const Icon(Icons.replay_rounded),
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          button: true,
          label: isListening ? 'Dừng và gửi câu trả lời' : 'Bắt đầu trả lời',
          child: SizedBox(
            width: 96,
            height: 96,
            child: ElevatedButton(
              onPressed: canUseMic ? _handleMicPressed : null,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                backgroundColor: isListening ? Colors.red : AppColors.secondary,
                disabledBackgroundColor: Colors.grey[300],
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                elevation: canUseMic ? 8 : 0,
              ),
              child: Icon(
                isListening ? Icons.stop_rounded : Icons.mic_rounded,
                size: 42,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isListening
              ? 'Dừng và gửi'
              : _phase == _VoiceInterviewPhase.ready
              ? 'Bấm để trả lời'
              : 'Đợi AI hoàn tất',
          style: TextStyle(
            color: canUseMic ? const Color(0xFF111827) : Colors.grey[600],
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  String get _headlineText {
    return switch (_phase) {
      _VoiceInterviewPhase.connecting => 'Đang kết nối AI',
      _VoiceInterviewPhase.speaking => 'AI đang đặt câu hỏi',
      _VoiceInterviewPhase.ready => 'Đến lượt bạn trả lời',
      _VoiceInterviewPhase.listening => 'Đang nghe bạn nói',
      _VoiceInterviewPhase.processing => 'AI đang xử lý câu trả lời',
      _VoiceInterviewPhase.finished => 'Phỏng vấn hoàn tất',
    };
  }

  String get _supportingText {
    return switch (_phase) {
      _VoiceInterviewPhase.connecting =>
        'Hệ thống đang chuẩn bị phiên phỏng vấn cho vị trí này.',
      _VoiceInterviewPhase.speaking =>
        'Hãy nghe hết câu hỏi, sau đó bấm microphone để trả lời bằng giọng nói.',
      _VoiceInterviewPhase.ready =>
        'Bấm microphone và trả lời tự nhiên trong một lượt. Nội dung được xử lý ẩn để gửi tới AI.',
      _VoiceInterviewPhase.listening =>
        'Nói rõ ràng và bấm lại nút khi bạn đã trả lời xong.',
      _VoiceInterviewPhase.processing =>
        'Câu trả lời đang được gửi đến phiên phỏng vấn. Vui lòng chờ trong giây lát.',
      _VoiceInterviewPhase.finished =>
        'Hệ thống đã tổng hợp kết quả phỏng vấn của bạn.',
    };
  }

  IconData get _orbIcon {
    return switch (_phase) {
      _VoiceInterviewPhase.speaking => Icons.volume_up_rounded,
      _VoiceInterviewPhase.ready => Icons.record_voice_over_rounded,
      _VoiceInterviewPhase.listening => Icons.mic_rounded,
      _VoiceInterviewPhase.processing => Icons.auto_awesome_rounded,
      _VoiceInterviewPhase.finished => Icons.check_rounded,
      _VoiceInterviewPhase.connecting => Icons.graphic_eq_rounded,
    };
  }
}
