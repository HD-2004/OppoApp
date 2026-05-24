import '../../../shared/domain/app_role.dart';

enum EmployerStatus { pendingReview, approved, rejected }

extension EmployerStatusValue on EmployerStatus {
  String get value {
    return switch (this) {
      EmployerStatus.pendingReview => 'pending_review',
      EmployerStatus.approved => 'approved',
      EmployerStatus.rejected => 'rejected',
    };
  }

  String get message {
    return switch (this) {
      EmployerStatus.pendingReview =>
        'Tài khoản nhà tuyển dụng của bạn đang được xét duyệt.',
      EmployerStatus.approved => 'Tài khoản nhà tuyển dụng đã được duyệt.',
      EmployerStatus.rejected =>
        'Tài khoản nhà tuyển dụng của bạn không được duyệt.',
    };
  }
}

class EmployerStatusParser {
  const EmployerStatusParser._();

  static EmployerStatus? fromValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'pending_review' => EmployerStatus.pendingReview,
      'approved' => EmployerStatus.approved,
      'rejected' => EmployerStatus.rejected,
      _ => null,
    };
  }
}

class AuthUserProfile {
  const AuthUserProfile({
    required this.userId,
    required this.username,
    required this.role,
    required this.email,
    required this.fullName,
    required this.kycCompleted,
    required this.profileCompleted,
    this.employerStatus,
    this.createdAt,
    this.updatedAt,
  });

  final String userId;
  final String username;
  final AppRole? role;
  final String email;
  final String fullName;
  final bool kycCompleted;
  final bool profileCompleted;
  final EmployerStatus? employerStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isEmployerApproved {
    return role == AppRole.employer &&
        employerStatus == EmployerStatus.approved;
  }

  bool get isEmployerPendingReview {
    return role == AppRole.employer &&
        employerStatus == EmployerStatus.pendingReview;
  }

  bool get isEmployerRejected {
    return role == AppRole.employer &&
        employerStatus == EmployerStatus.rejected;
  }

  AuthUserProfile copyWith({
    String? userId,
    String? username,
    AppRole? role,
    String? email,
    String? fullName,
    bool? kycCompleted,
    bool? profileCompleted,
    EmployerStatus? employerStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AuthUserProfile(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      role: role ?? this.role,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      kycCompleted: kycCompleted ?? this.kycCompleted,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      employerStatus: employerStatus ?? this.employerStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
