import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/repositories/user_repository.dart';
import '../../../data/local/app_database.dart';
import '../../../providers/sync_controller.dart';
import '../../widgets/developer_panel_sheet.dart';
import '../../../services/auth_service.dart';
import '../../routes/app_router.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  late Stream<User?> _userStream;

  @override
  void initState() {
    super.initState();
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _userStream = ref.read(userRepositoryProvider).watchUser(firebaseUser.uid);
    } else {
      _userStream = const Stream.empty();
    }
  }

  void _showDeleteAccountDialog(BuildContext context, User user) {
    final passwordController = TextEditingController();
    bool isDeleting = false;
    bool obscureText = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28.sp),
                  SizedBox(width: 10.w),
                  Text("Delete Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "This action is permanent and cannot be undone. All your offline and cloud data will be erased.\n\nPlease enter your password to confirm.",
                      style: TextStyle(color: Colors.white70, fontSize: 14.sp, height: 1.4)
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: passwordController,
                    obscureText: obscureText,
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    decoration: InputDecoration(
                        hintText: "Password",
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                        suffixIcon: IconButton(
                          icon: Icon(obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white54, size: 20.sp),
                          onPressed: () => setState(() => obscureText = !obscureText),
                        )
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: isDeleting ? null : () async {
                    if (passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Password is required"), backgroundColor: Colors.redAccent)
                      );
                      return;
                    }

                    setState(() => isDeleting = true);

                    try {
                      await ref.read(authServiceProvider).deleteAccount(
                        password: passwordController.text,
                        role: 'student',
                        docId: user.internalId,
                      );

                      if (!ctx.mounted) return;
                      Navigator.of(ctx, rootNavigator: true).pushNamedAndRemoveUntil(
                        AppRoutes.auth,
                            (route) => false,
                      );
                    } catch (e) {
                      setState(() => isDeleting = false);
                      if (ctx.mounted) {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))
                  ),
                  child: isDeleting
                      ? SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return Center(child: Text("Not logged in", style: TextStyle(fontSize: 16.sp, color: Colors.white)));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<User?>(
          stream: _userStream,
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
                        HapticFeedback.mediumImpact();
                        DeveloperPanelSheet.show(context);
                      },
                    ),
                  ],
                  SizedBox(height: 24.h),
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      await ref.read(authServiceProvider).signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.auth,
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
                                  HapticFeedback.lightImpact();
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
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pushNamed(context, AppRoutes.editStudentProfile);
                          },
                        ),
                        SizedBox(height: 25.h),
                        _actionRow(
                          icon: Icons.delete_outline,
                          title: "Delete Account",
                          action: "Delete",
                          color: Colors.redAccent,
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            _showDeleteAccountDialog(context, user);
                          },
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