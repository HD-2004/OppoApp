import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/application/auth_controller.dart';
import '../../../../features/candidate/application/jobs_providers.dart';
import '../../../../features/candidate/data/aws_application_repository.dart';
import '../../../../features/candidate/domain/application_repository.dart';
import '../../../../features/candidate/domain/job_post.dart';
import '../../../../features/candidate/notifications/application/notification_controller.dart';
import '../../../../features/candidate/presentation/user_job_detail_screen.dart';
import '../../../../features/home/presentation/widgets/candidate_menu_drawer.dart';
import '../widgets/employer_spotlight_row.dart';
import '../widgets/search_filter_pills.dart';
import '../widgets/search_job_card.dart';

// ── Provider: merged all jobs (standard + quick) ──────────────────────────────

final _allJobsProvider = FutureProvider<List<JobPost>>((ref) async {
  final standard = await ref.watch(activeJobsProvider.future);
  final quick = await ref.watch(activeQuickJobsProvider.future);
  return [...standard, ...quick]
    ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
});

// ── Page ──────────────────────────────────────────────────────────────────────

enum SearchSortFilter { distance, partTime, fullTime }

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    super.key,
    required this.onNotificationTap,
    required this.onJobsTap,
    required this.onWalletTap,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onSupportTap,
    required this.onSignOutTap,
  });

  final VoidCallback onNotificationTap;
  final VoidCallback onJobsTap;
  final VoidCallback onWalletTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onSupportTap;
  final VoidCallback onSignOutTap;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchController = TextEditingController();
  String _keyword = '';

  /// employerId đang được chọn từ spotlight — lọc job theo employer
  String _selectedEmployerId = '';

  SearchSortFilter _activeFilter = SearchSortFilter.distance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeDrawerAndRun(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  // ── Filter logic ────────────────────────────────────────────────────────────

  List<JobPost> _filtered(List<JobPost> all) {
    var result = all;

    // Keyword
    if (_keyword.trim().isNotEmpty) {
      final kw = _keyword.toLowerCase();
      result = result.where((j) {
        return j.title.toLowerCase().contains(kw) ||
            j.employerName.toLowerCase().contains(kw) ||
            (j.companyName?.toLowerCase().contains(kw) ?? false) ||
            j.location.toLowerCase().contains(kw) ||
            j.tags.any((t) => t.toLowerCase().contains(kw));
      }).toList();
    }

    // Employer spotlight filter
    if (_selectedEmployerId.isNotEmpty) {
      result = result
          .where((j) => j.employerId == _selectedEmployerId)
          .toList();
    }

    // Sort pill filter
    switch (_activeFilter) {
      case SearchSortFilter.partTime:
        result = result
            .where(
              (j) =>
                  j.jobType == JobPostType.partTime ||
                  j.jobType == JobPostType.urgent,
            )
            .toList();
      case SearchSortFilter.fullTime:
        result = result
            .where((j) => j.jobType == JobPostType.fullTime)
            .toList();
      case SearchSortFilter.distance:
        result = result.toList()
          ..sort((a, b) {
            final aHasCoordinates = a.latitude != null && a.longitude != null;
            final bHasCoordinates = b.latitude != null && b.longitude != null;
            if (aHasCoordinates != bHasCoordinates) {
              return aHasCoordinates ? -1 : 1;
            }
            return b.postedAt.compareTo(a.postedAt);
          });
        break;
    }

    return result;
  }

  // ── Apply flow ──────────────────────────────────────────────────────────────

  void _openDetail(JobPost job) {
    final user = ref.read(authControllerProvider).asData?.value.user;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserJobDetailScreen(
          job: job,
          onApplyPressed: () {
            Navigator.of(context).pop();
            _handleApply(job, user);
          },
        ),
      ),
    );
  }

  Future<void> _handleApply(JobPost job, dynamic user) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để ứng tuyển.')),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final cvs = await ref
          .read(applicationRepositoryProvider)
          .getCandidateCVs(user.userId);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (cvs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn chưa có CV. Hãy tải lên trong Hồ sơ.'),
          ),
        );
      } else {
        _showCVPicker(job, cvs);
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể tải CV.')));
    }
  }

  void _showCVPicker(JobPost job, List<Map<String, dynamic>> cvs) {
    String? selectedId = cvs.first['id']?.toString();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => AlertDialog(
          title: const Text(
            'Chọn CV ứng tuyển',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: RadioGroup<String>(
              groupValue: selectedId,
              onChanged: (v) => setModal(() => selectedId = v),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cvs.length,
                itemBuilder: (_, i) {
                  final id = cvs[i]['id']?.toString();
                  return RadioListTile<String>(
                    value: id!,
                    title: Text(cvs[i]['cvFileName']?.toString() ?? 'CV.pdf'),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                final chosen = cvs.firstWhere(
                  (c) => c['id']?.toString() == selectedId,
                );
                _submitApplication(
                  job,
                  chosen['cvUrl'] ?? chosen['cvS3Key'] ?? '',
                  chosen['cvFileName'] ?? 'CV.pdf',
                );
              },
              child: const Text('Nộp đơn'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitApplication(
    JobPost job,
    String cvUrl,
    String cvFilename,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final user = ref.read(authControllerProvider).asData?.value.user;
      if (user == null) {
        throw Exception('Vui lòng đăng nhập để ứng tuyển.');
      }
      await ref
          .read(applicationRepositoryProvider)
          .submitApplication(
            jobId: job.idJob,
            cvUrl: cvUrl,
            cvFilename: cvFilename,
            notification: ApplicationNotificationDetails(
              employerId: job.employerId,
              candidateId: user.userId,
              candidateName: user.fullName,
              jobTitle: job.title,
              companyName: job.companyName ?? job.employerName,
              isQuickJob: job.isQuickJob,
            ),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ứng tuyển thành công!'),
          backgroundColor: Color(0xFF1E3A8A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      final msg = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('ALREADY_APPLIED') || msg.contains('đã ứng tuyển')
                ? 'Bạn đã ứng tuyển công việc này rồi!'
                : msg.replaceAll('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(_allJobsProvider);
    final user = ref.watch(authControllerProvider).asData?.value.user;
    final displayName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Bạn';
    final email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : 'Chưa có email';

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: CandidateMenuDrawer(
        displayName: displayName,
        email: email,
        profileImage: user?.profileImage,
        onProfileTap: () => _closeDrawerAndRun(widget.onProfileTap),
        onJobsTap: () => _closeDrawerAndRun(widget.onJobsTap),
        onWalletTap: () => _closeDrawerAndRun(widget.onWalletTap),
        onNotificationsTap: () => _closeDrawerAndRun(widget.onNotificationTap),
        onSettingsTap: () => _closeDrawerAndRun(widget.onSettingsTap),
        onSupportTap: () => _closeDrawerAndRun(widget.onSupportTap),
        onSignOutTap: () => _closeDrawerAndRun(widget.onSignOutTap),
      ),
      appBar: _SearchAppBar(
        user: user,
        onNotificationTap: widget.onNotificationTap,
      ),
      body: Column(
        children: [
          // Search input
          _SearchInputBar(
            controller: _searchController,
            onChanged: (v) => setState(() => _keyword = v),
            onClear: () => setState(() {
              _searchController.clear();
              _keyword = '';
            }),
          ),

          // Filter pills
          SearchFilterPills(
            active: _activeFilter,
            onChanged: (f) => setState(() => _activeFilter = f),
          ),

          // Content
          Expanded(
            child: allAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _ErrorBody(
                onRetry: () {
                  ref.invalidate(activeJobsProvider);
                  ref.invalidate(activeQuickJobsProvider);
                },
              ),
              data: (all) {
                final filtered = _filtered(all);

                return RefreshIndicator(
                  color: const Color(0xFF1E3A8A),
                  onRefresh: () async {
                    ref.invalidate(activeJobsProvider);
                    ref.invalidate(activeQuickJobsProvider);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 500),
                    );
                  },
                  child: CustomScrollView(
                    slivers: [
                      // ── Employer spotlight ─────────────────────────
                      // Chỉ hiện khi không đang search keyword
                      if (_keyword.isEmpty)
                        SliverToBoxAdapter(
                          child: EmployerSpotlightRow(
                            jobs: all,
                            selectedEmployerId: _selectedEmployerId,
                            onEmployerTap: (id) => setState(
                              () => _selectedEmployerId =
                                  _selectedEmployerId == id ? '' : id,
                            ),
                          ),
                        ),

                      // ── Section header ─────────────────────────────
                      SliverToBoxAdapter(
                        child: _ShiftsHeader(
                          count: filtered.length,
                          selectedEmployerId: _selectedEmployerId,
                          employerName: _selectedEmployerId.isNotEmpty
                              ? _nameForEmployer(all, _selectedEmployerId)
                              : '',
                          onClear: _selectedEmployerId.isNotEmpty
                              ? () => setState(() => _selectedEmployerId = '')
                              : null,
                        ),
                      ),

                      // ── Job list ───────────────────────────────────
                      if (filtered.isEmpty)
                        const SliverToBoxAdapter(child: _EmptyState())
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => SearchJobCard(
                              job: filtered[i],
                              onTap: () => _openDetail(filtered[i]),
                              onApply: () => _handleApply(filtered[i], user),
                            ),
                            childCount: filtered.length,
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _nameForEmployer(List<JobPost> jobs, String id) {
    final match = jobs.firstWhere(
      (j) => j.employerId == id,
      orElse: () => jobs.first,
    );
    return match.companyName ?? match.employerName;
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _SearchAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _SearchAppBar({required this.user, required this.onNotificationTap});

  final dynamic user;
  final VoidCallback onNotificationTap;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = user?.profileImage as String?;
    // Badge từ cùng provider — đồng nhất với HomeHeader
    final unreadCount =
        ref
            .watch(candidateNotificationControllerProvider)
            .asData
            ?.value
            .summary
            .unread ??
        0;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: const CandidateMenuButton(),
      title: const Text(
        'Ốp Pờ',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1E3A8A),
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        // Bell với badge — dùng chung onNotificationTap từ UserDashboardScreen
        Stack(
          children: [
            IconButton(
              onPressed: onNotificationTap,
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF1E293B),
                size: 24,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? const Icon(Icons.person, size: 18, color: Color(0xFF9CA3AF))
                : null,
          ),
        ),
      ],
    );
  }
}

// ── Search input bar ──────────────────────────────────────────────────────────

class _SearchInputBar extends StatelessWidget {
  const _SearchInputBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm ca làm, quán cafe...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.all(6),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _ShiftsHeader extends StatelessWidget {
  const _ShiftsHeader({
    required this.count,
    required this.selectedEmployerId,
    required this.employerName,
    this.onClear,
  });

  final int count;
  final String selectedEmployerId;
  final String employerName;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selectedEmployerId.isNotEmpty && employerName.isNotEmpty
                  ? 'Ca làm từ $employerName'
                  : 'Ca làm việc hiện có',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF6B7280),
              ),
            )
          else
            Text(
              'Tìm thấy $count',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'Không tìm thấy ca làm việc phù hợp',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: Color(0xFFD1D5DB),
          ),
          const SizedBox(height: 12),
          const Text(
            'Không tải được dữ liệu',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }
}
