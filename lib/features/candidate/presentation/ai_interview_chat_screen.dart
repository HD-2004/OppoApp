import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/ai_interview_providers.dart';
import '../application/voice_rss_tts.dart';
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
  final AudioPlayer _voiceRssPlayer = AudioPlayer();

  _VoiceInterviewPhase _phase = _VoiceInterviewPhase.connecting;
  bool _speechReady = false;
  bool _ttsConfigured = false;
  bool _hasSubmittedCurrentUtterance = false;
  bool _finished = false;
  int _questionNumber = 0;
  int _playbackToken = 0;
  double _soundLevel = 0;
  String _pendingAnswer = '';
  String? _sessionId;
  String? _currentQuestion;
  String? _errorMessage;
  String? _noticeMessage;
  String? _speechLocaleId;
  bool _hasReplayedCurrent = false;

  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _configureTextToSpeech();
    _startInterviewSession();
  }

  @override
  void dispose() {
    _playbackToken++;
    _speechToText.cancel();
    _flutterTts.stop();
    unawaited(_voiceRssPlayer.dispose());
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
    _playbackToken++;
    await _speechToText.cancel();
    await _flutterTts.stop();
    await _voiceRssPlayer.stop();

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
      final experience = (user?.experience != null && user!.experience!.isNotEmpty)
          ? user.experience!
          : 'Đã có kinh nghiệm làm việc ở vị trí tương đương.';
      final education = (user?.education != null && user!.education!.isNotEmpty)
          ? user.education!
          : 'Chưa cập nhật';

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
Kinh nghiệm làm việc: $experience
Học vấn: $education
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
        _hasReplayedCurrent = false;
      });

      await _speakQuestion(question);
    } catch (_) {
      if (!mounted) return;
      await _startMockInterviewSession();
    }
  }

  Future<void> _startMockInterviewSession() async {
    final result = InterviewStartResult.websiteMockFallback(
      jobTitle: widget.job.title,
    );
    final question = result.question.trim().isNotEmpty
        ? result.question.trim()
        : 'Chào bạn, hãy bắt đầu buổi phỏng vấn.';

    if (!mounted) return;
    setState(() {
      _sessionId = mockInterviewSessionId;
      _currentQuestion = question;
      _questionNumber = 1;
      _errorMessage = null;
      _noticeMessage = null;
      _hasReplayedCurrent = false;
    });

    await _speakQuestion(question);
  }

  Future<void> _speakQuestion(String question) async {
    final spokenQuestion = question.trim();
    if (spokenQuestion.isEmpty) return;

    final playbackToken = ++_playbackToken;
    await _speechToText.cancel();
    await _flutterTts.stop();
    await _voiceRssPlayer.stop();

    if (!mounted) return;
    setState(() {
      _phase = _VoiceInterviewPhase.speaking;
      _noticeMessage = null;
      _soundLevel = 0;
    });

    try {
      final spokeWithVoiceRss = await _speakQuestionWithVoiceRss(
        spokenQuestion,
        playbackToken,
      );
      if (!spokeWithVoiceRss && _playbackToken == playbackToken) {
        await _speakQuestionWithDeviceTts(spokenQuestion);
      }
      if (!mounted ||
          _finished ||
          _phase != _VoiceInterviewPhase.speaking ||
          _playbackToken != playbackToken) {
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

  Future<bool> _speakQuestionWithVoiceRss(
    String question,
    int playbackToken,
  ) async {
    if (!VoiceRssInterviewTts.isEnabled) return false;

    try {
      final playbackComplete = _voiceRssPlayer.onPlayerComplete.first;
      final uri = VoiceRssInterviewTts.uriFor(question);
      await _voiceRssPlayer.play(UrlSource(uri.toString()));
      await playbackComplete.timeout(_voiceRssPlaybackTimeout(question));
      return true;
    } on TimeoutException {
      if (_playbackToken == playbackToken) {
        await _voiceRssPlayer.stop();
      }
      return true;
    } catch (_) {
      if (_playbackToken == playbackToken) {
        await _voiceRssPlayer.stop();
      }
      return false;
    }
  }

  Future<void> _speakQuestionWithDeviceTts(String question) async {
    await _configureTextToSpeech();
    await _flutterTts.speak(question);
  }

  Duration _voiceRssPlaybackTimeout(String question) {
    final seconds = ((question.runes.length / 8).ceil() + 12).clamp(20, 120);
    return Duration(seconds: seconds.toInt());
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

  Future<void> _stopListening() async {
    if (_phase != _VoiceInterviewPhase.listening) return;

    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _phase = _VoiceInterviewPhase.ready;
      _soundLevel = 0;
    });
  }

  Future<void> _handleMicPressed() async {
    if (_phase == _VoiceInterviewPhase.listening) {
      await _stopListening();
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

    _playbackToken++;
    await _flutterTts.stop();
    await _voiceRssPlayer.stop();

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
      setState(() {
        _pendingAnswer = recognized;
      });
    }

    if (result.finalResult) {
      unawaited(_stopListening());
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted || _phase != _VoiceInterviewPhase.listening) return;

    final normalized = status.toLowerCase();
    if (normalized == 'done' ||
        normalized == 'notlistening' ||
        normalized == 'not_listening') {
      setState(() {
        _phase = _VoiceInterviewPhase.ready;
        _soundLevel = 0;
      });
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

  Future<void> _handleSubmitAnswerPressed() async {
    final answer = _pendingAnswer.trim();
    if (answer.isEmpty ||
        _phase == _VoiceInterviewPhase.processing ||
        _finished ||
        _sessionId == null) {
      return;
    }

    _playbackToken++;
    await _flutterTts.stop();
    await _voiceRssPlayer.stop();

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
      final data = sessionId == mockInterviewSessionId
          ? InterviewAnswerResult.websiteMockFallback(
              answeredQuestionNumber: _questionNumber,
              companyName: widget.job.companyName ?? widget.job.employerName,
            )
          : await ref
                .read(aiInterviewRepositoryProvider)
                .respondInterview(sessionId: sessionId, answer: answer);

      await _handleInterviewAnswerResult(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _VoiceInterviewPhase.ready;
        _noticeMessage =
            'Không thể gửi câu trả lời đến AI. Vui lòng kiểm tra kết nối và trả lời lại.';
      });
    }
  }

  Future<void> _handleInterviewAnswerResult(InterviewAnswerResult data) async {
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
      _hasReplayedCurrent = false;
    });

    await _speakQuestion(nextQuestion);
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
              'Phỏng vấn AI cùng Oppo',
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
              : _buildChatLayout(),
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

  Widget _buildChatLayout() {
    final isListening = _phase == _VoiceInterviewPhase.listening;
    final isProcessing = _phase == _VoiceInterviewPhase.processing;
    final isSpeaking = _phase == _VoiceInterviewPhase.speaking;
    final canReplay = _currentQuestion != null && !_finished && !isListening && !isProcessing;
    final canSubmit = _pendingAnswer.trim().isNotEmpty && !isProcessing;

    return Column(
      children: [
        // VoiceQuestionCounter
        Container(
          margin: const EdgeInsets.only(top: 24, bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'Câu hỏi $_questionNumber',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
        ),

        // Center Stage (Avatar placeholder + Waveform + Status text)
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withOpacity(0.08),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.2),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _orbIcon,
                        size: 64,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildVoiceMeter(),
                  const SizedBox(height: 24),
                  Text(
                    _headlineText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _supportingText,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_noticeMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: _buildNotice(),
          ),

        // Captured Answer Preview Box
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CÂU TRẢ LỜI GHI NHẬN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (_pendingAnswer.trim().isNotEmpty)
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: Colors.green[600],
                      size: 16,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _pendingAnswer.trim().isNotEmpty
                    ? _pendingAnswer.trim()
                    : 'Bật micro và bắt đầu phát biểu để ghi nhận câu trả lời...',
                style: TextStyle(
                  fontSize: 14,
                  color: _pendingAnswer.trim().isNotEmpty
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF94A3B8),
                  fontStyle: _pendingAnswer.trim().isNotEmpty
                      ? FontStyle.normal
                      : FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        // Controls Row
        Container(
          padding: const EdgeInsets.only(bottom: 24, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildReplayButton(canReplay),
              const SizedBox(width: 24),
              _buildMicMainButton(isListening, isSpeaking, isProcessing),
              const SizedBox(width: 24),
              _buildSubmitButton(canSubmit),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplayButton(bool enabled) {
    final active = enabled && !_hasReplayedCurrent;
    return Tooltip(
      message: _hasReplayedCurrent
          ? 'Bạn đã dùng lượt nghe lại cho câu hỏi này'
          : 'Nghe lại câu hỏi (chỉ dùng 1 lần)',
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? const Color(0xFFF8FAFC)
              : const Color(0xFFCBD5E1).withOpacity(0.3),
          border: Border.all(
            color: active
                ? const Color(0xFFE2E8F0)
                : const Color(0xFFE2E8F0).withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: IconButton(
          icon: Icon(
            Icons.volume_up_rounded,
            color: active ? AppColors.secondary : const Color(0xFF94A3B8),
          ),
          onPressed: active ? _replayCurrentQuestion : null,
        ),
      ),
    );
  }

  Widget _buildMicMainButton(
    bool isListening,
    bool isSpeaking,
    bool isProcessing,
  ) {
    final disabled = isProcessing || isSpeaking;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isListening ? Colors.red : AppColors.secondary).withOpacity(
              disabled ? 0.05 : 0.25,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: isListening ? Colors.red : AppColors.secondary,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        onPressed: disabled ? null : _handleMicPressed,
        child: Icon(
          isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool enabled) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        onPressed: enabled ? _handleSubmitAnswerPressed : null,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gửi & Tiếp tục',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 18),
          ],
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
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(9, (index) {
          final distance = (index - 4).abs();
          final base = 8 + (4 - distance).clamp(0, 4) * 3;
          final activeBoost = _phase == _VoiceInterviewPhase.listening
              ? listeningStrength * 20
              : isActive
              ? (index.isEven ? 6 : 12)
              : 0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 4,
            height: (base + activeBoost).toDouble(),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.secondary
                  : AppColors.secondary.withOpacity(0.26),
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
          color: const Color(0xFFF59E0B).withOpacity(0.3),
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

  String get _headlineText {
    return switch (_phase) {
      _VoiceInterviewPhase.connecting => 'Đang kết nối phòng phỏng vấn...',
      _VoiceInterviewPhase.speaking => 'AI đang nói...',
      _VoiceInterviewPhase.ready => 'Nhấn nút micro để trả lời',
      _VoiceInterviewPhase.listening => '🎙️ Đang lắng nghe bạn...',
      _VoiceInterviewPhase.processing => 'AI đang xử lý...',
      _VoiceInterviewPhase.finished => 'Phỏng vấn hoàn tất',
    };
  }

  String get _supportingText {
    return switch (_phase) {
      _VoiceInterviewPhase.connecting => 'Vui lòng chờ trong giây lát',
      _VoiceInterviewPhase.speaking => 'Hãy lắng nghe câu hỏi của AI',
      _VoiceInterviewPhase.ready => 'Bấm nút micro bên dưới để bắt đầu nói',
      _VoiceInterviewPhase.listening => 'Nói rõ ràng câu trả lời của bạn',
      _VoiceInterviewPhase.processing => 'Vui lòng đợi trong giây lát',
      _VoiceInterviewPhase.finished => 'Hệ thống đã tổng hợp kết quả của bạn',
    };
  }
}
