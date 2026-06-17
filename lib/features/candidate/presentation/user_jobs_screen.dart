import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user_profile.dart';
import '../application/jobs_providers.dart';
import '../data/aws_application_repository.dart';
import '../domain/application_repository.dart';
import '../domain/job_post.dart';
import 'quick_job_intro_page.dart';
import 'user_job_detail_screen.dart';
import 'ai_screening_screen.dart';
import 'widgets/availability_card.dart';
import 'widgets/job_post_card.dart';

class UserJobsScreen extends ConsumerStatefulWidget {
  const UserJobsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  ConsumerState<UserJobsScreen> createState() => _UserJobsScreenState();
}

class _UserJobsScreenState extends ConsumerState<UserJobsScreen> {
  // Search & Filter state
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final Map<String, double> _jobDistances = {};

  String _searchKeyword = '';
  String _searchLocation = '';

  // Tab: 0 = Standard, 1 = Quick/Urgent, 2 = Saved
  int _activeTab = 0;

  // Filters
  bool _filterFullTime = false;
  bool _filterPartTime = false;

  bool _filterSalaryUnder25 = false;
  bool _filterSalary25to40 = false;
  bool _filterSalaryOver40 = false;

  // Sorting: 'newest', 'salary_desc'
  String _sortBy = 'newest';

  // Layout: 'list', 'grid'
  String _viewMode = 'list';
  String? _lastSavedJobsCleanupSignature;

  @override
  void dispose() {
    _keywordController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  int _getSalaryValue(String salaryStr) {
    final cleanStr = salaryStr.replaceAll('.', '').replaceAll(',', '');
    final match = RegExp(r'\d+').firstMatch(cleanStr);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371; // Earth's radius in km
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Future<void> _enableAvailability() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final coords = await LocationService.getCurrentLocation();
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading

      if (coords != null) {
        final user = ref.read(authControllerProvider).asData?.value.user;
        final currentLat = user?.latitude;
        final currentLng = user?.longitude;

        bool shouldUpdateLocation = true;
        if (currentLat != null && currentLng != null) {
          final distance = _calculateDistance(
            currentLat,
            currentLng,
            coords.$1,
            coords.$2,
          );
          // If the candidate is within 100m (0.1 km) of their saved location,
          // do not update coordinates in DB to avoid triggering duplicate recommendation emails.
          if (distance < 0.1) {
            shouldUpdateLocation = false;
          }
        }

        await ref
            .read(authControllerProvider.notifier)
            .updateAvailability(
              true,
              latitude: shouldUpdateLocation ? coords.$1 : null,
              longitude: shouldUpdateLocation ? coords.$2 : null,
            );
      } else {
        _showErrorDialog(
          'Không thể lấy vị trí hiện tại. Vui lòng bật GPS và cấp quyền truy cập.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Dismiss loading
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Widget _buildEmptyPlaceholder(AuthUserProfile? user) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    if (_activeTab == 1) {
      final status = user?.verificationStatus ?? 'PENDING';
      final isApproved = status == 'APPROVED';
      final isActive = user?.isActive == true;

      if (!isApproved) {
        if (status == 'SUBMITTED') {
          return Column(
            children: [
              const Icon(
                Icons.access_time_filled_rounded,
                size: 48,
                color: Colors.amber,
              ),
              const SizedBox(height: 12),
              Text(
                'Yêu cầu đang chờ duyệt',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hệ thống đang kiểm duyệt hồ sơ của bạn. Thường mất 1–2 ngày làm việc.',
                textAlign: TextAlign.center,
              ),
            ],
          );
        } else {
          return Column(
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Chưa kích hoạt Tuyển gấp',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Vui lòng gửi yêu cầu kích hoạt Công việc tuyển gấp và chờ admin duyệt.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const QuickJobIntroPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Tìm hiểu & Kích hoạt ngay'),
              ),
            ],
          );
        }
      }

      if (!isActive) {
        return Column(
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'Bật trạng thái làm việc và vị trí để tìm công việc',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vui lòng bật trạng thái làm việc ở phía trên để tìm các công việc tuyển gấp trong bán kính 3km.',
              textAlign: TextAlign.center,
            ),
          ],
        );
      }

      return Column(
        children: [
          const Icon(Icons.search, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            'Không tìm thấy công việc gần bạn',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Không có công việc tuyển gấp trong bán kính 3km. Thử lại sau hoặc di chuyển đến khu vực khác.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Default for standard / saved empty tab
    return Column(
      children: [
        const Icon(Icons.work_off_outlined, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        Text(
          'Không tìm thấy công việc nào phù hợp.',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text('Hãy thử thay đổi từ khóa hoặc bộ lọc của bạn.'),
      ],
    );
  }

  // Filter logic
  List<JobPost> _getFilteredJobs(
    List<JobPost> allStandard,
    List<JobPost> allQuick,
    List<String> savedJobIds,
    AuthUserProfile? user,
  ) {
    return _getFilteredJobsForTab(
      _activeTab,
      allStandard,
      allQuick,
      savedJobIds,
      user,
    );
  }

  List<JobPost> _getFilteredJobsForTab(
    int tab,
    List<JobPost> allStandard,
    List<JobPost> allQuick,
    List<String> savedJobIds,
    AuthUserProfile? user,
  ) {
    List<JobPost> baseList;
    if (tab == 0) {
      baseList = allStandard;
    } else if (tab == 1) {
      final status = user?.verificationStatus ?? 'PENDING';
      final isApproved = status == 'APPROVED';
      final isActive = user?.isActive == true;

      if (!isApproved || !isActive) {
        return [];
      }

      final double? userLat = user?.latitude;
      final double? userLng = user?.longitude;

      if (userLat != null && userLng != null) {
        baseList = [];
        for (final job in allQuick) {
          final double? jobLat = job.latitude;
          final double? jobLng = job.longitude;
          if (jobLat != null && jobLng != null) {
            final distance = _calculateDistance(
              userLat,
              userLng,
              jobLat,
              jobLng,
            );
            if (distance <= 3.0) {
              _jobDistances[job.id] = distance;
              baseList.add(job);
            }
          }
        }
        // Sort closest first
        baseList.sort((a, b) {
          final distA = _jobDistances[a.id] ?? 9999.0;
          final distB = _jobDistances[b.id] ?? 9999.0;
          return distA.compareTo(distB);
        });
      } else {
        baseList = [];
      }
    } else {
      // Saved Jobs Tab - merges standard and quick jobs that match saved IDs
      baseList = [
        ...allStandard,
        ...allQuick,
      ].where((job) => _isJobSaved(job, savedJobIds)).toList();
    }

    // Apply Search Keyword
    if (_searchKeyword.trim().isNotEmpty) {
      final kw = _searchKeyword.toLowerCase().trim();
      baseList = baseList.where((j) {
        return j.title.toLowerCase().contains(kw) ||
            j.employerName.toLowerCase().contains(kw) ||
            j.description.toLowerCase().contains(kw) ||
            j.tags.any((t) => t.toLowerCase().contains(kw));
      }).toList();
    }

    // Apply Location
    if (_searchLocation.trim().isNotEmpty) {
      final loc = _searchLocation.toLowerCase().trim();
      baseList = baseList
          .where((j) => j.location.toLowerCase().contains(loc))
          .toList();
    }

    // Apply Job Type filters
    if (_filterFullTime || _filterPartTime) {
      baseList = baseList.where((j) {
        if (_filterFullTime && j.jobType == JobPostType.fullTime) return true;
        if (_filterPartTime &&
            (j.jobType == JobPostType.partTime ||
                j.jobType == JobPostType.urgent)) {
          return true;
        }
        return false;
      }).toList();
    }

    // Apply Salary filters
    if (_filterSalaryUnder25 || _filterSalary25to40 || _filterSalaryOver40) {
      baseList = baseList.where((j) {
        final rate = j.isQuickJob
            ? (j.hourlyRate ?? 0)
            : _getSalaryValue(j.salary);
        if (rate == 0) return true; // Keep "negotiable" jobs

        if (_filterSalaryUnder25 && rate < 25000) return true;
        if (_filterSalary25to40 && rate >= 25000 && rate <= 40000) return true;
        if (_filterSalaryOver40 && rate > 40000) return true;
        return false;
      }).toList();
    }

    // Apply Sorting
    if (_sortBy == 'newest') {
      baseList.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    } else if (_sortBy == 'salary_desc') {
      baseList.sort((a, b) {
        final valA = a.isQuickJob
            ? (a.hourlyRate ?? 0)
            : _getSalaryValue(a.salary);
        final valB = b.isQuickJob
            ? (b.hourlyRate ?? 0)
            : _getSalaryValue(b.salary);
        return valB.compareTo(valA);
      });
    }

    return baseList;
  }

  bool _isJobSaved(JobPost job, List<String> savedJobIds) {
    return savedJobIds.contains(job.id) || savedJobIds.contains(job.idJob);
  }

  List<String> _validSavedJobIds(
    List<String> savedJobIds,
    List<JobPost> standardJobs,
    List<JobPost> quickJobs,
  ) {
    final activeJobIds = <String>{
      for (final job in [...standardJobs, ...quickJobs]) ...[
        if (job.id.trim().isNotEmpty) job.id,
        if (job.idJob.trim().isNotEmpty) job.idJob,
      ],
    };

    final valid = <String>[];
    for (final jobId in savedJobIds) {
      final trimmed = jobId.trim();
      if (trimmed.isNotEmpty &&
          activeJobIds.contains(trimmed) &&
          !valid.contains(trimmed)) {
        valid.add(trimmed);
      }
    }
    return valid;
  }

  void _pruneExpiredSavedJobs(
    List<String> savedJobIds,
    List<String> validSavedJobIds,
  ) {
    if (_sameStringList(savedJobIds, validSavedJobIds)) {
      return;
    }

    final signature = '${savedJobIds.join('|')}=>${validSavedJobIds.join('|')}';
    if (_lastSavedJobsCleanupSignature == signature) {
      return;
    }
    _lastSavedJobsCleanupSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(authControllerProvider.notifier)
          .pruneSavedJobs(validSavedJobIds);
    });
  }

  void _clearFilters() {
    setState(() {
      _keywordController.clear();
      _locationController.clear();
      _searchKeyword = '';
      _searchLocation = '';
      _filterFullTime = false;
      _filterPartTime = false;
      _filterSalaryUnder25 = false;
      _filterSalary25to40 = false;
      _filterSalaryOver40 = false;
    });
  }

  Future<void> _handleApply(JobPost job, AuthUserProfile? user) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để ứng tuyển.')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repository = ref.read(applicationRepositoryProvider);
      final cvs = await repository.getCandidateCVs(user.userId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(); // Dismiss loading

      if (cvs.isEmpty) {
        _showNoCVDialog();
      } else {
        _showCVSelectionDialog(job, cvs);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(); // Dismiss loading
      _showErrorDialog('Không thể tải danh sách CV. Vui lòng thử lại.');
    }
  }

  void _showNoCVDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Chưa có CV',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn chưa có CV. Vui lòng tải CV lên trong phần Hồ sơ của tôi trước khi ứng tuyển.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showCVSelectionDialog(JobPost job, List<Map<String, dynamic>> cvList) {
    String? selectedCvId = cvList.first['id']?.toString();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text(
                'Chọn CV ứng tuyển',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: RadioGroup<String>(
                  groupValue: selectedCvId,
                  onChanged: (val) {
                    setModalState(() {
                      selectedCvId = val;
                    });
                  },
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cvList.length,
                    itemBuilder: (context, index) {
                      final cv = cvList[index];
                      final id = cv['id']?.toString();
                      final name = cv['cvFileName']?.toString() ?? 'CV.pdf';
                      final date = cv['cvUploadDate']?.toString() ?? '';

                      return RadioListTile<String>(
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: date.isNotEmpty
                            ? Text('Tải lên ngày: $date')
                            : null,
                        value: id!,
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    final chosen = cvList.firstWhere(
                      (c) => c['id']?.toString() == selectedCvId,
                    );
                    final cvUrl = chosen['cvUrl'] ?? chosen['cvS3Key'] ?? '';
                    final cvFilename = chosen['cvFileName'] ?? 'CV.pdf';
                    final cvS3Key = chosen['cvS3Key']?.toString();

                    if (job.isAiScreeningEnabled) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AIScreeningScreen(
                            job: job,
                            cvFileName: cvFilename,
                            cvUrl: cvUrl,
                            cvS3Key: cvS3Key,
                          ),
                        ),
                      );
                    } else {
                      _submitApplication(job, cvUrl, cvFilename);
                    }
                  },
                  child: const Text('Nộp đơn'),
                ),
              ],
            );
          },
        );
      },
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
      final repository = ref.read(applicationRepositoryProvider);
      final user = ref.read(authControllerProvider).asData?.value.user;
      if (user == null) {
        throw Exception('Vui lòng đăng nhập để ứng tuyển.');
      }
      await repository.submitApplication(
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
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(); // Dismiss loading
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(); // Dismiss loading
      final msg = e.toString();
      if (msg.contains('ALREADY_APPLIED') ||
          msg.contains('already applied') ||
          msg.contains('đã ứng tuyển')) {
        _showErrorDialog('Bạn đã ứng tuyển công việc này rồi!');
      } else {
        _showErrorDialog(msg.replaceAll('Exception: ', ''));
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Thành công', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Hồ sơ ứng tuyển của bạn đã được gửi đi thành công!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Thông báo', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _openDetails(JobPost job) {
    final user = ref.read(authControllerProvider).asData?.value.user;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserJobDetailScreen(
          job: job,
          onApplyPressed: () {
            Navigator.of(context).pop(); // close detail
            _handleApply(job, user);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Async jobs data
    final standardJobsAsync = ref.watch(activeJobsProvider);
    final quickJobsAsync = ref.watch(activeQuickJobsProvider);

    // Profile sync
    final user = ref.watch(authControllerProvider).asData?.value.user;
    final rawSavedJobIds = user?.savedJobs ?? const <String>[];

    return Scaffold(
      body: SafeArea(
        child: standardJobsAsync.when(
          data: (standardJobs) {
            return quickJobsAsync.when(
              data: (quickJobs) {
                final savedJobIds = _validSavedJobIds(
                  rawSavedJobIds,
                  standardJobs,
                  quickJobs,
                );
                _pruneExpiredSavedJobs(rawSavedJobIds, savedJobIds);
                final filteredJobs = _getFilteredJobs(
                  standardJobs,
                  quickJobs,
                  savedJobIds,
                  user,
                );
                final urgentJobsCount = _getFilteredJobsForTab(
                  1,
                  standardJobs,
                  quickJobs,
                  savedJobIds,
                  user,
                ).length;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Blue Gradient Banner Header (matching Web HeroSection)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.showBackButton) ...[
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              'Tìm công việc mơ ước của bạn',
                              style: textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Hơn ${standardJobs.length} công việc đang chờ bạn khám phá',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Search bar (Keyword + Location)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _keywordController,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Tìm theo vị trí, công ty, kỹ năng...',
                                      prefixIcon: Icon(Icons.search),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  TextField(
                                    controller: _locationController,
                                    decoration: const InputDecoration(
                                      hintText: 'Địa điểm...',
                                      prefixIcon: Icon(
                                        Icons.location_on_outlined,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _searchKeyword =
                                              _keywordController.text;
                                          _searchLocation =
                                              _locationController.text;
                                        });
                                      },
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.search),
                                          SizedBox(width: 8),
                                          Text(
                                            'Tìm kiếm',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tabs selector matching web categories tabs
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: _JobCategoryTabs(
                          activeTab: _activeTab,
                          standardCount: standardJobs.length,
                          urgentCount: urgentJobsCount,
                          savedCount: savedJobIds.length,
                          onTabChanged: (tab) =>
                              setState(() => _activeTab = tab),
                        ),
                      ),

                      if (_activeTab == 1) ...[
                        if (user?.verificationStatus != 'APPROVED')
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.security,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user?.verificationStatus ==
                                                  'SUBMITTED'
                                              ? 'Yêu cầu đang chờ admin duyệt...'
                                              : 'Để sử dụng công việc tuyển gấp',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user?.verificationStatus ==
                                                  'SUBMITTED'
                                              ? 'Thường mất 1–2 ngày làm việc.'
                                              : 'Nhấn vào đây để biết thêm chi tiết',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (user?.verificationStatus != 'SUBMITTED')
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const QuickJobIntroPage(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Tìm hiểu ngay →',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: AvailabilityCard(
                              isAvailable: user?.isActive == true,
                              onChanged: (val) {
                                if (val) {
                                  _enableAvailability();
                                } else {
                                  ref
                                      .read(authControllerProvider.notifier)
                                      .updateAvailability(false);
                                }
                              },
                            ),
                          ),
                      ],

                      // Filters section collapsible
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ExpansionTile(
                          leading: const Icon(Icons.tune),
                          title: const Text(
                            'Bộ lọc việc làm',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: TextButton(
                            onPressed: _clearFilters,
                            child: const Text(
                              'Xóa bộ lọc',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Loại hình công việc',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  CheckboxListTile(
                                    title: const Text('Toàn thời gian'),
                                    value: _filterFullTime,
                                    onChanged: (val) => setState(
                                      () => _filterFullTime = val ?? false,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    dense: true,
                                  ),
                                  CheckboxListTile(
                                    title: const Text('Bán thời gian'),
                                    value: _filterPartTime,
                                    onChanged: (val) => setState(
                                      () => _filterPartTime = val ?? false,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    dense: true,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Thu nhập/giờ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  CheckboxListTile(
                                    title: const Text('Dưới 25.000đ/giờ'),
                                    value: _filterSalaryUnder25,
                                    onChanged: (val) => setState(
                                      () => _filterSalaryUnder25 = val ?? false,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    dense: true,
                                  ),
                                  CheckboxListTile(
                                    title: const Text(
                                      'Từ 25.000đ - 40.000đ/giờ',
                                    ),
                                    value: _filterSalary25to40,
                                    onChanged: (val) => setState(
                                      () => _filterSalary25to40 = val ?? false,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    dense: true,
                                  ),
                                  CheckboxListTile(
                                    title: const Text('Trên 40.000đ/giờ'),
                                    value: _filterSalaryOver40,
                                    onChanged: (val) => setState(
                                      () => _filterSalaryOver40 = val ?? false,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    dense: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Layout View Mode and Sorting Controls
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final resultLabel = Text(
                              'Tìm thấy ${filteredJobs.length} công việc phù hợp',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                            final controls = Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButton<String>(
                                  value: _sortBy,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'newest',
                                      child: Text('Mới nhất'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'salary_desc',
                                      child: Text('Lương cao nhất'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _sortBy = val);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.view_list,
                                    color: _viewMode == 'list'
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                  onPressed: () =>
                                      setState(() => _viewMode = 'list'),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.grid_view,
                                    color: _viewMode == 'grid'
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                  onPressed: () =>
                                      setState(() => _viewMode = 'grid'),
                                ),
                              ],
                            );

                            if (constraints.maxWidth < 420) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  resultLabel,
                                  const SizedBox(height: 4),
                                  controls,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: resultLabel),
                                const SizedBox(width: 12),
                                controls,
                              ],
                            );
                          },
                        ),
                      ),

                      // Jobs Listing View
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: filteredJobs.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(32),
                                alignment: Alignment.center,
                                child: _buildEmptyPlaceholder(user),
                              )
                            : _viewMode == 'list'
                            ? ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredJobs.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final job = filteredJobs[index];
                                  final isSaved = _isJobSaved(job, savedJobIds);
                                  return JobPostCard(
                                    job: job,
                                    distance: _jobDistances[job.id],
                                    isSaved: isSaved,
                                    onDetailsPressed: () => _openDetails(job),
                                    onApplyPressed: () =>
                                        _handleApply(job, user),
                                    onSavePressed: () => ref
                                        .read(authControllerProvider.notifier)
                                        .toggleSavedJob(job.id),
                                  );
                                },
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.72,
                                    ),
                                itemCount: filteredJobs.length,
                                itemBuilder: (context, index) {
                                  final job = filteredJobs[index];
                                  final isSaved = _isJobSaved(job, savedJobIds);
                                  return JobPostCard(
                                    job: job,
                                    distance: _jobDistances[job.id],
                                    isSaved: isSaved,
                                    onDetailsPressed: () => _openDetails(job),
                                    onApplyPressed: () =>
                                        _handleApply(job, user),
                                    onSavePressed: () => ref
                                        .read(authControllerProvider.notifier)
                                        .toggleSavedJob(job.id),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text('Không thể tải công việc gấp: $err'),
                ),
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text('Lỗi tải công việc: $err'),
            ),
          ),
        ),
      ),
    );
  }
}

class _JobCategoryTabs extends StatefulWidget {
  const _JobCategoryTabs({
    required this.activeTab,
    required this.standardCount,
    required this.urgentCount,
    required this.savedCount,
    required this.onTabChanged,
  });

  final int activeTab;
  final int standardCount;
  final int urgentCount;
  final int savedCount;
  final ValueChanged<int> onTabChanged;

  @override
  State<_JobCategoryTabs> createState() => _JobCategoryTabsState();
}

class _JobCategoryTabsState extends State<_JobCategoryTabs> {
  bool _isExpanded = false;

  void _selectTab(int tab) {
    setState(() => _isExpanded = false);
    widget.onTabChanged(tab);
  }

  @override
  Widget build(BuildContext context) {
    final selectedJobTypeTab = widget.activeTab == 1 ? 1 : 0;
    final selectedLabel = selectedJobTypeTab == 1
        ? 'Công việc Tuyển gấp'
        : 'Công việc';
    final selectedIcon = selectedJobTypeTab == 1
        ? Icons.flash_on_outlined
        : Icons.work_outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _JobTypeDropdownButton(
                label: selectedLabel,
                icon: selectedIcon,
                isExpanded: _isExpanded,
                isActive: widget.activeTab != 2,
                onTap: () => setState(() => _isExpanded = !_isExpanded),
              ),
            ),
            const SizedBox(width: 12),
            _SavedJobsIconButton(
              count: widget.savedCount,
              isActive: widget.activeTab == 2,
              onTap: () => _selectTab(2),
            ),
          ],
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 10),
          _JobTypeDropdownPanel(
            activeTab: selectedJobTypeTab,
            standardCount: widget.standardCount,
            urgentCount: widget.urgentCount,
            onSelected: _selectTab,
          ),
        ],
      ],
    );
  }
}

class _JobTypeDropdownButton extends StatelessWidget {
  const _JobTypeDropdownButton({
    required this.label,
    required this.icon,
    required this.isExpanded,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isExpanded;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final foregroundColor = isActive ? Colors.white : AppColors.primary;
    final mutedColor = isActive
        ? Colors.white.withValues(alpha: 0.82)
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? Colors.transparent
                  : theme.colorScheme.outlineVariant,
            ),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: foregroundColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Loại công việc',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: foregroundColor,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedJobsIconButton extends StatelessWidget {
  const _SavedJobsIconButton({
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = isActive
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant;

    return Tooltip(
      message: 'Công việc đã lưu',
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('saved-jobs-button'),
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Ink(
                    decoration: ShapeDecoration(
                      color: isActive
                          ? AppColors.primary
                          : theme.colorScheme.surface,
                      shape: CircleBorder(
                        side: BorderSide(
                          color: isActive
                              ? Colors.transparent
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Icon(
                      Icons.bookmark_outline_rounded,
                      color: foregroundColor,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  key: const Key('saved-jobs-badge'),
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D2D),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JobTypeDropdownPanel extends StatelessWidget {
  const _JobTypeDropdownPanel({
    required this.activeTab,
    required this.standardCount,
    required this.urgentCount,
    required this.onSelected,
  });

  final int activeTab;
  final int standardCount;
  final int urgentCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _JobTypeOption(
            label: 'Công việc',
            count: standardCount,
            icon: Icons.work_outline,
            isActive: activeTab == 0,
            onTap: () => onSelected(0),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          _JobTypeOption(
            label: 'Công việc Tuyển gấp',
            count: urgentCount,
            icon: Icons.flash_on_outlined,
            isActive: activeTab == 1,
            onTap: () => onSelected(1),
          ),
        ],
      ),
    );
  }
}

class _JobTypeOption extends StatelessWidget {
  const _JobTypeOption({
    required this.label,
    required this.count,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive
                    ? AppColors.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minWidth: 32),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isActive
                        ? AppColors.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
