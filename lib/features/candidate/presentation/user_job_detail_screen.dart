import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../employer/presentation/company_profile_screen.dart';
import '../application/jobs_providers.dart';
import '../domain/job_post.dart';
import '../domain/job_recruitment_window.dart';
import '../domain/job_work_schedule.dart';
import '../data/aws_job_repository.dart';

/// Màn hình chi tiết công việc — đồng bộ dữ liệu với website qua cùng backend.
/// Dữ liệu: AwsJobRepository → REST API AWS.
/// Không có mock/fake data — mọi field hiển thị từ [JobPost] backend thật.
class UserJobDetailScreen extends ConsumerStatefulWidget {
  const UserJobDetailScreen({
    super.key,
    required this.job,
    required this.onApplyPressed,
    this.showApplyButton = true,
  });

  final JobPost job;
  final VoidCallback onApplyPressed;
  final bool showApplyButton;

  @override
  ConsumerState<UserJobDetailScreen> createState() =>
      _UserJobDetailScreenState();
}

class _UserJobDetailScreenState extends ConsumerState<UserJobDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Increment view count when this screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(jobRepositoryProvider)
          .incrementJobViews(
            widget.job.idJob,
            isQuickJob: widget.job.isQuickJob,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRecruitable = isJobPostRecruitable(widget.job);
    final isExpired = isJobPostExpired(widget.job);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Scrollable content ─────────────────────────────────────
          CustomScrollView(
            slivers: [
              // ── Hero image + AppBar ──────────────────────────────
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: AppColors.primary,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                leading: _CircleIconBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroBanner(job: widget.job),
                ),
              ),

              // ── Body content ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick info cards
                    _QuickInfoSection(job: widget.job),
                    if (_shouldShowWorkScheduleCalendar(widget.job))
                      _WorkScheduleCalendarSection(job: widget.job),

                    if (isExpired) const _ExpiredJobNotice(),

                    const _SectionDivider(),

                    // Mô tả công việc
                    if (widget.job.description.isNotEmpty)
                      _DescriptionSection(text: widget.job.description),

                    // Yêu cầu
                    if (widget.job.requirements != null &&
                        widget.job.requirements!.isNotEmpty) ...[
                      const _SectionDivider(),
                      _RequirementsSection(text: widget.job.requirements!),
                    ],

                    // Quyền lợi
                    if (widget.job.benefits != null &&
                        widget.job.benefits!.isNotEmpty) ...[
                      const _SectionDivider(),
                      _BenefitsSection(text: widget.job.benefits!),
                    ],

                    // Thông tin nhà tuyển dụng
                    const _SectionDivider(),
                    _EmployerInfoCard(job: widget.job),

                    // Vị trí tương tự — từ tags/jobType, không mock
                    const _SectionDivider(),
                    _SimilarPositions(job: widget.job),

                    // Bottom spacing cho sticky button
                    // Khi bật phỏng vấn AI, thanh đáy cao hơn (có thêm khối lưu ý)
                    // nên cần chừa nhiều khoảng đệm hơn để không che nội dung.
                    SizedBox(
                      height: widget.showApplyButton
                          ? (widget.job.isAiScreeningEnabled ? 180 : 110)
                          : 24,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Sticky bottom apply button ─────────────────────────
          if (widget.showApplyButton)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyApplyBar(
                onApply: widget.onApplyPressed,
                isAiEnabled: widget.job.isAiScreeningEnabled,
                isRecruitable: isRecruitable,
                isExpired: isExpired,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.job});

  final JobPost job;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        job.employerAvatarUrl != null && job.employerAvatarUrl!.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background — ảnh công ty từ S3 hoặc gradient mặc định
        hasImage
            ? Image.network(
                job.employerAvatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _DefaultHeroBg(),
              )
            : const _DefaultHeroBg(),

        // Dark gradient overlay
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Color(0xCC000000),
              ],
              stops: [0, 0.4, 1],
            ),
          ),
        ),

        // Title + company + badge
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badges row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _badgeColor(job.jobType),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _badgeLabel(job.jobType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (job.isAiScreeningEnabled) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        border: Border.all(color: const Color(0xFFC084FC)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF7C3AED),
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Phỏng vấn AI',
                            style: TextStyle(
                              color: Color(0xFF6D28D9),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Job title
              Text(
                job.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Company name
              Text(
                job.companyName ?? job.employerName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _badgeColor(JobPostType type) {
    return switch (type) {
      JobPostType.urgent => const Color(0xFFF97316),
      JobPostType.partTime => const Color(0xFF7C3AED),
      JobPostType.fullTime => AppColors.primary,
    };
  }

  String _badgeLabel(JobPostType type) {
    return switch (type) {
      JobPostType.urgent => 'Tuyển gấp',
      JobPostType.partTime => 'Part-time',
      JobPostType.fullTime => 'Full-time',
    };
  }
}

class _DefaultHeroBg extends StatelessWidget {
  const _DefaultHeroBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.business_rounded, size: 72, color: Colors.white24),
      ),
    );
  }
}

// ── Circle icon button trên AppBar ────────────────────────────────────────────

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ── Quick info section ────────────────────────────────────────────────────────

class _QuickInfoSection extends StatelessWidget {
  const _QuickInfoSection({required this.job});

  final JobPost job;

  @override
  Widget build(BuildContext context) {
    final recruitmentWindow = recruitmentWindowValue(job);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Column(
        children: [
          if (job.salary.isNotEmpty)
            _InfoTile(
              icon: Icons.payments_outlined,
              iconBg: AppColors.primarySoft,
              iconColor: AppColors.primary,
              label: 'MỨC LƯƠNG',
              value: job.salary,
              valueStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          if (job.location.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.location_on_outlined,
              iconBg: AppColors.primarySoft,
              iconColor: AppColors.primary,
              label: 'ĐỊA ĐIỂM',
              value: job.location,
            ),
          ],
          const SizedBox(height: 10),
          _InfoTile(
            icon: Icons.calendar_month_outlined,
            iconBg: AppColors.primarySoft,
            iconColor: AppColors.primary,
            label: 'Thời gian tuyển dụng',
            value: recruitmentWindow,
          ),
        ],
      ),
    );
  }
}

bool _shouldShowWorkScheduleCalendar(JobPost job) {
  return job.isQuickJob || job.jobType == JobPostType.urgent;
}

class _WorkScheduleCalendarSection extends StatefulWidget {
  const _WorkScheduleCalendarSection({required this.job});

  final JobPost job;

  @override
  State<_WorkScheduleCalendarSection> createState() =>
      _WorkScheduleCalendarSectionState();
}

class _WorkScheduleCalendarSectionState
    extends State<_WorkScheduleCalendarSection> {
  late DateTime _visibleMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final initial = workScheduleInitialMonth(widget.job) ?? DateTime.now();
    _visibleMonth = DateTime(initial.year, initial.month);
    _selectedDate =
        _firstScheduledDateInMonth(_visibleMonth) ??
        firstScheduledWorkDate(widget.job);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedDate = _selectedDate;
    final selectedTimes = selectedDate == null
        ? const <String>[]
        : _displayShiftTimesForDate(widget.job, selectedDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Lịch làm việc',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${selectedTimes.length} ca',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                _CalendarMonthHeader(
                  month: _visibleMonth,
                  onPrevious: () => _moveMonth(-1),
                  onNext: () => _moveMonth(1),
                ),
                const _CalendarWeekdayHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                  child: _CalendarDayGrid(
                    month: _visibleMonth,
                    selectedDate: selectedDate,
                    job: widget.job,
                    onDateSelected: (date) {
                      setState(() => _selectedDate = date);
                    },
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                _SelectedWorkShiftList(
                  date: selectedDate,
                  shiftTimes: selectedTimes,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _moveMonth(int offset) {
    final nextMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + offset,
    );
    setState(() {
      _visibleMonth = nextMonth;
      _selectedDate = _firstScheduledDateInMonth(nextMonth);
    });
  }

  DateTime? _firstScheduledDateInMonth(DateTime month) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      if (_hasDisplayWorkScheduleOnDate(widget.job, date)) return date;
    }
    return null;
  }
}

class _CalendarMonthHeader extends StatelessWidget {
  const _CalendarMonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Tháng trước',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              'Tháng ${month.month} ${month.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tháng sau',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _CalendarWeekdayHeader extends StatelessWidget {
  const _CalendarWeekdayHeader();

  static const _labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (final label in _labels)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarDayGrid extends StatelessWidget {
  const _CalendarDayGrid({
    required this.month,
    required this.selectedDate,
    required this.job,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime? selectedDate;
  final JobPost job;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final cells = _monthCells(month);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        final date = cells[index];
        if (date == null) return const SizedBox.shrink();

        final isAvailable = _hasDisplayWorkScheduleOnDate(job, date);
        final isSelected =
            selectedDate != null && DateUtils.isSameDay(selectedDate, date);

        return _CalendarDayCell(
          date: date,
          isAvailable: isAvailable,
          isSelected: isSelected,
          onTap: isAvailable ? () => onDateSelected(date) : null,
        );
      },
    );
  }

  List<DateTime?> _monthCells(DateTime month) {
    final firstDay = DateTime(month.year, month.month);
    final leadingBlankCount = firstDay.weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(leadingBlankCount, null),
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
    ];

    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isAvailable,
    required this.isSelected,
    this.onTap,
  });

  final DateTime date;
  final bool isAvailable;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const availableGreen = Color(0xFF16A34A);
    const availableGreenSoft = Color(0xFFEAF7EE);
    const availableGreenBorder = Color(0xFF86EFAC);
    final backgroundColor = isSelected
        ? availableGreen
        : isAvailable
        ? availableGreenSoft
        : const Color(0xFFF8FAFC);
    final borderColor = isSelected
        ? availableGreen
        : isAvailable
        ? availableGreenBorder
        : const Color(0xFFE5E7EB);
    final textColor = isSelected
        ? Colors.white
        : isAvailable
        ? const Color(0xFF166534)
        : const Color(0xFFCBD5E1);
    final checkColor = isSelected ? Colors.white : availableGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  date.day.toString(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: isAvailable ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (isAvailable)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.check_rounded, size: 12, color: checkColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _hasDisplayWorkScheduleOnDate(JobPost job, DateTime date) {
  final exactDate = DateTime.tryParse(job.workDate?.trim() ?? '');
  if (exactDate != null) {
    return DateUtils.isSameDay(exactDate, date) &&
        _displayShiftTimesFromRules(job).isNotEmpty;
  }

  final start = job.recruitmentStartDate;
  final end = job.recruitmentEndDate;
  if (start != null || end != null) {
    final target = DateTime(date.year, date.month, date.day);
    if (start != null) {
      final startDate = DateTime(start.year, start.month, start.day);
      if (target.isBefore(startDate)) return false;
    }
    if (end != null) {
      final endDate = DateTime(end.year, end.month, end.day);
      if (target.isAfter(endDate)) return false;
    }
    return _displayShiftTimesFromRules(job).isNotEmpty;
  }

  return workShiftTimesForDate(job, date).isNotEmpty;
}

List<String> _displayShiftTimesForDate(JobPost job, DateTime date) {
  if (!_hasDisplayWorkScheduleOnDate(job, date)) return const [];

  final shiftTimes = _displayShiftTimesFromRules(job);
  if (shiftTimes.isNotEmpty) return shiftTimes;
  return workShiftTimesForDate(job, date);
}

List<String> _displayShiftTimesFromRules(JobPost job) {
  final uniqueTimes = <String>[];
  for (final rule in workShiftRulesFromJob(job)) {
    final trimmed = rule.timeRange.trim();
    if (trimmed.isNotEmpty && !uniqueTimes.contains(trimmed)) {
      uniqueTimes.add(trimmed);
    }
  }
  return uniqueTimes;
}

class _SelectedWorkShiftList extends StatelessWidget {
  const _SelectedWorkShiftList({required this.date, required this.shiftTimes});

  final DateTime? date;
  final List<String> shiftTimes;

  @override
  Widget build(BuildContext context) {
    if (date == null || shiftTimes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Chọn ngày có lịch làm việc để xem ca.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatRecruitmentDate(date!),
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final time in shiftTimes) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      time,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpiredJobNotice extends StatelessWidget {
  const _ExpiredJobNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.event_busy_outlined, color: Color(0xFFEA580C), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tin tuyển dụng đã hết hạn',
                    style: TextStyle(
                      color: Color(0xFF9A3412),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ứng viên không thể ứng tuyển vào tin này nữa.',
                    style: TextStyle(
                      color: Color(0xFFC2410C),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style:
                    valueStyle ??
                    const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section divider ───────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      color: const Color(0xFFF7F8FC),
      margin: const EdgeInsets.symmetric(vertical: 16),
    );
  }
}

// ── Section header (— Tiêu đề) ────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Description section ───────────────────────────────────────────────────────

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Parse bullet points nếu có (dấu • hoặc - hoặc \n)
    final lines = _parseLines(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Mô tả công việc'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) => _ContentLine(text: line)).toList(),
          ),
        ),
      ],
    );
  }

  List<String> _parseLines(String raw) {
    return raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }
}

// ── Requirements section ──────────────────────────────────────────────────────

class _RequirementsSection extends StatelessWidget {
  const _RequirementsSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Yêu cầu'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: lines
                .map((line) => _RequirementCard(text: line))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Tách label: value nếu có dấu :
    final colonIdx = text.indexOf(':');
    String? label;
    String body = text;
    if (colonIdx > 0 && colonIdx < 30) {
      label = text.substring(0, colonIdx).trim();
      body = text.substring(colonIdx + 1).trim();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null) ...[
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Benefits section ──────────────────────────────────────────────────────────

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Quyền lợi'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: lines.map((line) => _BenefitRow(text: line)).toList(),
          ),
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final clean = text.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              clean,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Content line (description bullets) ───────────────────────────────────────

class _ContentLine extends StatelessWidget {
  const _ContentLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isBullet =
        text.startsWith('•') || text.startsWith('-') || text.startsWith('*');
    final clean = isBullet
        ? text.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim()
        : text;

    if (isBullet) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: CircleAvatar(
                radius: 3,
                backgroundColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                clean,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        clean,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF374151),
          height: 1.7,
        ),
      ),
    );
  }
}

// ── Employer info card ────────────────────────────────────────────────────────

class _EmployerInfoCard extends StatelessWidget {
  const _EmployerInfoCard({required this.job});

  final JobPost job;

  @override
  Widget build(BuildContext context) {
    final company = job.companyName ?? job.employerName;
    final avatarUrl = job.employerAvatarUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin nhà tuyển dụng',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),

            // Logo + name
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const _CompanyIconFallback(),
                          ),
                        )
                      : const _CompanyIconFallback(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      // applicants count nếu có
                      if (job.applicants > 0)
                        Text(
                          '${job.applicants}+ ứng viên',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Tags nếu có
            if (job.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Lĩnh vực',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  const Spacer(),
                  Text(
                    job.tags.take(2).join(' / '),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // View company button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CompanyProfileScreen(
                        employerId: job.employerId,
                        companyName: job.companyName ?? job.employerName,
                        logoUrl: job.employerAvatarUrl,
                        location: job.location,
                        tags: job.tags,
                        applicants: job.applicants,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Xem trang công ty',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyIconFallback extends StatelessWidget {
  const _CompanyIconFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.business_rounded,
      color: AppColors.primary,
      size: 26,
    );
  }
}

// ── Similar positions ─────────────────────────────────────────────────────────
// Derive từ dữ liệu thật (activeJobs + activeQuickJobs) — không hardcode/mock.
// Xếp hạng theo cùng nhà tuyển dụng / địa điểm / loại việc / tags / tiêu đề.

class _SimilarPositions extends ConsumerWidget {
  const _SimilarPositions({required this.job});

  final JobPost job;

  static const int _maxItems = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeJobs = ref.watch(activeJobsProvider);
    final activeQuickJobs = ref.watch(activeQuickJobsProvider);

    // Hợp nhất hai nguồn dữ liệu thật khi cả hai đã sẵn sàng.
    final List<JobPost> all = [
      ...activeJobs.maybeWhen(data: (d) => d, orElse: () => const <JobPost>[]),
      ...activeQuickJobs.maybeWhen(
        data: (d) => d,
        orElse: () => const <JobPost>[],
      ),
    ];

    final isLoading = activeJobs.isLoading || activeQuickJobs.isLoading;
    final related = _findRelated(job, all);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VỊ TRÍ TƯƠNG TỰ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading && related.isEmpty)
            const _SimilarLoading()
          else if (related.isEmpty)
            const _SimilarEmpty()
          else
            ...related.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SimilarJobRow(
                  job: item,
                  onTap: () => _openJob(context, item),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openJob(BuildContext context, JobPost target) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserJobDetailScreen(
          job: target,
          onApplyPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// Lọc + xếp hạng tin tương tự từ danh sách thật `all` (không phát sinh dữ liệu).
  List<JobPost> _findRelated(JobPost seed, List<JobPost> all) {
    final scored = <({JobPost job, int score})>[];
    final seedTags = seed.tags
        .map(_normalize)
        .where((t) => t.isNotEmpty)
        .toSet();

    for (final candidate in all) {
      if (candidate.idJob == seed.idJob) continue; // loại chính tin gốc

      var score = 0;
      if (candidate.employerId == seed.employerId &&
          seed.employerId.isNotEmpty) {
        score += 50;
      }
      if (candidate.jobType == seed.jobType) score += 15;
      if (_textsOverlap(candidate.location, seed.location)) score += 10;

      final candidateTags = candidate.tags
          .map(_normalize)
          .where((t) => t.isNotEmpty)
          .toSet();
      final sharedTags = candidateTags.intersection(seedTags).length;
      score += 5 * sharedTags;

      if (_textsOverlap(candidate.title, seed.title)) score += 8;

      if (score > 0) scored.add((job: candidate, score: score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.job.postedAt.compareTo(a.job.postedAt);
    });

    return scored.take(_maxItems).map((e) => e.job).toList(growable: false);
  }

  String _normalize(String value) => value.toLowerCase().trim();

  /// Trùng lặp token (>= 3 ký tự) giữa hai chuỗi sau khi chuẩn hóa.
  bool _textsOverlap(String left, String right) {
    final leftTokens = _tokenize(left);
    final rightTokens = _tokenize(right).toSet();
    return leftTokens.any(
      (token) => token.length >= 3 && rightTokens.contains(token),
    );
  }

  List<String> _tokenize(String value) => _normalize(
    value,
  ).split(RegExp(r'[^a-z0-9à-ỹ]+')).where((t) => t.isNotEmpty).toList();
}

class _SimilarJobRow extends StatelessWidget {
  const _SimilarJobRow({required this.job, required this.onTap});

  final JobPost job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.work_outline_rounded,
              size: 16,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.location.split(',').first.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimilarLoading extends StatelessWidget {
  const _SimilarLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      child: const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _SimilarEmpty extends StatelessWidget {
  const _SimilarEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        children: [
          Icon(Icons.work_outline_rounded, size: 16, color: Color(0xFF9CA3AF)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Chưa có vị trí tương tự',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sticky apply bar ──────────────────────────────────────────────────────────

class _StickyApplyBar extends StatelessWidget {
  const _StickyApplyBar({
    required this.onApply,
    required this.isAiEnabled,
    required this.isRecruitable,
    required this.isExpired,
  });

  final VoidCallback onApply;
  final bool isAiEnabled;
  final bool isRecruitable;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAiEnabled && isRecruitable) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF7C3AED), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Color(0xFF7C3AED)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lưu ý: Công việc này yêu cầu Phỏng vấn chọn lọc qua AI sau khi gửi CV.',
                      style: TextStyle(
                        color: Color(0xFF6D28D9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isRecruitable ? onApply : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF6B7280),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isExpired
                    ? 'Đã hết hạn'
                    : isRecruitable
                    ? 'Ứng tuyển ngay'
                    : 'Chưa mở tuyển',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
