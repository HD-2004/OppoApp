import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../candidate/application/jobs_providers.dart';
import '../../../candidate/domain/job_post.dart';

// ── Enums & value objects ─────────────────────────────────────────────────────

enum JobTab { normal, urgent }

class JobsFilter {
  const JobsFilter({
    this.location = '',
    this.salaryRange = '',
    this.industry = '',
    this.keyword = '',
    this.sortBy = 'newest',
  });

  final String location;
  final String salaryRange;
  final String industry;
  final String keyword;
  final String sortBy;

  JobsFilter copyWith({
    String? location,
    String? salaryRange,
    String? industry,
    String? keyword,
    String? sortBy,
  }) {
    return JobsFilter(
      location: location ?? this.location,
      salaryRange: salaryRange ?? this.salaryRange,
      industry: industry ?? this.industry,
      keyword: keyword ?? this.keyword,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  bool get hasActiveFilter =>
      location.isNotEmpty ||
      salaryRange.isNotEmpty ||
      industry.isNotEmpty ||
      keyword.isNotEmpty;

  JobsFilter cleared() => const JobsFilter();
}

// ── State ─────────────────────────────────────────────────────────────────────

class JobsState {
  const JobsState({
    this.tab = JobTab.normal,
    this.filter = const JobsFilter(),
    this.standardJobs = const [],
    this.urgentJobs = const [],
    this.isLoading = false,
    this.error,
  });

  final JobTab tab;
  final JobsFilter filter;
  final List<JobPost> standardJobs;
  final List<JobPost> urgentJobs;
  final bool isLoading;
  final String? error;

  JobsState copyWith({
    JobTab? tab,
    JobsFilter? filter,
    List<JobPost>? standardJobs,
    List<JobPost>? urgentJobs,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return JobsState(
      tab: tab ?? this.tab,
      filter: filter ?? this.filter,
      standardJobs: standardJobs ?? this.standardJobs,
      urgentJobs: urgentJobs ?? this.urgentJobs,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<JobPost> get filteredJobs {
    final base = tab == JobTab.urgent ? urgentJobs : standardJobs;
    return _applyFilter(base);
  }

  // Unique locations derived from real job data (not hardcoded)
  List<String> get availableLocations {
    final locs = <String>{};
    for (final job in [...standardJobs, ...urgentJobs]) {
      final d = _extractDistrict(job.location);
      if (d.isNotEmpty) locs.add(d);
    }
    final list = locs.toList()..sort();
    return list;
  }

  // Unique industries derived from job tags (not hardcoded)
  List<String> get availableIndustries {
    final set = <String>{};
    for (final job in [...standardJobs, ...urgentJobs]) {
      for (final tag in job.tags) {
        if (tag.isNotEmpty) set.add(tag);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  // Fixed salary ranges (units, not job data)
  static const List<String> salaryRanges = [
    'Dưới 25k/giờ',
    '25k - 40k/giờ',
    'Trên 40k/giờ',
    'Thỏa thuận',
  ];

  // ── Private helpers ─────────────────────────────────────────────────────────

  List<JobPost> _applyFilter(List<JobPost> jobs) {
    var result = jobs;

    if (filter.keyword.isNotEmpty) {
      final kw = filter.keyword.toLowerCase();
      result = result.where((j) {
        return j.title.toLowerCase().contains(kw) ||
            j.employerName.toLowerCase().contains(kw) ||
            (j.companyName?.toLowerCase().contains(kw) ?? false) ||
            j.description.toLowerCase().contains(kw) ||
            j.tags.any((t) => t.toLowerCase().contains(kw));
      }).toList();
    }

    if (filter.location.isNotEmpty) {
      result = result
          .where(
            (j) => j.location.toLowerCase().contains(
              filter.location.toLowerCase(),
            ),
          )
          .toList();
    }

    if (filter.industry.isNotEmpty) {
      result = result
          .where(
            (j) => j.tags.any(
              (t) => t.toLowerCase().contains(filter.industry.toLowerCase()),
            ),
          )
          .toList();
    }

    if (filter.salaryRange.isNotEmpty) {
      result = result.where(_matchesSalary).toList();
    }

    if (filter.sortBy == 'newest') {
      result = [...result]..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    } else if (filter.sortBy == 'salary_desc') {
      result = [...result]
        ..sort((a, b) => _salaryValue(b).compareTo(_salaryValue(a)));
    }

    return result;
  }

  bool _matchesSalary(JobPost j) {
    final rate = j.isQuickJob
        ? (j.hourlyRate ?? 0)
        : _parseSalaryToHourly(j.salary);
    switch (filter.salaryRange) {
      case 'Dưới 25k/giờ':
        return rate > 0 && rate < 25000;
      case '25k - 40k/giờ':
        return rate >= 25000 && rate <= 40000;
      case 'Trên 40k/giờ':
        return rate > 40000;
      case 'Thỏa thuận':
        return rate == 0;
      default:
        return true;
    }
  }

  int _salaryValue(JobPost j) =>
      j.isQuickJob ? (j.hourlyRate ?? 0) : _parseSalaryToHourly(j.salary);

  int _parseSalaryToHourly(String salary) {
    final clean = salary.replaceAll('.', '').replaceAll(',', '');
    final match = RegExp(r'\d+').firstMatch(clean);
    return match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
  }

  String _extractDistrict(String location) {
    if (location.isEmpty) return '';
    return location.split(',').first.trim();
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final jobsControllerProvider = AsyncNotifierProvider<JobsController, JobsState>(
  JobsController.new,
);

class JobsController extends AsyncNotifier<JobsState> {
  @override
  Future<JobsState> build() async {
    return _fetch();
  }

  Future<JobsState> _fetch() async {
    final standard = await ref.read(activeJobsProvider.future);
    final urgent = await ref.read(activeQuickJobsProvider.future);
    // Preserve current filter & tab when refreshing
    final current = state.asData?.value ?? const JobsState();
    return current.copyWith(
      standardJobs: standard,
      urgentJobs: urgent,
      isLoading: false,
      clearError: true,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  void setTab(JobTab tab) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(tab: tab));
  }

  void setFilter(JobsFilter filter) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(filter: filter));
  }

  void clearFilters() {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(filter: const JobsFilter()));
  }

  void setKeyword(String kw) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(filter: current.filter.copyWith(keyword: kw)),
    );
  }
}
