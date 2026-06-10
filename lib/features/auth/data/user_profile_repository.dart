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
    Map<String, String>? socialLinks,
    List<String>? savedJobs,
  });

  Future<AuthUserProfile> submitVerificationRequest({required String userId});

  Future<AuthUserProfile> updateAvailability({
    required String userId,
    required bool isActive,
    double? latitude,
    double? longitude,
  });
}
