class ChatMessage {
  final int id;
  final String sender;
  final String text;
  final String time;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['messageId'] ?? json['createdAt'];
    return ChatMessage(
      id: _messageId(rawId),
      sender: json['sender']?.toString() ?? '',
      text: (json['text'] ?? json['message'] ?? '').toString(),
      time: (json['time'] ?? json['sentAt'] ?? '').toString(),
    );
  }

  static int _messageId(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    final text = value?.toString() ?? '';
    final numeric = num.tryParse(text);
    if (numeric != null) return numeric.toInt();

    return DateTime.tryParse(text)?.millisecondsSinceEpoch ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'sender': sender, 'text': text, 'time': time};
  }
}

class CandidateApplication {
  final String applicationId;
  final String jobId;
  final String jobTitle;
  final String jobType;
  final String candidateId;
  final String candidateEmail;
  final String employerId;
  final String employerEmail;
  final String employerName;
  final String? employerAvatarUrl;
  final String status;
  final DateTime appliedAt;
  final DateTime updatedAt;
  final List<ChatMessage> chatMessages;

  CandidateApplication({
    required this.applicationId,
    required this.jobId,
    required this.jobTitle,
    required this.jobType,
    required this.candidateId,
    required this.candidateEmail,
    required this.employerId,
    required this.employerEmail,
    required this.employerName,
    this.employerAvatarUrl,
    required this.status,
    required this.appliedAt,
    required this.updatedAt,
    required this.chatMessages,
  });

  factory CandidateApplication.fromJson(Map<String, dynamic> json) {
    final messages = _messagesFrom(json['chatMessages']);

    return CandidateApplication(
      applicationId: (json['applicationId'] ?? json['id'] ?? '').toString(),
      jobId: (json['jobId'] ?? json['idJob'] ?? json['jobID'] ?? '').toString(),
      jobTitle: (json['jobTitle'] ?? json['title'] ?? '').toString(),
      jobType: (json['jobType'] ?? json['type'] ?? '').toString(),
      candidateId: (json['candidateId'] ?? '').toString(),
      candidateEmail: (json['candidateEmail'] ?? '').toString(),
      employerId: (json['employerId'] ?? '').toString(),
      employerEmail: (json['employerEmail'] ?? '').toString(),
      employerName: (json['employerName'] ?? json['companyName'] ?? '')
          .toString(),
      employerAvatarUrl: (json['employerAvatarUrl'] ?? json['companyLogo'] ?? json['logoUrl'] ?? json['avatarUrl'] ?? json['profileImage'])?.toString(),
      status: (json['status'] ?? '').toString().toLowerCase(),
      appliedAt: _dateFrom(json['appliedAt'] ?? json['createdAt']),
      updatedAt: _dateFrom(
        json['updatedAt'] ?? json['appliedAt'] ?? json['createdAt'],
      ),
      chatMessages: messages,
    );
  }

  static List<ChatMessage> _messagesFrom(Object? value) {
    if (value is! List) return <ChatMessage>[];

    final messages = value
        .whereType<Map>()
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return messages;
  }

  static DateTime _dateFrom(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
    }
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}
