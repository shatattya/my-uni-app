import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Alias Firebase Auth to prevent collision with Drift's 'User' class
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

// 2. Fixed Path: Added one more '../' to reach the data folder correctly
import '../../../data/repositories/user_repository.dart';
import '../../../data/local/app_database.dart'; // Added to resolve the Drift User type

import 'student_profile_screen.dart';
import 'teacher_profile_screen.dart';

class ProfileRouter extends ConsumerStatefulWidget {
  const ProfileRouter({super.key});

  @override
  ConsumerState<ProfileRouter> createState() => _ProfileRouterState();
}

class _ProfileRouterState extends ConsumerState<ProfileRouter> {
  late Stream<User?> _userStream;
  bool _isSyncing = false;
  bool _hasSyncError = false;

  @override
  void initState() {
    super.initState();
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;

    // MEMORY FIX: Initialize the stream exactly once to prevent memory bloat during rebuilds
    if (firebaseUser != null) {
      _userStream = ref.read(userRepositoryProvider).watchUser(firebaseUser.uid);
    } else {
      _userStream = const Stream.empty();
    }
  }

  Future<void> _attemptSync(String uid) async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _hasSyncError = false;
    });

    try {
      await ref.read(userRepositoryProvider).syncUser(uid);
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _hasSyncError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the aliased firebase_auth
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      return const Center(child: Text("User not logged in", style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<User?>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF5667FD)));
        }

        if (!snapshot.hasData || snapshot.data == null) {
          // OFFLINE FIX: Trigger a sync exactly once instead of looping infinitely
          if (!_isSyncing && !_hasSyncError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _attemptSync(firebaseUser.uid);
            });
          }

          // Handle offline/sync error gracefully instead of an infinite spinner
          if (_hasSyncError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.white54, size: 48),
                  SizedBox(height: 16),
                  const Text("Offline or Sync Failed.", style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _attemptSync(firebaseUser.uid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5667FD),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Retry", style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            );
          }

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