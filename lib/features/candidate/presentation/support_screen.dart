import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user_profile.dart';
import '../data/support_feedback_repository.dart';

final supportFeedbackRepositoryProvider = Provider<SupportFeedbackRepository>((
  ref,
) {
  return SupportFeedbackRepository();
});

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  static const _phone = '0563 518 922';
  static const _email = 'oppohiringplatform@gmail.com';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isVietnamese = l10n.isVietnamese;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.support)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SupportCard(
              icon: Icons.support_agent_outlined,
              title: l10n.text('contactSupport'),
              subtitle: isVietnamese
                  ? 'Hotline, email và thời gian làm việc'
                  : 'Hotline, email and working hours',
              onTap: () => _showContactDetails(isVietnamese),
            ),
            const SizedBox(height: 12),
            _SupportCard(
              icon: Icons.help_outline,
              title: 'FAQ',
              subtitle: isVietnamese
                  ? 'Câu hỏi thường gặp khi sử dụng ứng dụng'
                  : 'Frequently asked questions about the app',
              onTap: () => _showFaq(isVietnamese),
            ),
            const SizedBox(height: 12),
            _SupportCard(
              icon: Icons.report_problem_outlined,
              title: isVietnamese ? 'Báo cáo sự cố' : 'Report a problem',
              subtitle: isVietnamese
                  ? 'Gửi lỗi hoặc góp ý trực tiếp đến quản trị viên'
                  : 'Send bugs or feedback directly to administrators',
              onTap: () => _openFeedbackForm(isVietnamese),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showContactDetails(bool isVietnamese) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVietnamese ? 'Liên hệ hỗ trợ trực tiếp' : 'Direct support',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _ContactRow(
                  icon: Icons.phone_outlined,
                  label: 'Hotline/Zalo',
                  value: _phone,
                  onCopy: () => _copyContact(_phone, isVietnamese),
                ),
                _ContactRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: _email,
                  onCopy: () => _copyContact(_email, isVietnamese),
                ),
                _ContactRow(
                  icon: Icons.schedule_outlined,
                  label: isVietnamese ? 'Giờ làm việc' : 'Working hours',
                  value: isVietnamese
                      ? '8:00 - 18:00 (Thứ 2 - Thứ 7)'
                      : '8:00 AM - 6:00 PM (Mon - Sat)',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyContact(String value, bool isVietnamese) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isVietnamese ? 'Đã sao chép $value' : 'Copied $value'),
      ),
    );
  }

  Future<void> _showFaq(bool isVietnamese) {
    final faqs = isVietnamese ? _vietnameseFaqs : _englishFaqs;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    isVietnamese
                        ? 'Câu hỏi thường gặp'
                        : 'Frequently asked questions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                for (final faq in faqs)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      title: Text(faq.question),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(faq.answer)],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFeedbackForm(bool isVietnamese) async {
    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVietnamese
                ? 'Vui lòng đăng nhập để gửi báo cáo.'
                : 'Please sign in to submit a report.',
          ),
        ),
      );
      return;
    }

    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _FeedbackFormScreen(
          user: user,
          repository: ref.read(supportFeedbackRepositoryProvider),
          isVietnamese: isVietnamese,
        ),
      ),
    );

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isVietnamese
                ? 'Đã gửi đến quản trị viên. Chúng tôi sẽ phản hồi sớm nhất.'
                : 'Sent to administrators. We will respond as soon as possible.',
          ),
        ),
      );
    }
  }
}

class _FeedbackFormScreen extends StatefulWidget {
  const _FeedbackFormScreen({
    required this.user,
    required this.repository,
    required this.isVietnamese,
  });

  final AuthUserProfile user;
  final SupportFeedbackRepository repository;
  final bool isVietnamese;

  @override
  State<_FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<_FeedbackFormScreen> {
  static const _maxImages = 3;
  static const _maxImageBytes = 5 * 1024 * 1024;

  final _commentController = TextEditingController();
  final _picker = ImagePicker();
  final List<_SelectedImage> _images = [];
  String _category = 'bug';
  bool _submitting = false;

  bool get _vi => widget.isVietnamese;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) return;

    final selected = await _picker.pickMultiImage();
    for (final image in selected.take(remaining)) {
      final bytes = await image.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        if (!mounted) return;
        _showMessage(
          _vi
              ? 'Ảnh "${image.name}" vượt quá 5 MB.'
              : 'Image "${image.name}" exceeds 5 MB.',
        );
        continue;
      }
      _images.add(
        _SelectedImage(
          name: image.name,
          attachment: SupportAttachment(
            bytes: bytes,
            mimeType: image.mimeType ?? _mimeTypeForName(image.name),
          ),
        ),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      _showMessage(
        _vi
            ? 'Vui lòng mô tả chi tiết sự cố hoặc góp ý.'
            : 'Please describe the problem or feedback.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.repository.submit(
        category: _category,
        comment: comment,
        user: widget.user,
        attachments: _images.map((item) => item.attachment).toList(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on SupportFeedbackException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
          _vi
              ? 'Đã xảy ra lỗi khi gửi. Vui lòng thử lại.'
              : 'An error occurred while sending. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_vi ? 'Gửi góp ý hỗ trợ' : 'Send feedback')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _vi ? 'Phân loại' : 'Category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'bug',
                  icon: const Icon(Icons.bug_report_outlined),
                  label: Text(_vi ? 'Báo lỗi' : 'Bug'),
                ),
                ButtonSegment(
                  value: 'suggestion',
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(_vi ? 'Góp ý' : 'Suggestion'),
                ),
                ButtonSegment(
                  value: 'other',
                  icon: const Icon(Icons.more_horiz),
                  label: Text(_vi ? 'Khác' : 'Other'),
                ),
              ],
              selected: {_category},
              onSelectionChanged: _submitting
                  ? null
                  : (value) => setState(() => _category = value.first),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              enabled: !_submitting,
              minLines: 6,
              maxLines: 10,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: _vi ? 'Nội dung chi tiết' : 'Detailed description',
                hintText: _vi
                    ? 'Mô tả sự cố, thời điểm xảy ra và các bước đã thực hiện...'
                    : 'Describe the issue, when it happened, and steps taken...',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _submitting || _images.length >= _maxImages
                  ? null
                  : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _vi
                    ? 'Đính kèm ảnh (${_images.length}/$_maxImages)'
                    : 'Attach images (${_images.length}/$_maxImages)',
              ),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var index = 0; index < _images.length; index++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.image_outlined),
                  title: Text(
                    _images[index].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _images.removeAt(index)),
                    icon: const Icon(Icons.close),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _submitting
                    ? (_vi ? 'Đang gửi...' : 'Sending...')
                    : (_vi ? 'Gửi đến quản trị viên' : 'Send to administrator'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: SelectableText(value),
      trailing: onCopy == null
          ? null
          : IconButton(
              onPressed: onCopy,
              tooltip: 'Copy',
              icon: const Icon(Icons.copy_outlined),
            ),
    );
  }
}

class _FaqItem {
  const _FaqItem(this.question, this.answer);

  final String question;
  final String answer;
}

class _SelectedImage {
  const _SelectedImage({required this.name, required this.attachment});

  final String name;
  final SupportAttachment attachment;
}

String _mimeTypeForName(String name) {
  final extension = name.split('.').last.toLowerCase();
  return switch (extension) {
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}

const _vietnameseFaqs = [
  _FaqItem(
    'Làm thế nào để ứng tuyển công việc?',
    'Mở công việc bạn quan tâm, chọn "Ứng tuyển ngay", chọn CV và xác nhận.',
  ),
  _FaqItem(
    'Xác thực KYC để làm gì?',
    'KYC tăng độ tin cậy của tài khoản, hỗ trợ ứng tuyển công việc có yêu cầu cao và sử dụng các tính năng tài chính.',
  ),
  _FaqItem(
    'Ví điện tử hoạt động như thế nào?',
    'Ví lưu thu nhập từ công việc đã hoàn thành. Bạn có thể liên kết tài khoản ngân hàng để rút tiền.',
  ),
];

const _englishFaqs = [
  _FaqItem(
    'How do I apply for a job?',
    'Open the job, select "Apply now", choose your CV, and confirm.',
  ),
  _FaqItem(
    'Why should I complete KYC?',
    'KYC improves account trust and unlocks jobs with higher requirements and financial features.',
  ),
  _FaqItem(
    'How does the digital wallet work?',
    'The wallet stores earnings from completed jobs. Link a bank account to withdraw funds.',
  ),
];
