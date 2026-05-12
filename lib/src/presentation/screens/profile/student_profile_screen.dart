import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil

import '../../../data/repositories/user_repository.dart';
import 'edit_student_profile_screen.dart';
import '../auth/auth_wrapper.dart';
import '../../../providers/sync_controller.dart';
import '../../widgets/developer_panel_sheet.dart'; // MODIFICATION: Import the new Dev Menu

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

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
              return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)));
            }

            if (!snapshot.hasData || snapshot.data == null) return const SizedBox();

            final user = snapshot.data!;
            final formattedAvatarId = user.avatarId.toString().padLeft(2, '0');

            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 40.h),
                  CircleAvatar(
                    radius: 60.r,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage("assets/avatars/$formattedAvatarId.png"),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    user.name,
                    style: TextStyle(fontSize: 24.sp, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16.h),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _badge("Student"),
                      if (user.isCR) ...[
                        SizedBox(width: 8.w),
                        _badge("CR"),
                      ],
                      if (user.isDev) ...[
                        SizedBox(width: 8.w),
                        _badge("Dev"),
                      ],
                    ],
                  ),

                  // MODIFICATION: The updated Developer Menu Button
                  if (user.isDev) ...[
                    SizedBox(height: 20.h),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E1E),
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.amber, width: 1.5.w),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      ),
                      icon: Icon(Icons.developer_mode, color: Colors.amber, size: 22.sp),
                      label: Text("Developer Panel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      onPressed: () {
                        DeveloperPanelSheet.show(context);
                      },
                    ),
                  ],

                  SizedBox(height: 24.h),

                  GestureDetector(
                    onTap: () async {
                      await firebase_auth.FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthWrapper()),
                            (route) => false,
                      );
                    },
                    child: Text("Log out", style: TextStyle(color: Colors.redAccent, fontSize: 16.sp, fontWeight: FontWeight.w500)),
                  ),

                  SizedBox(height: 40.h),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30.w),
                    child: Column(
                      children: [
                        _infoRow(Icons.badge_outlined, "Internal ID", user.internalId),
                        SizedBox(height: 20.h),
                        _infoRow(Icons.school_outlined, "Semester", "${user.semester}th"),
                        SizedBox(height: 20.h),
                        _infoRow(Icons.stars_outlined, "Section", user.section),
                      ],
                    ),
                  ),

                  SizedBox(height: 40.h),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30.w),
                    child: Column(
                      children: [
                        Consumer(
                            builder: (context, ref, child) {
                              final syncState = ref.watch(syncControllerProvider);

                              return _actionRow(
                                icon: Icons.sync_outlined,
                                title: "Sync Data",
                                action: syncState.isLoading ? "Syncing..." : "Sync",
                                color: syncState.isLoading ? Colors.white54 : const Color(0xFF1877F2),
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
                        SizedBox(height: 25.h),
                        _actionRow(
                          icon: Icons.edit_outlined,
                          title: "Edit Profile",
                          action: "Edit",
                          color: const Color(0xFF1877F2),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditStudentProfileScreen())),
                        ),
                        SizedBox(height: 25.h),
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
                  SizedBox(height: 40.h),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      decoration: BoxDecoration(color: const Color(0xFF1877F2), borderRadius: BorderRadius.circular(20.r)),
      child: Text(text, style: TextStyle(color: Colors.white, fontSize: 12.sp)),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 22.sp),
        SizedBox(width: 15.w),
        Text("$title : ", style: TextStyle(color: Colors.white70, fontSize: 16.sp)),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 16.sp)),
      ],
    );
  }

  Widget _actionRow({required IconData icon, required String title, required String action, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      splashColor: color.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22.sp),
            SizedBox(width: 15.w),
            Text(title, style: TextStyle(color: Colors.white, fontSize: 16.sp)),
            const Spacer(),
            Text(action, style: TextStyle(color: color, fontSize: 16.sp)),
          ],
        ),
      ),
    );
  }
}