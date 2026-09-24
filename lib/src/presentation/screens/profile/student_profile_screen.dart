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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.white, size: 28.sp),
            SizedBox(width: 10.w),
            Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
          ],
        ),
        content: Text("Are you sure you want to log out?", style: TextStyle(color: Colors.white70, fontSize: 15.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              await ref.read(authServiceProvider).signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.auth, (route) => false);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))
            ),
            child: const Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: 30.h),
                  // Avatar Header
                  CircleAvatar(
                    radius: 54.r,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage("assets/avatars/$formattedAvatarId.png"),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    user.name,
                    style: TextStyle(fontSize: 24.sp, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _badge("Student", Colors.blueGrey.shade700),
                      if (user.isCR) ...[
                        SizedBox(width: 8.w),
                        _badge("CR", const Color(0xFF1877F2)),
                      ],
                      if (user.isDev) ...[
                        SizedBox(width: 8.w),
                        _badge("Dev", Colors.amber.shade800),
                      ],
                    ],
                  ),
                  SizedBox(height: 30.h),

                  // Group 1: Read-Only Info
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: _buildGroupedCard([
                      _buildInfoRow(Icons.badge_rounded, "Internal ID", user.internalId, showDivider: true),
                      _buildInfoRow(Icons.school_rounded, "Semester", "${user.semester}th", showDivider: true),
                      _buildInfoRow(Icons.groups_rounded, "Section", user.section, showDivider: false),
                    ]),
                  ),
                  SizedBox(height: 24.h),

                  // Group 2: Actions
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Consumer(
                        builder: (context, ref, child) {
                          final syncState = ref.watch(syncControllerProvider);
                          return _buildGroupedCard([
                            _buildActionRow(
                              icon: Icons.sync_rounded,
                              title: "Sync Data",
                              trailingText: syncState.isLoading ? "Syncing..." : null,
                              trailingWidget: syncState.isLoading
                                  ? SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
                                  : null,
                              showDivider: true,
                              onTap: syncState.isLoading ? null : () async {
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
                            ),
                            _buildActionRow(
                              icon: Icons.edit_rounded,
                              title: "Edit Profile",
                              showDivider: user.isDev,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pushNamed(context, AppRoutes.editStudentProfile);
                              },
                            ),
                            if (user.isDev)
                              _buildActionRow(
                                icon: Icons.developer_mode_rounded,
                                title: "Developer Panel",
                                iconColor: Colors.amber,
                                showDivider: false,
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  DeveloperPanelSheet.show(context);
                                },
                              ),
                          ]);
                        }
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Group 3: Danger Zone
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: _buildGroupedCard([
                      _buildActionRow(
                        icon: Icons.logout_rounded,
                        title: "Log Out",
                        textColor: Colors.redAccent,
                        iconColor: Colors.redAccent,
                        showDivider: true,
                        hideChevron: true,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _showLogoutDialog(context);
                        },
                      ),
                      _buildActionRow(
                        icon: Icons.person_remove_rounded,
                        title: "Delete Account",
                        textColor: Colors.redAccent,
                        iconColor: Colors.redAccent,
                        showDivider: false,
                        hideChevron: true,
                        onTap: () {
                          HapticFeedback.heavyImpact();
                          _showDeleteAccountDialog(context, user);
                        },
                      ),
                    ]),
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

  Widget _badge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12.r)),
      child: Text(text, style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGroupedCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value, {required bool showDivider}) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Icon(icon, color: Colors.white54, size: 22.sp),
              SizedBox(width: 16.w),
              Text(title, style: TextStyle(color: Colors.white, fontSize: 16.sp)),
              const Spacer(),
              Text(value, style: TextStyle(color: Colors.white54, fontSize: 16.sp)),
            ],
          ),
        ),
        if (showDivider) Divider(color: Colors.white12, height: 1.h, indent: 54.w),
      ],
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    String? trailingText,
    Widget? trailingWidget,
    Color textColor = Colors.white,
    Color iconColor = Colors.white,
    required bool showDivider,
    bool hideChevron = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      highlightColor: Colors.white10,
      splashColor: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22.sp),
                SizedBox(width: 16.w),
                Text(title, style: TextStyle(color: textColor, fontSize: 16.sp)),
                const Spacer(),
                if (trailingText != null)
                  Text(trailingText, style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
                if (trailingWidget != null)
                  Padding(padding: EdgeInsets.only(left: 8.w), child: trailingWidget),
                if (!hideChevron)
                  Padding(
                    padding: EdgeInsets.only(left: 8.w),
                    child: Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20.sp),
                  ),
              ],
            ),
          ),
          if (showDivider) Divider(color: Colors.white12, height: 1.h, indent: 54.w),
        ],
      ),
    );
  }
}