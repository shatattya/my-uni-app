import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil

import '../../../data/repositories/user_repository.dart';
import 'edit_teacher_profile_screen.dart';
import '../auth/auth_wrapper.dart';
import '../../../providers/sync_controller.dart';
import '../../../services/auth_service.dart'; // Added: Import AuthService for secure logout

class TeacherProfileScreen extends ConsumerWidget {
  const TeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return Center(child: Text("Not logged in", style: TextStyle(fontSize: 16.sp, color: Colors.white)));

    final userStream = ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder(
          stream: userStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2))); // Premium Blue
            }

            if (!snapshot.hasData || snapshot.data == null) return const SizedBox();

            final user = snapshot.data!;
            final formattedAvatarId = user.avatarId.toString().padLeft(2, '0');
            final String email = firebaseUser.email ?? user.internalId;

            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 40.h), // Scaled
                  CircleAvatar(
                    radius: 60.r, // Scaled
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage("assets/avatars/$formattedAvatarId.png"),
                  ),
                  SizedBox(height: 20.h), // Scaled
                  Text(
                    user.name,
                    style: TextStyle(fontSize: 24.sp, color: Colors.white, fontWeight: FontWeight.bold), // Scaled
                  ),
                  SizedBox(height: 16.h), // Scaled

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h), // Scaled
                    decoration: BoxDecoration(color: const Color(0xFF1877F2), borderRadius: BorderRadius.circular(20.r)), // Premium Blue & Scaled
                    child: Text("Teacher", style: TextStyle(color: Colors.white, fontSize: 12.sp)), // Scaled
                  ),

                  SizedBox(height: 24.h), // Scaled

                  GestureDetector(
                    onTap: () async {
                      // MODIFICATION: Use the centralized secure sign-out to wipe DB and clear FCM token
                      await ref.read(authServiceProvider).signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthWrapper()),
                            (route) => false,
                      );
                    },
                    child: Text("Log out", style: TextStyle(color: Colors.redAccent, fontSize: 16.sp, fontWeight: FontWeight.w500)), // Scaled
                  ),

                  SizedBox(height: 60.h), // Scaled

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30.w), // Scaled
                    child: Row(
                      children: [
                        Icon(Icons.badge_outlined, color: Colors.white, size: 22.sp), // Scaled
                        SizedBox(width: 15.w), // Scaled
                        Text("E-mail : $email", style: TextStyle(color: Colors.white, fontSize: 16.sp)), // Scaled
                      ],
                    ),
                  ),

                  SizedBox(height: 40.h), // Scaled

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30.w), // Scaled
                    child: Column(
                      children: [
                        Consumer(
                            builder: (context, ref, child) {
                              final syncState = ref.watch(syncControllerProvider);

                              return _actionRow(
                                icon: Icons.sync_outlined,
                                title: "Sync Data",
                                action: syncState.isLoading ? "Syncing..." : "Sync",
                                color: syncState.isLoading ? Colors.white54 : const Color(0xFF1877F2), // Premium Blue
                                onTap: syncState.isLoading ? () {} : () async {
                                  try {
                                    await ref.read(syncControllerProvider.notifier).syncAllData();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Data synced successfully!"), backgroundColor: Colors.green),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                },
                              );
                            }
                        ),
                        SizedBox(height: 25.h), // Scaled
                        _actionRow(
                          icon: Icons.edit_outlined,
                          title: "Edit Profile",
                          action: "Edit",
                          color: const Color(0xFF1877F2), // Premium Blue
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditTeacherProfileScreen())),
                        ),
                        SizedBox(height: 25.h), // Scaled
                        _actionRow(
                          icon: Icons.delete_outline,
                          title: "Delete Account",
                          action: "Delete",
                          color: Colors.redAccent,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40.h), // Scaled
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String action,
    required Color color,
    required VoidCallback onTap
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r), // Scaled
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w), // Scaled
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22.sp), // Scaled
              SizedBox(width: 15.w), // Scaled
              Text(title, style: TextStyle(color: Colors.white, fontSize: 16.sp)), // Scaled
              const Spacer(),
              Text(action, style: TextStyle(color: color, fontSize: 16.sp)), // Scaled
            ],
          ),
        ),
      ),
    );
  }
}