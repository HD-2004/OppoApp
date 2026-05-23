enum UrgentShiftStatus { draft, open, filled, inProgress, completed, cancelled }

class UrgentShiftJob {
  const UrgentShiftJob({
    required this.jobId,
    required this.employerId,
    required this.title,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.startTime,
    required this.endTime,
    required this.payAmount,
    required this.currency,
    required this.requiredWorkers,
    required this.acceptedWorkers,
    required this.status,
  });

  final String jobId;
  final String employerId;
  final String title;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime startTime;
  final DateTime endTime;
  final int payAmount;
  final String currency;
  final int requiredWorkers;
  final int acceptedWorkers;
  final UrgentShiftStatus status;

  bool get hasOpenSlots => acceptedWorkers < requiredWorkers;

  UrgentShiftJob copyWith({int? acceptedWorkers, UrgentShiftStatus? status}) {
    return UrgentShiftJob(
      jobId: jobId,
      employerId: employerId,
      title: title,
      category: category,
      address: address,
      latitude: latitude,
      longitude: longitude,
      startTime: startTime,
      endTime: endTime,
      payAmount: payAmount,
      currency: currency,
      requiredWorkers: requiredWorkers,
      acceptedWorkers: acceptedWorkers ?? this.acceptedWorkers,
      status: status ?? this.status,
    );
  }
}
