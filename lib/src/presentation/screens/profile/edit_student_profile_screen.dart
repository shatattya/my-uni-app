import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../providers/profile_controller.dart';
import '../../../data/repositories/user_repository.dart';
import '../../widgets/avatar_picker_sheet.dart';

class EditStudentProfileScreen extends ConsumerStatefulWidget {
  const EditStudentProfileScreen({super.key});

  @override
  ConsumerState<EditStudentProfileScreen> createState() => _EditStudentProfileScreenState();
}

class _EditStudentProfileScreenState extends ConsumerState<EditStudentProfileScreen> {
  final nameController = TextEditingController();
  final semesterController = TextEditingController();
  final sectionController = TextEditingController();

  final currentPasswordController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  int currentAvatarId = 1;
  String userRole = 'student';
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  void _loadCurrentData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final user = await ref.read(userRepositoryProvider).watchUser(uid).first;
      if (user != null && mounted) {
        setState(() {
          nameController.text = user.name;
          semesterController.text = user.semester.toString();
          sectionController.text = user.section;
          currentAvatarId = user.avatarId;
          userRole = user.role;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    semesterController.dispose();
    sectionController.dispose();
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
    ref.read(profileControllerProvider.notifier).updateStudentProfile(
      name: nameController.text.trim(),
      semester: int.parse(semesterController.text),
      section: sectionController.text.trim(),
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
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(next.error.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.redAccent)
          );
        } else if (next.hasValue) {
          if (!context.mounted) return;
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
                    _buildCompactField(
                      "Full Name",
                      nameController,
                      maxLength: 35,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]'))],
                    ),
                    Divider(color: Colors.white12, height: 1.h, indent: 16.w, endIndent: 16.w),
                    _buildCompactField("Semester", semesterController, isNumber: true),
                    Divider(color: Colors.white12, height: 1.h, indent: 16.w, endIndent: 16.w),
                    _buildCompactField(
                      "Section",
                      sectionController,
                      maxLength: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-cA-C]')),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
                        }),
                      ],
                    ),
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
        bool isNumber = false,
        bool isPassword = false,
        bool obscureText = false,
        VoidCallback? onToggleVisibility,
        List<TextInputFormatter>? inputFormatters,
        int? maxLength,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: Colors.white, fontSize: 16.sp),
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white54, fontSize: 14.sp),
        counterText: "",
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