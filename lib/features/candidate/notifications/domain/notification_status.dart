enum CandidateNotificationStatus {
  unread,
  read,
  archived;

  static CandidateNotificationStatus fromWire(String? value, {bool? read}) {
    switch ((value ?? '').toUpperCase()) {
      case 'UNREAD':
        return CandidateNotificationStatus.unread;
      case 'READ':
        return CandidateNotificationStatus.read;
      case 'ARCHIVED':
        return CandidateNotificationStatus.archived;
      default:
        return read == true
            ? CandidateNotificationStatus.read
            : CandidateNotificationStatus.unread;
    }
  }
}
