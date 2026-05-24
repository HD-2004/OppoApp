enum JobPostType { urgent, partTime }

extension JobPostTypeLabel on JobPostType {
  String get label {
    return switch (this) {
      JobPostType.urgent => 'Urgent shift',
      JobPostType.partTime => 'Part-time',
    };
  }
}

class JobPost {
  const JobPost({
    required this.id,
    required this.employerName,
    required this.title,
    required this.jobType,
    required this.location,
    required this.salary,
    required this.shiftTime,
    required this.description,
    required this.tags,
    required this.postedAt,
    this.employerAvatarUrl,
    this.isSaved = false,
  });

  final String id;
  final String employerName;
  final String? employerAvatarUrl;
  final String title;
  final JobPostType jobType;
  final String location;
  final String salary;
  final String shiftTime;
  final String description;
  final List<String> tags;
  final DateTime postedAt;
  final bool isSaved;
}
