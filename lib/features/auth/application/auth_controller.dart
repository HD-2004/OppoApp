import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../shared/domain/app_role.dart';
import '../data/auth_repository.dart';
import '../data/auth_service.dart';
import '../data/aws_user_profile_repository.dart';
import '../data/user_profile_repository.dart';
import '../domain/auth_user_profile.dart';
import '../domain/auth_state.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return AwsUserProfileRepository();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authServiceProvider),
    ref.watch(userProfileRepositoryProvider),
  );
});

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthState> {
  String routeAfterLogin(AuthUserProfile user) {
    if (user.role == AppRole.employer) {
      if (user.isEmployerApproved) {
        return '/employer';
      }
      if (user.isEmployerRejected) {
        return '/employer/rejected';
      }
      return '/employer/pending-review';
    }

    if (user.role == AppRole.candidate) {
      return '/candidate';
    }

    return '/missing-role';
  }

  @override
  Future<AuthState> build() async {
    final repository = ref.watch(authRepositoryProvider);

    try {
      final isSignedIn = await repository.checkAuthSession();
      if (!isSignedIn) {
        return const AuthState.unauthenticated();
      }

      final profile = await repository.fetchCurrentProfile();
      if (profile == null) {
        return const AuthState.unauthenticated();
      }
      if (profile.role == null) {
        return AuthState.missingRole(profile);
      }

      return AuthState.authenticated(profile);
    } on AuthFailure catch (failure) {
      if (failure.code == 'configuration') {
        safePrint(failure.message);
        return const AuthState.unauthenticated();
      }
      rethrow;
    } on SignedOutException {
      return const AuthState.unauthenticated();
    }
  }

  Future<void> register(RegisterRequest request) async {
    await ref.read(authRepositoryProvider).signUp(request);
    state = AsyncData(AuthState.unconfirmed(request.email));
  }

  Future<void> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    await ref
        .read(authRepositoryProvider)
        .confirmSignUp(email: email, confirmationCode: confirmationCode);
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<void> signIn({required String email, required String password}) async {
    final repository = ref.read(authRepositoryProvider);
    await repository.signIn(email: email, password: password);
    final profile = await repository.fetchCurrentProfile();
    if (profile == null) {
      state = const AsyncData(AuthState.unauthenticated());
      return;
    }

    state = AsyncData(
      profile.role == null
          ? AuthState.missingRole(profile)
          : AuthState.authenticated(profile),
    );
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return ref
        .read(authRepositoryProvider)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
  }

  Future<void> resetPassword({required String email}) {
    return ref.read(authRepositoryProvider).resetPassword(email: email);
  }

  Future<void> confirmResetPassword({
    required String email,
    required String confirmationCode,
    required String newPassword,
  }) {
    return ref
        .read(authRepositoryProvider)
        .confirmResetPassword(
          email: email,
          confirmationCode: confirmationCode,
          newPassword: newPassword,
        );
  }

  Future<void> resendSignUpCode({required String email}) {
    return ref.read(authRepositoryProvider).resendSignUpCode(email: email);
  }

  Future<void> completeKyc() async {
    final current = state.asData?.value.user;
    if (current == null) {
      return;
    }

    final updated = await ref
        .read(authRepositoryProvider)
        .updateKycCompleted(userId: current.userId, completed: true);
    state = AsyncData(AuthState.authenticated(updated));
  }

  Future<void> completeProfile({
    String? fullName,
    String? phone,
    String? cccd,
    String? dateOfBirth,
    String? location,
    String? title,
    String? bio,
    List<String>? skills,
    String? profileImage,
  }) async {
    final current = state.asData?.value.user;
    if (current == null) {
      return;
    }

    final updated = await ref
        .read(authRepositoryProvider)
        .updateProfileCompleted(
          userId: current.userId,
          completed: true,
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
    state = AsyncData(AuthState.authenticated(updated));
  }
}
