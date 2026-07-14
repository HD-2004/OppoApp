import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user_profile.dart';
import '../application/jobs_providers.dart';
import '../data/aws_application_repository.dart';
import '../domain/job_post.dart';
import 'application_flow_navigation.dart';
import 'quick_job_intro_page.dart';
import 'user_job_detail_screen.dart';
import 'widgets/availability_card.dart';
import 'widgets/job_post_card.dart';

const double _urgentJobSearchRadiusKm = 10;
const double _unknownJobDistanceKm = 9999;
const int _jobsTabAll = 0;
const int _jobsTabStandard = 1;
const int _jobsTabUrgent = 2;
const int _jobsTabSaved = 3;

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
  String _selectedPosition = '';
  String _selectedIndustry = '';

  int _activeTab = _jobsTabAll;

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

    if (_activeTab == _jobsTabUrgent) {
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
            Text(
              'Vui lòng bật trạng thái làm việc ở phía trên để tìm các công việc tuyển gấp trong bán kính ${_urgentJobSearchRadiusKm.toStringAsFixed(0)}km.',
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
          Text(
            'Không có công việc tuyển gấp trong bán kính ${_urgentJobSearchRadiusKm.toStringAsFixed(0)}km. Thử lại sau hoặc di chuyển đến khu vực khác.',
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
    List<JobPost> allJobs,
    List<JobPost> allStandard,
    List<JobPost> allQuick,
    List<String> savedJobIds,
    AuthUserProfile? user,
  ) {
    return _getFilteredJobsForTab(
      _activeTab,
      allJobs,
      allStandard,
      allQuick,
      savedJobIds,
      user,
    );
  }

  List<JobPost> _getFilteredJobsForTab(
    int tab,
    List<JobPost> allJobs,
    List<JobPost> allStandard,
    List<JobPost> allQuick,
    List<String> savedJobIds,
    AuthUserProfile? user,
  ) {
    List<JobPost> baseList;
    if (tab == _jobsTabAll) {
      baseList = allJobs;
    } else if (tab == _jobsTabStandard) {
      baseList = allStandard;
    } else if (tab == _jobsTabUrgent) {
      baseList = _urgentJobsAvailableForUser(
        allQuick,
        user,
        trackDistances: true,
      );
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

    // Apply Position
    if (_selectedPosition.trim().isNotEmpty) {
      final position = _selectedPosition.toLowerCase().trim();
      baseList = baseList
          .where((j) => j.title.toLowerCase().contains(position))
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

    // Apply Industry/Tag
    if (_selectedIndustry.trim().isNotEmpty) {
      final industry = _selectedIndustry.toLowerCase().trim();
      baseList = baseList
          .where(
            (j) => j.tags.any((tag) => tag.toLowerCase().contains(industry)),
          )
          .toList();
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

    if (tab == _jobsTabUrgent) {
      baseList.sort((a, b) {
        final distanceComparison =
            (_jobDistances[a.id] ?? _unknownJobDistanceKm).compareTo(
              _jobDistances[b.id] ?? _unknownJobDistanceKm,
            );
        if (distanceComparison != 0) {
          return distanceComparison;
        }
        return _compareBySelectedSort(a, b);
      });
    } else {
      baseList.sort(_compareBySelectedSort);
    }

    return baseList;
  }

  int _compareBySelectedSort(JobPost a, JobPost b) {
    if (_sortBy == 'salary_desc') {
      final valA = a.isQuickJob
          ? (a.hourlyRate ?? 0)
          : _getSalaryValue(a.salary);
      final valB = b.isQuickJob
          ? (b.hourlyRate ?? 0)
          : _getSalaryValue(b.salary);
      return valB.compareTo(valA);
    }
    return b.postedAt.compareTo(a.postedAt);
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
      _selectedPosition = '';
      _selectedIndustry = '';
      _filterFullTime = false;
      _filterPartTime = false;
      _filterSalaryUnder25 = false;
      _filterSalary25to40 = false;
      _filterSalaryOver40 = false;
    });
  }

  bool get _hasActiveFilters =>
      _searchKeyword.trim().isNotEmpty ||
      _searchLocation.trim().isNotEmpty ||
      _selectedPosition.trim().isNotEmpty ||
      _selectedIndustry.trim().isNotEmpty ||
      _filterFullTime ||
      _filterPartTime ||
      _filterSalaryUnder25 ||
      _filterSalary25to40 ||
      _filterSalaryOver40;

  List<String> _availablePositions(List<JobPost> jobs) {
    return _uniqueSortedOptions(jobs.map((job) => job.title));
  }

  List<String> _availableLocations(List<JobPost> jobs) {
    return _uniqueSortedOptions(jobs.map((job) => job.location));
  }

  List<String> _availableIndustries(List<JobPost> jobs) {
    return _uniqueSortedOptions(
      jobs.expand((job) => job.tags).where((tag) => tag.trim().isNotEmpty),
    );
  }

  List<String> _uniqueSortedOptions(Iterable<String> values) {
    final normalized = <String, String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      normalized.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
    }
    final result = normalized.values.toList();
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  void _showPositionSheet(List<JobPost> jobs) {
    _showOptionsSheet(
      title: 'Chọn vị trí',
      options: _availablePositions(jobs),
      selected: _selectedPosition,
      emptyMessage: 'Chưa có dữ liệu vị trí.',
      onSelected: (value) => setState(() => _selectedPosition = value),
    );
  }

  void _showLocationSheet(List<JobPost> jobs) {
    _showOptionsSheet(
      title: 'Chọn khu vực',
      options: _availableLocations(jobs),
      selected: _searchLocation,
      emptyMessage: 'Chưa có dữ liệu khu vực.',
      onSelected: (value) => setState(() {
        _searchLocation = value;
        _locationController.text = value;
      }),
    );
  }

  void _showIndustrySheet(List<JobPost> jobs) {
    _showOptionsSheet(
      title: 'Chọn loại hình',
      options: _availableIndustries(jobs),
      selected: _selectedIndustry,
      emptyMessage: 'Chưa có dữ liệu loại hình.',
      onSelected: (value) => setState(() => _selectedIndustry = value),
    );
  }

  void _showOptionsSheet({
    required String title,
    required List<String> options,
    required String selected,
    required String emptyMessage,
    required ValueChanged<String> onSelected,
  }) {
    if (options.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(emptyMessage)));
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(sheetContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (selected.trim().isNotEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            onSelected('');
                          },
                          child: const Text(
                            'Xóa',
                            style: TextStyle(
                              color: Color(0xFFFF3B30),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.4),
                    ),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected =
                          option.toLowerCase() == selected.trim().toLowerCase();
                      return ListTile(
                        title: Text(
                          option,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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

    var isLoadingVisible = true;

    try {
      // Check if an existing application already exists → skip CV picker
      final handled = await checkExistingApplicationBeforeApply(
        context: context,
        ref: ref,
        job: job,
        user: user,
        onBeforeHandleExistingApplication: () {
          if (mounted && isLoadingVisible) {
            Navigator.of(context).pop(); // Dismiss loading before navigation
            isLoadingVisible = false;
          }
        },
      );
      if (!mounted) return;
      if (handled) return;

      final repository = ref.read(applicationRepositoryProvider);
      final cvs = await repository.getCandidateCVs(user.userId);
      if (!mounted) {
        return;
      }
      if (isLoadingVisible) {
        Navigator.of(context).pop(); // Dismiss loading
        isLoadingVisible = false;
      }

      if (cvs.isEmpty) {
        _showNoCVDialog();
      } else {
        _showCVSelectionDialog(job, cvs);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (isLoadingVisible) {
        Navigator.of(context).pop(); // Dismiss loading
        isLoadingVisible = false;
      }
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
          builder: (builderCtx, setModalState) {
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
                    itemBuilder: (itemCtx, index) {
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
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      final chosen = cvList.firstWhere(
                        (c) => c['id']?.toString() == selectedCvId,
                      );
                      final cvUrl = (chosen['cvUrl'] ?? chosen['cvS3Key'] ?? '')
                          .toString();
                      final cvFilename = (chosen['cvFileName'] ?? 'CV.pdf')
                          .toString();
                      final cvS3Key = chosen['cvS3Key']?.toString();

                      if (job.isAiScreeningEnabled) {
                        final user = ref
                            .read(authControllerProvider)
                            .asData
                            ?.value
                            .user;
                        if (user == null) {
                          _showErrorDialog('Vui lòng đăng nhập để ứng tuyển.');
                          return;
                        }
                        await openAiApplicationFlow(
                          context: context,
                          ref: ref,
                          job: job,
                          user: user,
                          selectedCvUrl: cvUrl,
                          selectedCvFilename: cvFilename,
                          selectedCvS3Key: cvS3Key,
                        );
                      } else {
                        _submitApplication(
                          job,
                          cvUrl,
                          cvFilename,
                          cvS3Key: cvS3Key,
                        );
                      }
                    } catch (e, stack) {
                      debugPrint('Lỗi khi nộp đơn: $e\n$stack');
                      _showErrorDialog('Lỗi khi nộp đơn: $e');
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
    String cvFilename, {
    String? cvS3Key,
  }) async {
    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user == null) {
      _showErrorDialog('Vui lòng đăng nhập để ứng tuyển.');
      return;
    }

    await submitApplicationWithBackgroundEval(
      context: context,
      ref: ref,
      job: job,
      user: user,
      cvUrl: cvUrl,
      cvFilename: cvFilename,
      cvS3Key: cvS3Key,
      onSuccess: () {
        if (mounted) {
          _showSuccessDialog();
        }
      },
      onError: (msg) async {
        if (!mounted) return;
        if (msg.contains('ALREADY_APPLIED') ||
            msg.contains('already applied') ||
            msg.contains('đã ứng tuyển')) {
          final openedInterview =
              await openExistingAiInterviewForDuplicateApplication(
                context: context,
                ref: ref,
                job: job,
                user: user,
                selectedCvUrl: cvUrl,
                selectedCvFilename: cvFilename,
                selectedCvS3Key: cvS3Key,
              );
          if (openedInterview || !mounted) return;
          _showErrorDialog('Bạn đã ứng tuyển công việc này rồi!');
        } else {
          _showErrorDialog(msg.replaceAll('Exception: ', ''));
        }
      },
    );
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

  List<JobPost> _urgentJobsAvailableForUser(
    List<JobPost> allQuick,
    AuthUserProfile? user, {
    bool trackDistances = false,
  }) {
    final status = user?.verificationStatus ?? 'PENDING';
    final isApproved = status == 'APPROVED';
    final isActive = user?.isActive == true;
    final userLat = user?.latitude;
    final userLng = user?.longitude;

    if (!isApproved || !isActive || userLat == null || userLng == null) {
      if (trackDistances) {
        _jobDistances.clear();
      }
      return [];
    }

    if (trackDistances) {
      _jobDistances.clear();
    }

    final availableJobs = <JobPost>[];
    for (final job in allQuick) {
      final jobLat = job.latitude;
      final jobLng = job.longitude;
      if (jobLat == null || jobLng == null) {
        continue;
      }

      final distance = _calculateDistance(userLat, userLng, jobLat, jobLng);
      if (distance <= _urgentJobSearchRadiusKm) {
        if (trackDistances) {
          _jobDistances[job.id] = distance;
        }
        availableJobs.add(job);
      }
    }
    return availableJobs;
  }

  List<JobPost> _uniqueJobPosts(List<JobPost> jobs) {
    final seenIds = <String>{};
    final uniqueJobs = <JobPost>[];

    for (final job in jobs) {
      final ids = <String>{
        if (job.id.trim().isNotEmpty) job.id.trim(),
        if (job.idJob.trim().isNotEmpty) job.idJob.trim(),
      };
      if (ids.isNotEmpty && ids.any(seenIds.contains)) {
        continue;
      }
      seenIds.addAll(ids);
      uniqueJobs.add(job);
    }

    return uniqueJobs;
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
                final enabledQuickJobs = _urgentJobsAvailableForUser(
                  quickJobs,
                  user,
                );
                final allJobs = _uniqueJobPosts([
                  ...standardJobs,
                  ...enabledQuickJobs,
                ]);
                final savedJobIds = _validSavedJobIds(
                  rawSavedJobIds,
                  standardJobs,
                  quickJobs,
                );
                _pruneExpiredSavedJobs(rawSavedJobIds, savedJobIds);
                final visibleQuickJobs = enabledQuickJobs;
                final filteredJobs = _getFilteredJobs(
                  allJobs,
                  standardJobs,
                  visibleQuickJobs,
                  savedJobIds,
                  user,
                );
                final urgentJobsCount = _getFilteredJobsForTab(
                  _jobsTabUrgent,
                  allJobs,
                  standardJobs,
                  visibleQuickJobs,
                  savedJobIds,
                  user,
                ).length;
                final savedJobsCount = _getFilteredJobsForTab(
                  _jobsTabSaved,
                  allJobs,
                  standardJobs,
                  visibleQuickJobs,
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
                            colors: [AppColors.primary, Color(0xFF4FACFE)],
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
                          allCount: allJobs.length,
                          standardCount: standardJobs.length,
                          urgentCount: urgentJobsCount,
                          savedCount: savedJobsCount,
                          onTabChanged: (tab) =>
                              setState(() => _activeTab = tab),
                        ),
                      ),

                      if (_activeTab == _jobsTabUrgent) ...[
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

                      // Compact filters matching the web chip style
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _JobFiltersPanel(
                          hasActiveFilters: _hasActiveFilters,
                          positionLabel: _selectedPosition.trim().isEmpty
                              ? 'Vị trí'
                              : _selectedPosition.trim(),
                          locationLabel: _searchLocation.trim().isEmpty
                              ? 'Khu vực'
                              : _searchLocation.trim(),
                          industryLabel: _selectedIndustry.trim().isEmpty
                              ? 'Loại hình F&B'
                              : _selectedIndustry.trim(),
                          isPositionActive: _selectedPosition.trim().isNotEmpty,
                          isLocationActive: _searchLocation.trim().isNotEmpty,
                          isIndustryActive: _selectedIndustry.trim().isNotEmpty,
                          onClearFilters: _clearFilters,
                          onPositionTap: () => _showPositionSheet(allJobs),
                          onLocationTap: () => _showLocationSheet(allJobs),
                          onIndustryTap: () => _showIndustrySheet(allJobs),
                          advancedFilters: _AdvancedJobFilters(
                            filterFullTime: _filterFullTime,
                            filterPartTime: _filterPartTime,
                            filterSalaryUnder25: _filterSalaryUnder25,
                            filterSalary25to40: _filterSalary25to40,
                            filterSalaryOver40: _filterSalaryOver40,
                            onFullTimeChanged: (value) => setState(
                              () => _filterFullTime = value ?? false,
                            ),
                            onPartTimeChanged: (value) => setState(
                              () => _filterPartTime = value ?? false,
                            ),
                            onSalaryUnder25Changed: (value) => setState(
                              () => _filterSalaryUnder25 = value ?? false,
                            ),
                            onSalary25to40Changed: (value) => setState(
                              () => _filterSalary25to40 = value ?? false,
                            ),
                            onSalaryOver40Changed: (value) => setState(
                              () => _filterSalaryOver40 = value ?? false,
                            ),
                          ),
                        ),
                      ),

                      // Layout View Mode and Sorting Controls
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            DropdownButton<String>(
                              value: _sortBy,
                              underline: const SizedBox(),
                              items: [
                                DropdownMenuItem(
                                  value: 'newest',
                                  child: Text('Mới nhất'),
                                ),
                                const DropdownMenuItem(
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
                                    layout: JobCardLayout.list,
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
                            : _JobMasonryGrid(
                                jobs: filteredJobs,
                                crossAxisCount: 2,
                                spacing: 12,
                                itemBuilder: (context, job) {
                                  final isSaved = _isJobSaved(job, savedJobIds);
                                  return JobPostCard(
                                    job: job,
                                    layout: JobCardLayout.grid,
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

class _JobFiltersPanel extends StatelessWidget {
  const _JobFiltersPanel({
    required this.hasActiveFilters,
    required this.positionLabel,
    required this.locationLabel,
    required this.industryLabel,
    required this.isPositionActive,
    required this.isLocationActive,
    required this.isIndustryActive,
    required this.onClearFilters,
    required this.onPositionTap,
    required this.onLocationTap,
    required this.onIndustryTap,
    required this.advancedFilters,
  });

  final bool hasActiveFilters;
  final String positionLabel;
  final String locationLabel;
  final String industryLabel;
  final bool isPositionActive;
  final bool isLocationActive;
  final bool isIndustryActive;
  final VoidCallback onClearFilters;
  final VoidCallback onPositionTap;
  final VoidCallback onLocationTap;
  final VoidCallback onIndustryTap;
  final Widget advancedFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bộ lọc việc làm',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: hasActiveFilters ? onClearFilters : null,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                  disabledForegroundColor: const Color(
                    0xFFFF3B30,
                  ).withValues(alpha: 0.42),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Xóa bộ lọc'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FilterChipButton(
                key: const Key('position-filter-chip'),
                label: positionLabel,
                isActive: isPositionActive,
                onTap: onPositionTap,
              ),
              _FilterChipButton(
                key: const Key('location-filter-chip'),
                label: locationLabel,
                isActive: isLocationActive,
                onTap: onLocationTap,
              ),
              _FilterChipButton(
                key: const Key('industry-filter-chip'),
                label: industryLabel,
                isActive: isIndustryActive,
                onTap: onIndustryTap,
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                iconColor: AppColors.primary,
                collapsedIconColor: theme.colorScheme.onSurfaceVariant,
                title: Text(
                  'Bộ lọc nâng cao',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                children: [advancedFilters],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = isActive
        ? Colors.white
        : theme.colorScheme.onSurface;
    final borderColor = isActive
        ? AppColors.primary
        : theme.colorScheme.outlineVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isActive ? 0.08 : 0.035),
                blurRadius: isActive ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 42, maxWidth: 178),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isActive
                        ? Colors.white
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdvancedJobFilters extends StatelessWidget {
  const _AdvancedJobFilters({
    required this.filterFullTime,
    required this.filterPartTime,
    required this.filterSalaryUnder25,
    required this.filterSalary25to40,
    required this.filterSalaryOver40,
    required this.onFullTimeChanged,
    required this.onPartTimeChanged,
    required this.onSalaryUnder25Changed,
    required this.onSalary25to40Changed,
    required this.onSalaryOver40Changed,
  });

  final bool filterFullTime;
  final bool filterPartTime;
  final bool filterSalaryUnder25;
  final bool filterSalary25to40;
  final bool filterSalaryOver40;
  final ValueChanged<bool?> onFullTimeChanged;
  final ValueChanged<bool?> onPartTimeChanged;
  final ValueChanged<bool?> onSalaryUnder25Changed;
  final ValueChanged<bool?> onSalary25to40Changed;
  final ValueChanged<bool?> onSalaryOver40Changed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: theme.colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Loại hình công việc', style: titleStyle),
        _CompactCheckboxTile(
          label: 'Toàn thời gian',
          value: filterFullTime,
          onChanged: onFullTimeChanged,
        ),
        _CompactCheckboxTile(
          label: 'Bán thời gian',
          value: filterPartTime,
          onChanged: onPartTimeChanged,
        ),
        const SizedBox(height: 8),
        Text('Thu nhập/giờ', style: titleStyle),
        _CompactCheckboxTile(
          label: 'Dưới 25.000đ/giờ',
          value: filterSalaryUnder25,
          onChanged: onSalaryUnder25Changed,
        ),
        _CompactCheckboxTile(
          label: 'Từ 25.000đ - 40.000đ/giờ',
          value: filterSalary25to40,
          onChanged: onSalary25to40Changed,
        ),
        _CompactCheckboxTile(
          label: 'Trên 40.000đ/giờ',
          value: filterSalaryOver40,
          onChanged: onSalaryOver40Changed,
        ),
      ],
    );
  }
}

class _CompactCheckboxTile extends StatelessWidget {
  const _CompactCheckboxTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
    );
  }
}

class _JobCategoryTabs extends StatefulWidget {
  const _JobCategoryTabs({
    required this.activeTab,
    required this.allCount,
    required this.standardCount,
    required this.urgentCount,
    required this.savedCount,
    required this.onTabChanged,
  });

  final int activeTab;
  final int allCount;
  final int standardCount;
  final int urgentCount;
  final int savedCount;
  final ValueChanged<int> onTabChanged;

  @override
  State<_JobCategoryTabs> createState() => _JobCategoryTabsState();
}

class _JobCategoryTabsState extends State<_JobCategoryTabs> {
  bool _isExpanded = false;
  int _lastNonSavedTab = _jobsTabAll;

  @override
  void initState() {
    super.initState();
    if (widget.activeTab != _jobsTabSaved) {
      _lastNonSavedTab = widget.activeTab;
    }
  }

  @override
  void didUpdateWidget(covariant _JobCategoryTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTab != _jobsTabSaved) {
      _lastNonSavedTab = widget.activeTab;
    }
  }

  void _selectTab(int tab) {
    if (tab == _jobsTabSaved && widget.activeTab != _jobsTabSaved) {
      _lastNonSavedTab = widget.activeTab;
    } else if (tab != _jobsTabSaved) {
      _lastNonSavedTab = tab;
    }
    setState(() => _isExpanded = false);
    widget.onTabChanged(tab);
  }

  void _backFromSavedJobs() {
    _selectTab(_lastNonSavedTab);
  }

  @override
  Widget build(BuildContext context) {
    final isViewingSavedJobs = widget.activeTab == _jobsTabSaved;
    final selectedIcon = switch (widget.activeTab) {
      _jobsTabAll => Icons.all_inbox_outlined,
      _jobsTabUrgent => Icons.flash_on_outlined,
      _ => Icons.work_outline,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: isViewingSavedJobs
                  ? _SavedJobsBackButton(onTap: _backFromSavedJobs)
                  : _JobTypeDropdownButton(
                      icon: selectedIcon,
                      isExpanded: _isExpanded,
                      isActive: true,
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                    ),
            ),
            const SizedBox(width: 12),
            _SavedJobsIconButton(
              count: widget.savedCount,
              isActive: isViewingSavedJobs,
              onTap: isViewingSavedJobs
                  ? _backFromSavedJobs
                  : () => _selectTab(_jobsTabSaved),
            ),
          ],
        ),
        if (_isExpanded && !isViewingSavedJobs) ...[
          const SizedBox(height: 10),
          _JobTypeDropdownPanel(
            activeTab: widget.activeTab,
            allCount: widget.allCount,
            standardCount: widget.standardCount,
            urgentCount: widget.urgentCount,
            onSelected: _selectTab,
          ),
        ],
      ],
    );
  }
}

class _SavedJobsBackButton extends StatelessWidget {
  const _SavedJobsBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: 'Quay lại danh sách công việc',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('saved-jobs-back-button'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Quay lại',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JobTypeDropdownButton extends StatelessWidget {
  const _JobTypeDropdownButton({
    required this.icon,
    required this.isExpanded,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isExpanded;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final foregroundColor = isActive ? Colors.white : AppColors.primary;

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
                  child: Text(
                    'Loại công việc',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
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
    required this.allCount,
    required this.standardCount,
    required this.urgentCount,
    required this.onSelected,
  });

  final int activeTab;
  final int allCount;
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
            label: 'Tất cả công việc',
            count: allCount,
            icon: Icons.all_inbox_outlined,
            isActive: activeTab == _jobsTabAll,
            onTap: () => onSelected(_jobsTabAll),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          _JobTypeOption(
            label: 'Công việc tiêu chuẩn',
            count: standardCount,
            icon: Icons.work_outline,
            isActive: activeTab == _jobsTabStandard,
            onTap: () => onSelected(_jobsTabStandard),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          _JobTypeOption(
            label: 'Công việc Tuyển gấp',
            count: urgentCount,
            icon: Icons.flash_on_outlined,
            isActive: activeTab == _jobsTabUrgent,
            onTap: () => onSelected(_jobsTabUrgent),
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

/// A dependency-free masonry grid: cards keep their natural height instead of
/// being forced into a uniform aspect ratio. Items are distributed across
/// [crossAxisCount] columns in round-robin order, and each column is a
/// [Column] whose children size themselves to their content.
class _JobMasonryGrid extends StatelessWidget {
  const _JobMasonryGrid({
    required this.jobs,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.spacing = 12,
  });

  final List<JobPost> jobs;
  final Widget Function(BuildContext context, JobPost job) itemBuilder;
  final int crossAxisCount;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return const SizedBox.shrink();
    }

    final columns = List.generate(crossAxisCount, (_) => <JobPost>[]);
    for (var i = 0; i < jobs.length; i++) {
      columns[i % crossAxisCount].add(jobs[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var col = 0; col < crossAxisCount; col++) ...[
          if (col > 0) SizedBox(width: spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var row = 0; row < columns[col].length; row++) ...[
                  if (row > 0) SizedBox(height: spacing),
                  itemBuilder(context, columns[col][row]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
