enum JobPostType { urgent, partTime, fullTime }

extension JobPostTypeLabel on JobPostType {
  String get label {
    return switch (this) {
      JobPostType.urgent => 'Tuyển gấp',
      JobPostType.partTime => 'Bán thời gian',
      JobPostType.fullTime => 'Toàn thời gian',
    };
  }
}

class JobPost {
  const JobPost({
    required this.id,
    required this.idJob,
    required this.employerId,
    required this.employerName,
    required this.title,
    required this.jobType,
    required this.location,
    this.latitude,
    this.longitude,
    required this.salary,
    required this.shiftTime,
    required this.description,
    required this.tags,
    required this.postedAt,
    this.recruitmentStartDate,
    this.recruitmentEndDate,
    this.status = 'active',
    this.employerAvatarUrl,
    this.isSaved = false,
    this.isQuickJob = false,
    this.workHours,
    this.workDays,
    this.responsibilities,
    this.requirements,
    this.benefits,
    this.workDate,
    this.companyName,
    this.hourlyRate,
    this.totalHours,
    this.totalSalary,
    this.startTime,
    this.endTime,
    this.applicants = 0,
    this.views = 0,
    this.visibilityScore = 0,
    this.employerReputationScore = 0,
    this.candidateRatingScore = 0,
    this.isAiScreeningEnabled = false,
    this.customQuestions = const [],
  });

  final String id;
  final String idJob;
  final String employerId;
  final String employerName;
  final String? employerAvatarUrl;
  final String title;
  final JobPostType jobType;
  final String location;
  final double? latitude;
  final double? longitude;
  final String salary;
  final String shiftTime;
  final String description;
  final List<String> tags;
  final DateTime postedAt;
  final DateTime? recruitmentStartDate;
  final DateTime? recruitmentEndDate;
  final String status;
  final bool isSaved;
  final bool isQuickJob;
  final String? workHours;
  final String? workDays;
  final String? responsibilities;
  final String? requirements;
  final String? benefits;
  final String? workDate;
  final String? companyName;
  final int? hourlyRate;
  final double? totalHours;
  final int? totalSalary;
  final String? startTime;
  final String? endTime;
  final int applicants;
  final int views;
  final double visibilityScore;
  final double employerReputationScore;
  final double candidateRatingScore;
  final bool isAiScreeningEnabled;
  final List<String> customQuestions;

  JobPost copyWith({
    bool? isSaved,
    DateTime? recruitmentStartDate,
    DateTime? recruitmentEndDate,
    String? status,
    bool? isAiScreeningEnabled,
    List<String>? customQuestions,
  }) {
    return JobPost(
      id: id,
      idJob: idJob,
      employerId: employerId,
      employerName: employerName,
      employerAvatarUrl: employerAvatarUrl,
      title: title,
      jobType: jobType,
      location: location,
      latitude: latitude,
      longitude: longitude,
      salary: salary,
      shiftTime: shiftTime,
      description: description,
      tags: tags,
      postedAt: postedAt,
      recruitmentStartDate: recruitmentStartDate ?? this.recruitmentStartDate,
      recruitmentEndDate: recruitmentEndDate ?? this.recruitmentEndDate,
      status: status ?? this.status,
      isSaved: isSaved ?? this.isSaved,
      isQuickJob: isQuickJob,
      workHours: workHours,
      workDays: workDays,
      workDate: workDate,
      responsibilities: responsibilities,
      requirements: requirements,
      benefits: benefits,
      applicants: applicants,
      views: views,
      visibilityScore: visibilityScore,
      employerReputationScore: employerReputationScore,
      candidateRatingScore: candidateRatingScore,
      companyName: companyName,
      hourlyRate: hourlyRate,
      totalHours: totalHours,
      totalSalary: totalSalary,
      startTime: startTime,
      endTime: endTime,
      isAiScreeningEnabled: isAiScreeningEnabled ?? this.isAiScreeningEnabled,
      customQuestions: customQuestions ?? this.customQuestions,
    );
  }
}
