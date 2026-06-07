import '../../../shared/domain/app_role.dart';
import '../domain/auth_user_profile.dart';

class PendingRegistrationProfile {
  const PendingRegistrationProfile({
    required this.email,
    required this.fullName,
    required this.role,
  });

  final String email;
  final String fullName;
  final AppRole role;
}

abstract class UserProfileRepository {
  Future<void> savePendingRegistration(PendingRegistrationProfile profile);

  Future<AuthUserProfile?> getByUserId(String userId);

  Future<AuthUserProfile?> getByEmail(String email);

  Future<AuthUserProfile> upsertAfterLogin({
    required String userId,
    required String username,
    required String email,
    required String fullName,
    required AppRole? role,
  });

  Future<AuthUserProfile> updateKycCompleted({
    required String userId,
    required bool completed,
  });

  Future<AuthUserProfile> updateProfileCompleted({
    required String userId,
    required bool completed,
    String? fullName,
    String? phone,
    String? cccd,
    String? dateOfBirth,
    String? location,
    String? title,
    String? bio,
    List<String>? skills,
    String? profileImage,
    List<String>? savedJobs,
  });

  Future<AuthUserProfile> submitVerificationRequest({
    required String userId,
  });

  Future<AuthUserProfile> updateAvailability({
    required String userId,
    required bool isActive,
    double? latitude,
    double? longitude,
  });
}

class InMemoryUserProfileRepository implements UserProfileRepository {
  final Map<String, AuthUserProfile> _profilesByUserId = {};
  final Map<String, PendingRegistrationProfile> _pendingByEmail = {};

  @override
  Future<void> savePendingRegistration(
    PendingRegistrationProfile profile,
  ) async {
    _pendingByEmail[profile.email.trim().toLowerCase()] = profile;
  }

  @override
  Future<AuthUserProfile?> getByUserId(String userId) async {
    return _profilesByUserId[userId];
  }

  @override
  Future<AuthUserProfile?> getByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    for (final profile in _profilesByUserId.values) {
      if (profile.email.trim().toLowerCase() == normalizedEmail) {
        return profile;
      }
    }
    return null;
  }

  @override
  Future<AuthUserProfile> upsertAfterLogin({
    required String userId,
    required String username,
    required String email,
    required String fullName,
    required AppRole? role,
  }) async {
    final existing = _profilesByUserId[userId];
    if (existing != null) {
      return existing.copyWith(
        username: username,
        email: email.isEmpty ? existing.email : email,
        fullName: fullName.isEmpty ? existing.fullName : fullName,
        role: role ?? existing.role,
        updatedAt: DateTime.now(),
      );
    }

    final pending = _pendingByEmail[email.trim().toLowerCase()];
    final resolvedRole = role ?? pending?.role;
    final now = DateTime.now();
    final profile = AuthUserProfile(
      userId: userId,
      username: username,
      role: resolvedRole,
      email: email,
      fullName: fullName.isNotEmpty ? fullName : pending?.fullName ?? '',
      kycCompleted: false,
      profileCompleted: false,
      employerStatus: resolvedRole == AppRole.employer
          ? EmployerStatus.pendingReview
          : null,
      verificationStatus: 'PENDING',
      isActive: false,
      createdAt: now,
      updatedAt: now,
    );
    _profilesByUserId[userId] = profile;
    return profile;
  }

  @override
  Future<AuthUserProfile> updateKycCompleted({
    required String userId,
    required bool completed,
  }) async {
    final profile = _requireProfile(userId);
    final updated = profile.copyWith(
      kycCompleted: completed,
      updatedAt: DateTime.now(),
    );
    _profilesByUserId[userId] = updated;
    return updated;
  }

  @override
  Future<AuthUserProfile> updateProfileCompleted({
    required String userId,
    required bool completed,
    String? fullName,
    String? phone,
    String? cccd,
    String? dateOfBirth,
    String? location,
    String? title,
    String? bio,
    List<String>? skills,
    String? profileImage,
    List<String>? savedJobs,
  }) async {
    final profile = _requireProfile(userId);
    final updated = profile.copyWith(
      fullName: fullName?.trim().isNotEmpty == true ? fullName!.trim() : null,
      phone: phone?.trim().isNotEmpty == true ? phone!.trim() : null,
      cccd: cccd?.trim().isNotEmpty == true ? cccd!.trim() : null,
      dateOfBirth: dateOfBirth?.trim().isNotEmpty == true ? dateOfBirth!.trim() : null,
      location: location?.trim().isNotEmpty == true ? location!.trim() : null,
      title: title?.trim().isNotEmpty == true ? title!.trim() : null,
      bio: bio?.trim().isNotEmpty == true ? bio!.trim() : null,
      skills: skills,
      profileImage: profileImage,
      savedJobs: savedJobs,
      profileCompleted: completed,
      updatedAt: DateTime.now(),
    );
    _profilesByUserId[userId] = updated;
    return updated;
  }

  @override
  Future<AuthUserProfile> submitVerificationRequest({
    required String userId,
  }) async {
    final profile = _requireProfile(userId);
    final updated = profile.copyWith(
      verificationStatus: 'SUBMITTED',
      updatedAt: DateTime.now(),
    );
    _profilesByUserId[userId] = updated;
    return updated;
  }

  @override
  Future<AuthUserProfile> updateAvailability({
    required String userId,
    required bool isActive,
    double? latitude,
    double? longitude,
  }) async {
    final profile = _requireProfile(userId);
    final updated = profile.copyWith(
      isActive: isActive,
      latitude: latitude,
      longitude: longitude,
      updatedAt: DateTime.now(),
    );
    _profilesByUserId[userId] = updated;
    return updated;
  }

  AuthUserProfile _requireProfile(String userId) {
    final profile = _profilesByUserId[userId];
    if (profile == null) {
      throw StateError('Không tìm thấy hồ sơ người dùng.');
    }
    return profile;
  }
}
