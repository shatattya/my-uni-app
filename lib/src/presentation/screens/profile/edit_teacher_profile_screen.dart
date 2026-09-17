import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../providers/profile_controller.dart';
import '../../../data/repositories/user_repository.dart';
import '../../widgets/avatar_picker_sheet.dart';

class EditTeacherProfileScreen extends ConsumerStatefulWidget {
  const EditTeacherProfileScreen({super.key});

  @override
  ConsumerState<EditTeacherProfileScreen> createState() => _EditTeacherProfileScreenState();
}

class _EditTeacherProfileScreenState extends ConsumerState<EditTeacherProfileScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();

  final currentPasswordController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  int currentAvatarId = 10;
  String userRole = 'teacher';
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  void _loadCurrentData() async {
    final userAuth = FirebaseAuth.instance.currentUser;
    if (userAuth != null) {
      emailController.text = userAuth.email ?? "";
      final user = await ref.read(userRepositoryProvider).watchUser(userAuth.uid).first;
      if (user != null && mounted) {
        setState(() {
          nameController.text = user.name;
          currentAvatarId = user.avatarId;
          userRole = user.role;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    currentPasswordController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void handleUpdate() {
    if (passwordController.text.isNotEmpty && passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isUpdating = true);
    ref.read(profileControllerProvider.notifier).updateTeacherProfile(
      name: nameController.text.trim(),
      avatarId: currentAvatarId,
      currentPassword: currentPasswordController.text.trim(),
      newPassword: passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedAvatarId = currentAvatarId.toString().padLeft(2, '0');

    ref.listen<AsyncValue<void>>(profileControllerProvider, (prev, next) {
      if (!_isUpdating) return;
      if (!next.isLoading) {
        setState(() => _isUpdating = false);
        if (next.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(next.error.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.redAccent)
          );
        } else if (next.hasValue) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
          );
        }
      }
    });

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Text("Edit Profile", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () {
                    AvatarPickerSheet.show(context, userRole, (id) {
                      setState(() => currentAvatarId = id);
                    });
                  },
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 45.r,
                        backgroundColor: Colors.white12,
                        backgroundImage: AssetImage("assets/avatars/$formattedAvatarId.png"),
                      ),
                      Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1877F2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2.w),
                        ),
                        child: Icon(Icons.camera_alt, color: Colors.white, size: 16.sp),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // Basic Info Group
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Column(
                  children: [
                    _buildCompactField("Full Name", nameController),
                    Divider(color: Colors.white12, height: 1.h, indent: 16.w, endIndent: 16.w),
                    _buildCompactField("E-mail", emailController, enabled: false),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Password Group (Collapsible)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                    iconColor: const Color(0xFF1877F2),
                    collapsedIconColor: Colors.white54,
                    title: Text("Change Password", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500)),
                    children: [
                      Divider(color: Colors.white12, height: 1.h),
                      _buildCompactField(
                        "Current Password",
                        currentPasswordController,
                        isPassword: true,
                        obscureText: _obscureCurrent,
                        onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                      Divider(color: Colors.white12, height: 1.h, indent: 16.w, endIndent: 16.w),
                      _buildCompactField(
                        "New Password",
                        passwordController,
                        isPassword: true,
                        obscureText: _obscureNew,
                        onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                      Divider(color: Colors.white12, height: 1.h, indent: 16.w, endIndent: 16.w),
                      _buildCompactField(
                        "Confirm New Password",
                        confirmPasswordController,
                        isPassword: true,
                        obscureText: _obscureConfirm,
                        onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      SizedBox(height: 8.h),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 40.h),
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : handleUpdate,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r))
                  ),
                  child: _isUpdating
                      ? SizedBox(height: 20.h, width: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                ),
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactField(
      String label,
      TextEditingController controller, {
        bool isPassword = false,
        bool enabled = true,
        bool obscureText = false,
        VoidCallback? onToggleVisibility,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.white : Colors.white54, fontSize: 16.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: enabled ? Colors.white54 : Colors.white30, fontSize: 14.sp),
        filled: true,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        suffixIcon: isPassword ? IconButton(
          icon: Icon(obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white54, size: 20.sp),
          onPressed: onToggleVisibility,
        ) : null,
      ),
    );
  }
}