import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Alias Firebase Auth to prevent collision with Drift's 'User' class
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

// 2. Fixed Path: Added one more '../' to reach the data folder correctly
import '../../../data/repositories/user_repository.dart';

import 'student_profile_screen.dart';
import 'teacher_profile_screen.dart';

class ProfileRouter extends ConsumerWidget {
  const ProfileRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the aliased firebase_auth
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Center(child: Text("User not logged in", style: TextStyle(color: Colors.white)));
    }

    // OFFLINE FIRST: Watch the local database!
    final userStream = ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid);

    return StreamBuilder(
      stream: userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF5667FD)));
        }

        if (!snapshot.hasData || snapshot.data == null) {
          // If local DB is empty, trigger a sync and show loading
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(userRepositoryProvider).syncUser(firebaseUser.uid);
          });
          return const Center(child: CircularProgressIndicator(color: Color(0xFF5667FD)));
        }

        // Because the import is fixed, Flutter now knows this is a Drift User!
        final role = snapshot.data!.role;

        if (role == "teacher") {
          return const TeacherProfileScreen();
        }

        return const StudentProfileScreen();
      },
    );
  }
}