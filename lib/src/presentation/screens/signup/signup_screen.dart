import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../routes/app_router.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  String? internalIdError;
  String? nameError;
  String? passwordError;
  String? confirmPasswordError;
  String? semesterError;
  String? sectionError;
  bool _passwordHidden = true;
  bool _confirmPasswordHidden = true;
  bool isLoading = false;
  bool _isPolicyAccepted = false;
  final nameController = TextEditingController();
  final idController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final semesterController = TextEditingController();
  final sectionController = TextEditingController();

  void validateName(String value) {
    if (value.isEmpty) { setState(() => nameError = null); return; }
    final regex = RegExp(r'^[a-zA-Z ]+$');
    if (!regex.hasMatch(value)) {
      setState(() => nameError = "Name can only contain letters and spaces");
      return;
    }
    setState(() => nameError = null);
  }

  void validateInternalId(String value) {
    if (value.isEmpty) { setState(() => internalIdError = null); return; }
    if (value.length != 9 || int.tryParse(value) == null) {
      setState(() => internalIdError = "Internal ID must be exactly 9 digits");
      return;
    }
    if (value.substring(2, 4) != "02") {
      setState(() => internalIdError = "Department code must be 02");
      return;
    }
    int batch = int.parse(value.substring(4, 6));
    if (batch < 37 || batch > 60) {
      setState(() => internalIdError = "Batch must be between 37 and 48");
      return;
    }
    setState(() => internalIdError = null);
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

  void validateSemester(String value) {
    if (value.isEmpty) { setState(() => semesterError = null); return; }
    int? semester = int.tryParse(value);
    if (semester == null || semester < 1 || semester > 8) {
      setState(() => semesterError = "Semester must be between 1 and 8");
      return;
    }
    setState(() => semesterError = null);
  }

  void validateSection(String value) {
    if (value.isEmpty) { setState(() => sectionError = null); return; }
    if (value != "A" && value != "B" && value != "C") {
      setState(() => sectionError = "Section must be A, B, or C");
    } else {
      setState(() => sectionError = null);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    idController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    semesterController.dispose();
    sectionController.dispose();
    super.dispose();
  }

  void _showResultDialog({required String title, required String message, required bool isSuccess}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: isSuccess ? Colors.green : Colors.redAccent,
              size: 28.sp,
            ),
            SizedBox(width: 10.w),
            Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
          ],
        ),
        content: Text(message, style: TextStyle(color: Colors.white70, fontSize: 15.sp, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isSuccess) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
            child: Text("OK", style: TextStyle(color: const Color(0xFF1877F2), fontSize: 16.sp, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void handleSignup() async {
    if (!isFormValid()) {
      HapticFeedback.heavyImpact();
      _showResultDialog(
        title: "Invalid Form",
        message: "Please fix the errors in the form before signing up.",
        isSuccess: false,
      );
      return;
    }
    if (!_isPolicyAccepted) {
      HapticFeedback.heavyImpact();
      _showResultDialog(
        title: "Policy Required",
        message: "You must accept the Privacy Policy to create an account.",
        isSuccess: false,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUp(
        internalId: idController.text,
        password: passwordController.text,
        name: nameController.text,
        semester: int.parse(semesterController.text),
        section: sectionController.text,
      );

      if (!mounted) return;
      setState(() => isLoading = false);
      HapticFeedback.mediumImpact();
      _showResultDialog(
        title: "Success",
        message: "Account created successfully. Please log in to continue.",
        isSuccess: true,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      String message = "Signup failed. Please try again.";
      if (e.code == 'email-already-in-use') message = "An account with this Internal ID already exists.";

      HapticFeedback.heavyImpact();
      _showResultDialog(
        title: "Signup Failed",
        message: message,
        isSuccess: false,
      );
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        HapticFeedback.heavyImpact();
        _showResultDialog(
          title: "Error",
          message: "An unexpected error occurred: ${e.toString().split(']').last}",
          isSuccess: false,
        );
      }
    }
  }

  bool isFormValid() {
    if (nameController.text.isEmpty || idController.text.isEmpty || passwordController.text.isEmpty || confirmPasswordController.text.isEmpty || semesterController.text.isEmpty || sectionController.text.isEmpty) return false;
    if (nameError != null || internalIdError != null || passwordError != null || confirmPasswordError != null || semesterError != null || sectionError != null) return false;
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
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white, fontSize: 16.sp)),
        SizedBox(height: 12.h),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          style: TextStyle(color: Colors.black, fontSize: 16.sp),
          decoration: InputDecoration(
            counterText: "",
            hintText: hint,
            hintStyle: TextStyle(color: Colors.black54, fontSize: 16.sp),
            filled: true,
            fillColor: const Color(0xFFE0E0E0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            errorText: errorText,
            suffixIcon: showVisibilityToggle
                ? IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
                size: 24.sp,
              ),
              onPressed: onToggleVisibility,
            )
                : null,
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20.h),
                _buildTextField(
                  label: "Full Name",
                  hint: "Enter Your Full Name",
                  controller: nameController,
                  onChanged: validateName,
                  errorText: nameError,
                  maxLength: 35,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                  ],
                ),
                _buildTextField(
                  label: "Internal ID",
                  hint: "Enter Your Internal ID",
                  controller: idController,
                  keyboardType: TextInputType.number,
                  onChanged: validateInternalId,
                  errorText: internalIdError,
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
                _buildTextField(
                  label: "Semester",
                  hint: "Enter Your Semester",
                  controller: semesterController,
                  keyboardType: TextInputType.number,
                  onChanged: validateSemester,
                  errorText: semesterError,
                ),
                _buildTextField(
                  label: "Section",
                  hint: "Enter Your Section",
                  controller: sectionController,
                  onChanged: validateSection,
                  errorText: sectionError,
                  maxLength: 1,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-cA-C]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                      );
                    }),
                  ],
                ),
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
                          Navigator.pushNamed(context, AppRoutes.privacyPolicy);
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
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      disabledBackgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.5),
                    ),
                    child: isLoading
                        ? SizedBox(
                      height: 20.h,
                      width: 20.h,
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : Text(
                      "Sign Up",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}