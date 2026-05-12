import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

final profileControllerProvider = AsyncNotifierProvider<ProfileController, void>(() {
  return ProfileController();
});

class ProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateStudentProfile({
    required String name,
    required int semester,
    required String section,
    required int avatarId,
    String? currentPassword, // Added parameter
    String? newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      // 1. Update Password if provided
      if (newPassword != null && newPassword.isNotEmpty) {
        if (currentPassword == null || currentPassword.isEmpty) {
          throw Exception("Current password is required to set a new password.");
        }

        try {
          // Re-authenticate the user silently to satisfy Firebase's security requirement
          final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
          await user.reauthenticateWithCredential(cred);

          // Now safely update the password
          await user.updatePassword(newPassword);
        } on FirebaseAuthException catch (e) {
          throw Exception(e.message ?? "Failed to update password");
        }
      }

      // 2. Update Database
      await ref.read(userRepositoryProvider).updateProfile(
        uid: user.uid,
        name: name,
        semester: semester,
        section: section,
        avatarId: avatarId,
      );
    });
  }

  Future<void> updateTeacherProfile({
    required int avatarId,
    String? currentPassword, // Added parameter
    String? newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      if (newPassword != null && newPassword.isNotEmpty) {
        if (currentPassword == null || currentPassword.isEmpty) {
          throw Exception("Current password is required to set a new password.");
        }

        try {
          // Re-authenticate the user silently to satisfy Firebase's security requirement
          final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
          await user.reauthenticateWithCredential(cred);

          // Now safely update the password
          await user.updatePassword(newPassword);
        } on FirebaseAuthException catch (e) {
          throw Exception(e.message ?? "Failed to update password");
        }
      }
      await ref.read(userRepositoryProvider).updateTeacherAvatar(user.uid, avatarId);
    });
  }
}