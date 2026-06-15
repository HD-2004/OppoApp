import '../../../shared/domain/app_role.dart';

class AuthUserProfile {
  const AuthUserProfile({
    required this.userId,
    required this.username,
    required this.role,
    required this.email,
    required this.fullName,
    required this.kycCompleted,
    required this.profileCompleted,
    this.phone,
    this.cccd,
    this.dateOfBirth,
    this.location,
    this.title,
    this.bio,
    this.skills,
    this.profileImage,
    this.savedJobs,
    this.createdAt,
    this.updatedAt,
    this.verificationStatus,
    this.isActive = false,
    this.latitude,
    this.longitude,
    this.socialLinks,
  });

  final String userId;
  final String username;
  final AppRole? role;
  final String email;
  final String fullName;
  final bool kycCompleted;
  final bool profileCompleted;
  final String? phone;
  final String? cccd;
  final String? dateOfBirth;
  final String? location;
  final String? title;
  final String? bio;
  final List<String>? skills;
  final String? profileImage;
  final List<String>? savedJobs;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? verificationStatus;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final Map<String, String>? socialLinks;

  AuthUserProfile copyWith({
    String? userId,
    String? username,
    AppRole? role,
    String? email,
    String? fullName,
    bool? kycCompleted,
    bool? profileCompleted,
    String? phone,
    String? cccd,
    String? dateOfBirth,
    String? location,
    String? title,
    String? bio,
    List<String>? skills,
    String? profileImage,
    List<String>? savedJobs,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? verificationStatus,
    bool? isActive,
    double? latitude,
    double? longitude,
    Map<String, String>? socialLinks,
  }) {
    return AuthUserProfile(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      role: role ?? this.role,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      kycCompleted: kycCompleted ?? this.kycCompleted,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      phone: phone ?? this.phone,
      cccd: cccd ?? this.cccd,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      location: location ?? this.location,
      title: title ?? this.title,
      bio: bio ?? this.bio,
      skills: skills ?? this.skills,
      profileImage: profileImage ?? this.profileImage,
      savedJobs: savedJobs ?? this.savedJobs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      socialLinks: socialLinks ?? this.socialLinks,
    );
  }
}
