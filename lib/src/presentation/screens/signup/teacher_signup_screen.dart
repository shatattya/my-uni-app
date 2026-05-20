import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ADDED: For Haptic Feedback
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil
import '../../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'privacy_policy_screen.dart'; // ADDED: Import the new Privacy Policy screen

class TeacherSignupScreen extends ConsumerStatefulWidget {
  const TeacherSignupScreen({super.key});

  @override
  ConsumerState<TeacherSignupScreen> createState() => _TeacherSignupScreenState();
}

class _TeacherSignupScreenState extends ConsumerState<TeacherSignupScreen> {
  String? emailError;
  String? nameError;
  String? passwordError;
  String? confirmPasswordError;
  bool _passwordHidden = true;
  bool _confirmPasswordHidden = true;
  bool isLoading = false;

  // MODIFICATION: Added Privacy Policy State
  bool _isPolicyAccepted = false;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  void validateName(String value) {
    if (value.isEmpty) { setState(() => nameError = null); return; }
    final regex = RegExp(r'^[a-zA-Z. ]+$');
    if (!regex.hasMatch(value)) {
      setState(() => nameError = "Name can only contain letters, spaces, and periods");
      return;
    }
    setState(() => nameError = null);
  }

  void validateEmail(String value) {
    if (value.isEmpty) { setState(() => emailError = null); return; }
    if (!value.endsWith("@bgctub.ac.bd")) {
      setState(() => emailError = "Must be a valid @bgctub.ac.bd email address");
      return;
    }
    setState(() => emailError = null);
  }

  void validatePassword(String value) {
    if (value.isEmpty) { setState(() => passwordError = null); return; }
    final regex = RegExp(r'^(?=.*[0-9]).{8,}$');
    if (!regex.hasMatch(value)) {
      setState(() => passwordError = "Password must be at least 8 characters and contain a number");
      return;
    }
    setState(() => passwordError = null);
  }

  void validateConfirmPassword(String value) {
    if (value.isEmpty) { setState(() => confirmPasswordError = null); return; }
    if (value != passwordController.text) {
      setState(() => confirmPasswordError = "Passwords do not match");
      return;
    }
    setState(() => confirmPasswordError = null);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void handleSignup() async {
    // MODIFICATION: Enforce Form Validity and Policy Acceptance with Haptic Feedback
    if (!isFormValid()) {
      HapticFeedback.heavyImpact(); // iOS UX warning
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fix the errors before signing up"), backgroundColor: Colors.redAccent));
      return;
    }

    if (!_isPolicyAccepted) {
      HapticFeedback.heavyImpact(); // iOS UX warning
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You must accept the Privacy Policy to create an account."), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUpTeacher(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        name: nameController.text.trim(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact(); // iOS UX success
      Navigator.pop(context, "Account created successfully. Please log in.");

    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      String message = "Signup failed";
      if (e.code == 'email-already-in-use') message = "An account with this Email already exists";
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving profile: ${e.toString().split(']').last}"), backgroundColor: Colors.redAccent));
      }
    }
  }

  bool isFormValid() {
    if (nameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.isEmpty || confirmPasswordController.text.isEmpty) return false;
    if (nameError != null || emailError != null || passwordError != null || confirmPasswordError != null) return false;
    return true;
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    bool obscureText = false,
    bool showVisibilityToggle = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white, fontSize: 16.sp)), // Scaled
        SizedBox(height: 12.h), // Scaled
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: TextStyle(color: Colors.black, fontSize: 16.sp), // Scaled
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.black54, fontSize: 16.sp), // Scaled
            filled: true,
            fillColor: const Color(0xFFE0E0E0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r), // Scaled
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h), // Scaled
            errorText: errorText,
            suffixIcon: showVisibilityToggle
                ? IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
                size: 24.sp, // Scaled
              ),
              onPressed: onToggleVisibility,
            )
                : null,
          ),
        ),
        SizedBox(height: 20.h), // Scaled
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // MODIFICATION: Wrap Scaffold in GestureDetector for iOS Keyboard dismiss
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text("Teacher Sign Up", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w600)), // Scaled
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 28.w), // Scaled
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20.h), // Scaled

                _buildTextField(
                  label: "Full Name",
                  hint: "Enter Your Full Name",
                  controller: nameController,
                  onChanged: validateName,
                  errorText: nameError,
                ),

                _buildTextField(
                  label: "University E-mail",
                  hint: "teacher@bgctub.ac.bd",
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: validateEmail,
                  errorText: emailError,
                ),

                _buildTextField(
                  label: "Password",
                  hint: "********",
                  controller: passwordController,
                  onChanged: validatePassword,
                  errorText: passwordError,
                  obscureText: _passwordHidden,
                  showVisibilityToggle: true,
                  onToggleVisibility: () => setState(() => _passwordHidden = !_passwordHidden),
                ),

                _buildTextField(
                  label: "Confirm Password",
                  hint: "********",
                  controller: confirmPasswordController,
                  onChanged: validateConfirmPassword,
                  errorText: confirmPasswordError,
                  obscureText: _confirmPasswordHidden,
                  showVisibilityToggle: true,
                  onToggleVisibility: () => setState(() => _confirmPasswordHidden = !_confirmPasswordHidden),
                ),

                // MODIFICATION: Privacy Policy Checkbox Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 24.h,
                      width: 24.w,
                      child: Checkbox(
                        value: _isPolicyAccepted,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _isPolicyAccepted = value ?? false);
                        },
                        activeColor: const Color(0xFF1877F2),
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.white54, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                        },
                        child: Text.rich(
                          TextSpan(
                            text: "I agree to the ",
                            style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                            children: [
                              TextSpan(
                                text: "Privacy Policy",
                                style: TextStyle(
                                  color: const Color(0xFF1877F2),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h), // Scaled

                SizedBox(
                  width: double.infinity,
                  height: 56.h, // Scaled
                  child: ElevatedButton(
                    onPressed: isLoading ? null : handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2), // Premium Blue
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r), // Scaled
                      ),
                      // Visual feedback if disabled (opacity trick)
                      disabledBackgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.5),
                    ),
                    child: isLoading
                        ? SizedBox(
                      height: 20.h, // Scaled
                      width: 20.h, // Scaled
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : Text(
                      "Sign Up",
                      style: TextStyle(
                        fontSize: 18.sp, // Scaled
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 40.h), // Scaled
              ],
            ),
          ),
        ),
      ),
    );
  }
}