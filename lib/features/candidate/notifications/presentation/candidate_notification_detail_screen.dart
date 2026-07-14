import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_application_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/application_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/application/notification_navigation.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/candidate_notification.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_type.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/digital_wallet_screen.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/user_profile_screen.dart';
import 'package:oppo_temp_jobs/features/messaging/presentation/pages/messages_screen.dart';

final _candidateApplicationsForNotificationProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) {
      return ref
          .watch(applicationRepositoryProvider)
          .getCandidateApplications(userId);
    });

class CandidateNotificationDetailScreen extends ConsumerWidget {
  const CandidateNotificationDetailScreen({
    super.key,
    required this.notification,
  });

  final CandidateNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = resolveCandidateNotificationDestination(notification);
    final theme = Theme.of(context);
    final tone = _toneFor(notification.type);
    final relatedJobs = _needsRelatedJobLookup(notification)
        ? [
            ...?ref.watch(activeJobsProvider).asData?.value,
            ...?ref.watch(activeQuickJobsProvider).asData?.value,
          ]
        : const <JobPost>[];
    final senderName = _senderName(notification, relatedJobs: relatedJobs);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: BackButton(color: AppColors.textPrimaryFor(context)),
        title: Text(
          'Chi tiết thông báo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryFor(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _NotificationHeader(
            notification: notification,
            tone: tone,
            senderName: senderName,
          ),
          const SizedBox(height: 14),
          _LetterMetadataSection(
            notification: notification,
            tone: tone,
            senderName: senderName,
          ),
          if (destination.hasAction) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _openDestination(context, destination),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(destination.label),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openDestination(
    BuildContext context,
    CandidateNotificationDestination destination,
  ) {
    switch (destination.kind) {
      case CandidateNotificationDestinationKind.route:
        final route = destination.route;
        if (route != null) {
          context.go(route);
        }
        return;
      case CandidateNotificationDestinationKind.applicationDetail:
      case CandidateNotificationDestinationKind.applicationList:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CandidateApplicationNotificationDetailScreen(
              applicationId: destination.entityId,
            ),
          ),
        );
        return;
      case CandidateNotificationDestinationKind.messages:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MessagesScreen()));
        return;
      case CandidateNotificationDestinationKind.wallet:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const DigitalWalletScreen()));
        return;
      case CandidateNotificationDestinationKind.profile:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const UserProfileScreen()));
        return;
      case CandidateNotificationDestinationKind.notificationDetail:
        break;
    }
  }
}

class CandidateApplicationNotificationDetailScreen extends ConsumerWidget {
  const CandidateApplicationNotificationDetailScreen({
    super.key,
    this.applicationId,
  });

  final String? applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authControllerProvider).asData?.value.user?.userId;
    final id = userId?.trim();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: BackButton(color: AppColors.textPrimaryFor(context)),
        title: Text(
          applicationId == null ? 'Hồ sơ ứng tuyển' : 'Chi tiết ứng tuyển',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryFor(context),
          ),
        ),
      ),
      body: id == null || id.isEmpty
          ? const _ApplicationStateMessage(
              icon: Icons.lock_outline_rounded,
              message: 'Vui lòng đăng nhập để xem hồ sơ ứng tuyển.',
            )
          : ref
                .watch(_candidateApplicationsForNotificationProvider(id))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const _ApplicationStateMessage(
                    icon: Icons.wifi_off_rounded,
                    message: 'Không thể tải hồ sơ ứng tuyển.',
                  ),
                  data: (applications) {
                    final targetId = applicationId?.trim();
                    if (targetId == null || targetId.isEmpty) {
                      return _ApplicationList(applications: applications);
                    }

                    final application = _findApplication(
                      applications,
                      targetId,
                    );
                    if (application == null) {
                      return _ApplicationStateMessage(
                        icon: Icons.search_off_rounded,
                        message:
                            'Không tìm thấy hồ sơ ứng tuyển với mã $targetId.',
                      );
                    }

                    return _ApplicationDetail(application: application);
                  },
                ),
    );
  }
}

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({
    required this.notification,
    required this.tone,
    required this.senderName,
  });

  final CandidateNotification notification;
  final _NotificationTone tone;
  final String senderName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const Key('notification-tone-indicator'),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tone.softColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _iconFor(notification.type),
              color: tone.color,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _personalizeNotificationText(notification.title, senderName),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryFor(context),
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _personalizeNotificationText(notification.body, senderName),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryFor(context),
                    height: 1.48,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterMetadataSection extends StatelessWidget {
  const _LetterMetadataSection({
    required this.notification,
    required this.tone,
    required this.senderName,
  });

  final CandidateNotification notification;
  final _NotificationTone tone;
  final String senderName;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      borderColor: tone.borderColor,
      children: [
        _DetailRow(
          icon: Icons.outbox_rounded,
          label: 'Người gửi',
          value: senderName,
          iconColor: tone.color,
        ),
        _DetailRow(
          icon: Icons.person_outline_rounded,
          label: 'Người nhận',
          value: _receiverName(notification),
          iconColor: tone.color,
        ),
        _DetailRow(
          icon: Icons.calendar_today_outlined,
          label: 'Ngày',
          value: _formatDateOnly(notification.createdAt),
          iconColor: tone.color,
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.children, this.borderColor});

  final List<Widget> children;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? AppColors.borderFor(context)),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: iconColor ?? AppColors.textMutedFor(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMutedFor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryFor(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationList extends StatelessWidget {
  const _ApplicationList({required this.applications});

  final List<Map<String, dynamic>> applications;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return const _ApplicationStateMessage(
        icon: Icons.inbox_outlined,
        message: 'Bạn chưa có hồ sơ ứng tuyển nào.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: applications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final application = applications[index];
        final id = applicationIdFromApplication(application);
        return Material(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: id == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CandidateApplicationNotificationDetailScreen(
                            applicationId: id,
                          ),
                    ),
                  ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _firstText(application, const [
                            'jobTitle',
                            'title',
                          ], fallback: 'Công việc'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryFor(context),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _firstText(application, const [
                            'employerName',
                            'companyName',
                          ], fallback: 'Nhà tuyển dụng'),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryFor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusLabel(application['status']),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ApplicationDetail extends StatelessWidget {
  const _ApplicationDetail({required this.application});

  final Map<String, dynamic> application;

  @override
  Widget build(BuildContext context) {
    final applicationId = applicationIdFromApplication(application) ?? '---';
    final jobTitle = _firstText(application, const [
      'jobTitle',
      'title',
    ], fallback: 'Công việc');
    final company = _firstText(application, const [
      'employerName',
      'companyName',
    ], fallback: 'Nhà tuyển dụng');
    final cvFilename = _firstText(application, const [
      'cvFilename',
      'cvFileName',
      'candidateCvFilename',
      'candidateCVFilename',
    ]);
    final aiScore = _firstText(application, const ['aiScreeningScore']);
    final aiResult = _firstText(application, const [
      'aiScreeningResult',
      'cvScreeningResult',
      'screeningResult',
    ]);
    final aiReason = _firstText(application, const [
      'aiScreeningReason',
      'cvScreeningReason',
      'screeningReason',
    ]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderFor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                jobTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimaryFor(context),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                company,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondaryFor(context),
                ),
              ),
              const SizedBox(height: 12),
              _StatusPill(status: application['status']),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _DetailSection(
          children: [
            _DetailRow(
              icon: Icons.tag_rounded,
              label: 'Mã ứng tuyển',
              value: applicationId,
            ),
            _DetailRow(
              icon: Icons.work_outline_rounded,
              label: 'Mã công việc',
              value: _firstText(application, const [
                'jobId',
                'idJob',
                'jobID',
              ], fallback: '---'),
            ),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label: 'Ngày ứng tuyển',
              value: _formatRawDate(
                application['appliedAt'] ?? application['createdAt'],
              ),
            ),
            _DetailRow(
              icon: Icons.update_rounded,
              label: 'Cập nhật',
              value: _formatRawDate(application['updatedAt']),
            ),
            if (cvFilename.isNotEmpty)
              _DetailRow(
                icon: Icons.attach_file_rounded,
                label: 'CV',
                value: cvFilename,
              ),
          ],
        ),
        if (aiScore.isNotEmpty ||
            aiResult.isNotEmpty ||
            aiReason.isNotEmpty) ...[
          const SizedBox(height: 14),
          _DetailSection(
            children: [
              if (aiScore.isNotEmpty)
                _DetailRow(
                  icon: Icons.speed_rounded,
                  label: 'Điểm sàng lọc AI',
                  value: aiScore,
                ),
              if (aiResult.isNotEmpty)
                _DetailRow(
                  icon: Icons.fact_check_outlined,
                  label: 'Kết quả sàng lọc',
                  value: _statusLabel(aiResult),
                ),
              if (aiReason.isNotEmpty)
                _DetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Ghi chú',
                  value: aiReason,
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: const Text('Mở tin nhắn'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final Object? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.softPrimaryFor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ApplicationStateMessage extends StatelessWidget {
  const _ApplicationStateMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.softPrimaryFor(context),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryFor(context),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic>? _findApplication(
  List<Map<String, dynamic>> applications,
  String applicationId,
) {
  final target = applicationId.trim();
  for (final application in applications) {
    final id = applicationIdFromApplication(application);
    if (id == target) return application;
  }
  return null;
}

IconData _iconFor(CandidateNotificationType type) {
  return switch (type) {
    CandidateNotificationType.profileViewed => Icons.visibility_outlined,
    CandidateNotificationType.newMessage => Icons.chat_bubble_outline_rounded,
    CandidateNotificationType.cvAccepted ||
    CandidateNotificationType.shiftAccepted ||
    CandidateNotificationType.shiftConfirmed ||
    CandidateNotificationType.shiftCompleted ||
    CandidateNotificationType.paymentReleased ||
    CandidateNotificationType.kycApproved => Icons.check_circle_outline_rounded,
    CandidateNotificationType.cvRejected ||
    CandidateNotificationType.paymentFailed ||
    CandidateNotificationType.kycRejected => Icons.cancel_outlined,
    CandidateNotificationType.jobRecommended => Icons.work_outline_rounded,
    CandidateNotificationType.system => Icons.notifications_none_rounded,
  };
}

_NotificationTone _toneFor(CandidateNotificationType type) {
  return switch (type) {
    CandidateNotificationType.cvAccepted ||
    CandidateNotificationType.shiftAccepted ||
    CandidateNotificationType.shiftConfirmed ||
    CandidateNotificationType.shiftCompleted ||
    CandidateNotificationType.paymentReleased ||
    CandidateNotificationType.kycApproved => const _NotificationTone(
      color: Color(0xFF16A34A),
      softColor: Color(0xFFEAF7EE),
      borderColor: Color(0xFFBBF7D0),
    ),
    CandidateNotificationType.cvRejected ||
    CandidateNotificationType.paymentFailed ||
    CandidateNotificationType.kycRejected => const _NotificationTone(
      color: Color(0xFFDC2626),
      softColor: Color(0xFFFEE2E2),
      borderColor: Color(0xFFFECACA),
    ),
    _ => const _NotificationTone(
      color: AppColors.primary,
      softColor: Color(0xFFEFF6FF),
      borderColor: Color(0xFFDDE6F3),
    ),
  };
}

class _NotificationTone {
  const _NotificationTone({
    required this.color,
    required this.softColor,
    required this.borderColor,
  });

  final Color color;
  final Color softColor;
  final Color borderColor;
}

const _senderNameKeys = [
  'senderName',
  'sender_name',
  'senderDisplayName',
  'sender_display_name',
  'fromName',
  'from_name',
  'fromDisplayName',
  'from_display_name',
  'sender',
  'from',
  'employerName',
  'employer_name',
  'employerDisplayName',
  'employer_display_name',
  'companyName',
  'company_name',
  'company',
  'businessName',
  'business_name',
  'organizationName',
  'organization_name',
];

const _senderNestedKeys = [
  'sender',
  'from',
  'employer',
  'company',
  'organization',
  'job',
];

const _jobIdKeys = [
  'jobId',
  'jobID',
  'job_id',
  'idJob',
  'id_job',
  'jobPostId',
  'job_post_id',
  'postId',
  'post_id',
];

const _employerIdKeys = [
  'employerId',
  'employerID',
  'employer_id',
  'companyId',
  'company_id',
  'ownerId',
  'owner_id',
];

String _senderName(
  CandidateNotification notification, {
  List<JobPost> relatedJobs = const [],
}) {
  final sender = _firstSpecificText(notification.data, _senderNameKeys);
  if (sender.isNotEmpty) return sender;

  final nestedSender = _firstSpecificNestedText(
    notification.data,
    _senderNestedKeys,
    _senderNameKeys,
  );
  if (nestedSender.isNotEmpty) return nestedSender;

  final senderFromJob = _senderNameFromRelatedJob(notification, relatedJobs);
  if (senderFromJob.isNotEmpty) return senderFromJob;

  final senderFromText = _senderNameFromNotificationText(notification);
  if (senderFromText.isNotEmpty) return senderFromText;

  if (_isSystemNotification(notification.type)) {
    return 'Hệ thống';
  }
  return 'Người gửi chưa xác định';
}

bool _needsRelatedJobLookup(CandidateNotification notification) {
  if (_firstSpecificText(notification.data, _senderNameKeys).isNotEmpty) {
    return false;
  }
  if (_firstSpecificNestedText(
    notification.data,
    _senderNestedKeys,
    _senderNameKeys,
  ).isNotEmpty) {
    return false;
  }
  return _valuesForKeys(notification.data, _jobIdKeys).isNotEmpty ||
      _valuesForKeys(notification.data, _employerIdKeys).isNotEmpty;
}

String _senderNameFromRelatedJob(
  CandidateNotification notification,
  List<JobPost> relatedJobs,
) {
  if (relatedJobs.isEmpty) return '';

  final jobIds = _valuesForKeys(
    notification.data,
    _jobIdKeys,
  ).map(_normalizeLookupValue).where((value) => value.isNotEmpty).toSet();
  final employerIds = _valuesForKeys(
    notification.data,
    _employerIdKeys,
  ).map(_normalizeLookupValue).where((value) => value.isNotEmpty).toSet();

  JobPost? match;
  if (jobIds.isNotEmpty) {
    for (final job in relatedJobs) {
      final ids = {
        _normalizeLookupValue(job.id),
        _normalizeLookupValue(job.idJob),
      };
      if (ids.any(jobIds.contains)) {
        match = job;
        break;
      }
    }
  }

  if (match == null && employerIds.isNotEmpty) {
    for (final job in relatedJobs) {
      if (employerIds.contains(_normalizeLookupValue(job.employerId))) {
        match = job;
        break;
      }
    }
  }

  if (match == null) return '';
  return _specificJobCompanyName(match);
}

String _specificJobCompanyName(JobPost job) {
  final companyName = job.companyName?.trim() ?? '';
  if (_isSpecificPartyLabel(companyName)) return companyName;

  final employerName = job.employerName.trim();
  if (_isSpecificPartyLabel(employerName)) return employerName;

  return '';
}

String _senderNameFromNotificationText(CandidateNotification notification) {
  for (final text in [notification.body, notification.title]) {
    final candidate = _extractSpecificSenderFromText(text);
    if (candidate.isNotEmpty) return candidate;
  }
  return '';
}

String _extractSpecificSenderFromText(String text) {
  final patterns = [
    RegExp(
      r'\btại\s+(.+?)(?=\s+(?:đã|sẽ|vừa|cho|chưa|không|sớm|ở)\b|[,.]|$)',
      caseSensitive: false,
      unicode: true,
    ),
    RegExp(
      r'\bđược\s+(.+?)\s+(?:chấp nhận|duyệt|thông qua|từ chối)\b',
      caseSensitive: false,
      unicode: true,
    ),
    RegExp(
      r'\btừ\s+(.+?)(?=\s+(?:vừa|đã|gửi)\b|[,.]|$)',
      caseSensitive: false,
      unicode: true,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    final value = match?.group(1)?.trim() ?? '';
    if (_isSpecificPartyLabel(value)) return value;
  }
  return '';
}

String _personalizeNotificationText(String text, String senderName) {
  if (!_isSpecificPartyLabel(senderName)) return text;
  return text
      .replaceAll(
        RegExp(r'\bNTD\b', caseSensitive: false, unicode: true),
        senderName,
      )
      .replaceAll('Nhà tuyển dụng', senderName)
      .replaceAll('nhà tuyển dụng', senderName);
}

bool _isSystemNotification(CandidateNotificationType type) {
  return switch (type) {
    CandidateNotificationType.system ||
    CandidateNotificationType.kycApproved ||
    CandidateNotificationType.kycRejected ||
    CandidateNotificationType.paymentReleased ||
    CandidateNotificationType.paymentFailed => true,
    _ => false,
  };
}

bool _isSpecificPartyLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  const genericLabels = {
    'ntd',
    'nha tuyen dung',
    'nhà tuyển dụng',
    'employer',
    'company',
    'công ty',
    'nguoi gui',
    'người gửi',
    'nguoi gui chua xac dinh',
    'người gửi chưa xác định',
    'sender',
    'he thong',
    'hệ thống',
    'system',
    'ban',
    'bạn',
  };
  return !genericLabels.contains(normalized);
}

String _firstSpecificText(Map<String, dynamic> map, List<String> keys) {
  final text = _firstText(map, keys);
  return _isSpecificPartyLabel(text) ? text : '';
}

String _firstSpecificNestedText(
  Map<String, dynamic> map,
  List<String> nestedKeys,
  List<String> valueKeys,
) {
  for (final key in nestedKeys) {
    final nested = map[key];
    if (nested is Map) {
      final text = _firstSpecificText(
        Map<String, dynamic>.from(nested),
        valueKeys,
      );
      if (text.isNotEmpty) return text;
    }
  }
  return '';
}

List<String> _valuesForKeys(Map<String, dynamic> map, List<String> keys) {
  final values = <String>[];
  for (final key in keys) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) values.add(value);
  }
  for (final nestedKey in _senderNestedKeys) {
    final nested = map[nestedKey];
    if (nested is Map) {
      values.addAll(_valuesForKeys(Map<String, dynamic>.from(nested), keys));
    }
  }
  return values;
}

String _normalizeLookupValue(String value) => value.trim().toLowerCase();

String _receiverName(CandidateNotification notification) {
  return _firstText(notification.data, const [
    'recipientName',
    'recipient_name',
    'receiverName',
    'receiver_name',
    'toName',
    'to_name',
    'to',
    'candidateName',
    'candidate_name',
    'fullName',
    'full_name',
  ], fallback: 'Bạn');
}

String _formatDateOnly(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return '---';
  return DateFormat('dd/MM/yyyy').format(value.toLocal());
}

String _formatDateTime(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return '---';
  return DateFormat('HH:mm, dd/MM/yyyy').format(value.toLocal());
}

String _formatRawDate(Object? value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return '---';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return _formatDateTime(parsed);
}

String _firstText(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final text = map[key]?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

String _statusLabel(Object? value) {
  final normalized = value
      ?.toString()
      .trim()
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]}_${match[2]}',
      )
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_');

  return switch (normalized) {
    'pending' => 'Đang chờ duyệt',
    'approved' || 'cv_accepted' || 'accepted' => 'Đã chấp nhận',
    'rejected' || 'cv_rejected' => 'Đã từ chối',
    'completed_pending_candidate' => 'Chờ xác nhận hoàn thành',
    'completed' => 'Đã hoàn thành',
    'archived' => 'Đã lưu trữ',
    'pass' => 'Đạt',
    'review' => 'Cần xem xét',
    'failed' || 'fail' => 'Không đạt',
    _ =>
      value?.toString().trim().isNotEmpty == true
          ? value!.toString().trim()
          : '---',
  };
}
