import 'package:amplify_flutter/amplify_flutter.dart';

import '../../../shared/domain/app_role.dart';
import '../domain/auth_user_profile.dart';
import 'auth_service.dart';
import 'user_profile_repository.dart';

class RegisterRequest {
  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
  });

  final String fullName;
  final String email;
  final String password;
  final AppRole role;
}

class AuthRepository {
  const AuthRepository(this._service, this._userProfileRepository);

  final AuthService _service;
  final UserProfileRepository _userProfileRepository;

  Future<void> configureAmplify() => _service.configureAmplify();

  Future<bool> checkAuthSession() async {
    final session = await _service.checkAuthSession();
    return session.isSignedIn;
  }

  Future<void> signUp(RegisterRequest request) async {
    await _service.signUp(
      email: request.email,
      password: request.password,
      fullName: request.fullName,
      role: request.role.cognitoValue,
    );
    await _userProfileRepository.savePendingRegistration(
      PendingRegistrationProfile(
        email: request.email,
        fullName: request.fullName,
        role: request.role,
      ),
    );
  }

  Future<void> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    await _service.confirmSignUp(
      email: email,
      confirmationCode: confirmationCode,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _service.signIn(email: email, password: password);
  }

  Future<void> signOut() => _service.signOut();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _service.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> resetPassword({required String email}) {
    return _service.resetPassword(email: email);
  }

  Future<void> confirmResetPassword({
    required String email,
    required String confirmationCode,
    required String newPassword,
  }) {
    return _service.confirmResetPassword(
      email: email,
      confirmationCode: confirmationCode,
      newPassword: newPassword,
    );
  }

  Future<void> resendSignUpCode({required String email}) {
    return _service.resendSignUpCode(email: email);
  }

  Future<AuthSession> fetchAuthSession() {
    return _service.fetchAuthSession();
  }

  Future<List<AuthUserAttribute>> fetchUserAttributes() {
    return _service.fetchUserAttributes();
  }

  Future<String?> fetchUserRole() async {
    final role = await _service.fetchUserRole();
    return role?.cognitoValue;
  }

  Future<AuthUserProfile?> fetchCurrentProfile() {
    return _fetchAndUpsertProfile();
  }

  Future<AuthUserProfile?> _fetchAndUpsertProfile() async {
    final currentUser = await _service.getCurrentUser();
    if (currentUser == null) {
      return null;
    }

    final attributes = await _service.fetchUserAttributes();
    String email = '';
    String fullName = '';
    for (final attribute in attributes) {
      if (attribute.userAttributeKey.key == 'email') {
        email = attribute.value;
      }
      if (attribute.userAttributeKey.key == 'name') {
        fullName = attribute.value;
      }
    }

    final role = await _service.fetchUserRole();
    return _userProfileRepository.upsertAfterLogin(
      userId: currentUser.userId,
      username: currentUser.username,
      email: email,
      fullName: fullName,
      role: role,
    );
  }

  Future<AuthUserProfile> updateKycCompleted({
    required String userId,
    required bool completed,
  }) {
    return _userProfileRepository.updateKycCompleted(
      userId: userId,
      completed: completed,
    );
  }

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
  }) {
    return _userProfileRepository.updateProfileCompleted(
      userId: userId,
      completed: completed,
      fullName: fullName,
      phone: phone,
      cccd: cccd,
      dateOfBirth: dateOfBirth,
      location: location,
      title: title,
      bio: bio,
      skills: skills,
      profileImage: profileImage,
    );
  }
}
