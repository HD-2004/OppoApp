import 'dart:async';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/auth_failure.dart';
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
    return '/candidate';
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
      return AuthState.authenticated(profile);
    } on AuthFailure catch (failure) {
      // Any AuthFailure at startup (configuration errors, 400 Bad Request from
      // Cognito when there is no session, invalid_scope, etc.) should resolve
      // to unauthenticated rather than rethrowing — a rethrow causes Riverpod
      // to schedule an infinite retry loop that floods the network with
      // repeated GetUser requests.
      safePrint('Auth session check failed at startup: ${failure.message}');
      return const AuthState.unauthenticated();
    } on SignedOutException {
      return const AuthState.unauthenticated();
    } on Exception catch (e) {
      safePrint('Auth session check failed at startup: $e');
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
    await _syncSignedInProfile(repository);
  }

  Future<void> signInWithSocialProvider(AuthProvider provider) async {
    final repository = ref.read(authRepositoryProvider);
    await repository.signInWithSocialProvider(provider);
    await _syncSignedInProfile(repository);
  }

  Future<void> _syncSignedInProfile(AuthRepository repository) async {
    final profile = await repository.fetchCurrentProfile();
    if (profile == null) {
      state = const AsyncData(AuthState.unauthenticated());
      return;
    }
    state = AsyncData(AuthState.authenticated(profile));
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
    Map<String, String>? socialLinks,
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
          socialLinks: socialLinks,
        );
    state = AsyncData(AuthState.authenticated(updated));
  }

  Future<void> toggleSavedJob(String jobId) async {
    final current = state.asData?.value.user;
    if (current == null) {
      return;
    }

    final savedList = List<String>.from(current.savedJobs ?? []);
    if (savedList.contains(jobId)) {
      savedList.remove(jobId);
    } else {
      savedList.add(jobId);
    }

    final updated = await ref
        .read(authRepositoryProvider)
        .updateProfileCompleted(
          userId: current.userId,
          completed: current.profileCompleted,
          fullName: current.fullName,
          phone: current.phone,
          cccd: current.cccd,
          dateOfBirth: current.dateOfBirth,
          location: current.location,
          title: current.title,
          bio: current.bio,
          skills: current.skills,
          profileImage: current.profileImage,
          socialLinks: current.socialLinks,
          savedJobs: savedList,
        );
    state = AsyncData(AuthState.authenticated(updated));
  }

  void pruneSavedJobs(List<String> validSavedJobs) {
    final current = state.asData?.value.user;
    if (current == null) {
      return;
    }

    final normalized = <String>[
      for (final id in validSavedJobs)
        if (id.trim().isNotEmpty) id.trim(),
    ];
    final deduped = normalized.toSet().toList(growable: false);
    final currentSaved = current.savedJobs ?? const <String>[];
    if (_sameStringList(currentSaved, deduped)) {
      return;
    }

    final optimistic = current.copyWith(savedJobs: deduped);
    state = AsyncData(AuthState.authenticated(optimistic));

    unawaited(_persistSavedJobs(optimistic, deduped));
  }

  Future<void> _persistSavedJobs(
    AuthUserProfile current,
    List<String> savedJobs,
  ) async {
    try {
      final updated = await ref
          .read(authRepositoryProvider)
          .updateProfileCompleted(
            userId: current.userId,
            completed: current.profileCompleted,
            fullName: current.fullName,
            phone: current.phone,
            cccd: current.cccd,
            dateOfBirth: current.dateOfBirth,
            location: current.location,
            title: current.title,
            bio: current.bio,
            skills: current.skills,
            profileImage: current.profileImage,
            socialLinks: current.socialLinks,
            savedJobs: savedJobs,
          );
      state = AsyncData(AuthState.authenticated(updated));
    } catch (error) {
      safePrint('Could not prune expired saved jobs: $error');
    }
  }

  Future<void> submitVerificationRequest() async {
    final current = state.asData?.value.user;
    if (current == null) {
      return;
    }

    final updated = await ref
        .read(authRepositoryProvider)
        .submitVerificationRequest(
          userId: current.userId,
          currentProfile: current,
        );
    state = AsyncData(AuthState.authenticated(updated));
  }

  Future<void> updateAvailability(
    bool isActive, {
    double? latitude,
    double? longitude,
  }) async {
    final current = state.asData?.value.user;
    if (current == null) {
      return;
    }
    final updated = await ref
        .read(authRepositoryProvider)
        .updateAvailability(
          userId: current.userId,
          isActive: isActive,
          latitude: latitude,
          longitude: longitude,
        );
    final resolved = updated.copyWith(
      isActive: isActive,
      latitude: latitude ?? updated.latitude ?? current.latitude,
      longitude: longitude ?? updated.longitude ?? current.longitude,
    );

    state = AsyncData(AuthState.authenticated(resolved));
  }
}

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
