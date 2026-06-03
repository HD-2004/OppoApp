enum CandidateNotificationType {
  profileViewed,
  cvAccepted,
  cvRejected,
  newMessage,
  shiftAccepted,
  shiftConfirmed,
  shiftCompleted,
  paymentReleased,
  paymentFailed,
  kycApproved,
  kycRejected,
  jobRecommended,
  system;

  static CandidateNotificationType fromWire(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'PROFILE_VIEWED':
        return CandidateNotificationType.profileViewed;
      case 'CV_ACCEPTED':
      case 'SUCCESS':
        return CandidateNotificationType.cvAccepted;
      case 'CV_REJECTED':
        return CandidateNotificationType.cvRejected;
      case 'NEW_MESSAGE':
        return CandidateNotificationType.newMessage;
      case 'SHIFT_ACCEPTED':
        return CandidateNotificationType.shiftAccepted;
      case 'SHIFT_CONFIRMED':
        return CandidateNotificationType.shiftConfirmed;
      case 'SHIFT_COMPLETED':
        return CandidateNotificationType.shiftCompleted;
      case 'PAYMENT_RELEASED':
        return CandidateNotificationType.paymentReleased;
      case 'PAYMENT_FAILED':
        return CandidateNotificationType.paymentFailed;
      case 'KYC_APPROVED':
        return CandidateNotificationType.kycApproved;
      case 'KYC_REJECTED':
        return CandidateNotificationType.kycRejected;
      case 'JOB_RECOMMENDED':
        return CandidateNotificationType.jobRecommended;
      default:
        return CandidateNotificationType.system;
    }
  }
}
