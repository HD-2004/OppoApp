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
    return ChatMessage(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      sender: json['sender']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'time': time,
    };
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
    required this.status,
    required this.appliedAt,
    required this.updatedAt,
    required this.chatMessages,
  });

  factory CandidateApplication.fromJson(Map<String, dynamic> json) {
    final messagesList = json['chatMessages'] as List?;
    final messages = messagesList != null
        ? messagesList
            .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList()
        : <ChatMessage>[];

    return CandidateApplication(
      applicationId: json['applicationId']?.toString() ?? '',
      jobId: json['jobId']?.toString() ?? '',
      jobTitle: json['jobTitle']?.toString() ?? '',
      jobType: json['jobType']?.toString() ?? '',
      candidateId: json['candidateId']?.toString() ?? '',
      candidateEmail: json['candidateEmail']?.toString() ?? '',
      employerId: json['employerId']?.toString() ?? '',
      employerEmail: json['employerEmail']?.toString() ?? '',
      employerName: json['employerName']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      appliedAt: DateTime.tryParse(json['appliedAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      chatMessages: messages,
    );
  }
}
