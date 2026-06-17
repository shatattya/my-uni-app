import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

// BUG FIX: Added AutoDispose to prevent stale error/loading states from being
// cached when the user navigates away from the profile screens.
final profileControllerProvider = AutoDisposeAsyncNotifierProvider<ProfileController, void>(() {
  return ProfileController();
});

class ProfileController extends AutoDisposeAsyncNotifier<void> {
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

      await ref.read(userRepositoryProvider).updateProfile(
        uid: user.uid,
        name: name,
        semester: semester,
        section: section,
        avatarId: avatarId,
      );
    });
  }

  // MODIFICATION: Added the 'name' parameter here to pass it to the repository
  Future<void> updateTeacherProfile({
    required String name,
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

      // MODIFICATION: Updated to call the new repository method with the name
      await ref.read(userRepositoryProvider).updateTeacherProfile(user.uid, name, avatarId);
    });
  }
}