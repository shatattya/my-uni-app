import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil
import '../../../providers/profile_controller.dart';
import '../../../data/repositories/user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final profileState = ref.watch(profileControllerProvider);
    final formattedAvatarId = currentAvatarId.toString().padLeft(2, '0');

    // BUG FIX: The Rock-Solid Listener
    ref.listen<AsyncValue<void>>(profileControllerProvider, (prev, next) {
      // ONLY fire if we were explicitly loading and now we are not. Prevents firing on initial screen load.
      if (prev != null && prev.isLoading && !next.isLoading) {
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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 28.w), // Scaled
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 60.r, // Scaled
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 58.r, // Scaled
                      backgroundColor: Colors.black,
                      backgroundImage: AssetImage("assets/avatars/$formattedAvatarId.png"),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h), // Scaled
            GestureDetector(
              onTap: () {
                AvatarPickerSheet.show(context, userRole, (id) {
                  setState(() => currentAvatarId = id);
                });
              },
              child: Text("Change Picture", style: TextStyle(color: const Color(0xFF1877F2), fontSize: 16.sp)), // Premium Blue & Scaled
            ),
            SizedBox(height: 30.h), // Scaled

            _buildField("Full Name", nameController),
            _buildField("Semester", semesterController, isNumber: true),
            _buildField("Section", sectionController),

            Divider(color: Colors.white24, thickness: 1, height: 40.h), // Scaled

            _buildField(
                "Current Password (Required if changing password)",
                currentPasswordController,
                isPassword: true,
                obscureText: _obscureCurrent,
                onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent)
            ),
            _buildField(
                "New Password",
                passwordController,
                isPassword: true,
                obscureText: _obscureNew,
                onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew)
            ),
            _buildField(
                "Confirm New Password",
                confirmPasswordController,
                isPassword: true,
                obscureText: _obscureConfirm,
                onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm)
            ),

            SizedBox(height: 40.h), // Scaled

            SizedBox(
              width: double.infinity,
              height: 56.h, // Scaled matching login/signup height
              child: ElevatedButton(
                onPressed: profileState.isLoading ? null : handleUpdate,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2), // Premium Blue
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)) // Scaled
                ),
                child: profileState.isLoading
                    ? SizedBox(height: 20.h, width: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) // Scaled
                    : Text("Update", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w600)), // Premium font styling
              ),
            ),
            SizedBox(height: 40.h), // Scaled
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool isNumber = false, bool isPassword = false, bool obscureText = false, VoidCallback? onToggleVisibility}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h), // Scaled
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500)), // Scaled
          SizedBox(height: 8.h), // Scaled
          TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: TextStyle(color: Colors.white, fontSize: 16.sp), // Scaled
            decoration: InputDecoration(
              filled: false,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r), // Scaled
                borderSide: const BorderSide(color: Colors.white30),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r), // Scaled
                borderSide: const BorderSide(color: Color(0xFF1877F2)), // Premium Blue
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h), // Scaled
              suffixIcon: isPassword ? IconButton(
                icon: Icon(obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white54, size: 24.sp), // Outlined & Scaled
                onPressed: onToggleVisibility,
              ) : null,
            ),
          ),
        ],
      ),
    );
  }
}