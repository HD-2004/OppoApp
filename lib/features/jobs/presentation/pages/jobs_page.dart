import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../../../candidate/data/aws_application_repository.dart';
import '../../../candidate/domain/job_post.dart';
import '../../../candidate/presentation/user_job_detail_screen.dart';
import '../controllers/jobs_controller.dart';
import '../widgets/job_card.dart';
import '../widgets/job_filter_bar.dart';
import '../widgets/job_type_tabs.dart';
import '../widgets/jobs_empty_state.dart';
import '../widgets/jobs_error_state.dart';
import '../widgets/jobs_header.dart';
import '../widgets/jobs_loading_skeleton.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  bool _searchMode = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchMode = !_searchMode;
      if (!_searchMode) {
        _searchController.clear();
        ref.read(jobsControllerProvider.notifier).setKeyword('');
      }
    });
  }

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
      final repo = ref.read(applicationRepositoryProvider);
      final cvs = await repo.getCandidateCVs(user.userId);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (cvs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn chưa có CV. Vui lòng tải CV lên trong Hồ sơ.'),
          ),
        );
      } else {
        _showCVPicker(job, cvs);
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải danh sách CV.')),
      );
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
                  final cv = cvs[i];
                  final id = cv['id']?.toString();
                  return RadioListTile<String>(
                    value: id!,
                    title: Text(cv['cvFileName']?.toString() ?? 'CV.pdf'),
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
                backgroundColor: AppColors.secondary,
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
      await ref
          .read(applicationRepositoryProvider)
          .submitApplication(
            jobId: job.idJob,
            cvUrl: cvUrl,
            cvFilename: cvFilename,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hồ sơ ứng tuyển đã được gửi thành công!'),
          backgroundColor: AppColors.secondary,
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
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsControllerProvider);
    final controller = ref.read(jobsControllerProvider.notifier);
    final jobsState = jobsAsync.asData?.value ?? const JobsState();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: _searchMode
          ? _buildSearchAppBar(controller)
          : JobsHeader(onSearchTap: _toggleSearch),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: controller.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Title ─────────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Công việc',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tìm kiếm cơ hội phù hợp với bạn hôm nay.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),

            // ── Tabs ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
                child: JobTypeTabs(
                  selectedTab: jobsState.tab,
                  onTabChanged: controller.setTab,
                ),
              ),
            ),

            // ── Filters ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: JobFilterBar(
                  filter: jobsState.filter,
                  availableLocations: jobsState.availableLocations,
                  availableIndustries: jobsState.availableIndustries,
                  onFilterChanged: controller.setFilter,
                ),
              ),
            ),

            // ── Main content ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: jobsAsync.when(
                loading: () => const JobsLoadingSkeleton(),
                error: (e, _) => JobsErrorState(
                  message: e.toString().replaceAll('Exception: ', ''),
                  onRetry: controller.refresh,
                ),
                data: (s) => _buildJobList(s, controller),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildJobList(JobsState state, JobsController controller) {
    final jobs = state.filteredJobs;
    if (jobs.isEmpty) return JobsEmptyState(tab: state.tab);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Tìm thấy ${jobs.length} công việc',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: jobs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) =>
              JobCard(job: jobs[i], onTap: () => _openDetail(jobs[i])),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar(JobsController controller) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF374151)),
        onPressed: _toggleSearch,
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Tìm việc làm, công ty...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
        ),
        style: const TextStyle(fontSize: 16, color: Color(0xFF111827)),
        onChanged: (v) {
          controller.setKeyword(v);
          setState(() {});
        },
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
            onPressed: () {
              _searchController.clear();
              controller.setKeyword('');
              setState(() {});
            },
          ),
      ],
    );
  }
}
