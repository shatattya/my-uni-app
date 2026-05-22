import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ADDED: For Haptic Feedback and InputFormatters
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added
import '../../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'privacy_policy_screen.dart'; // ADDED: Import the new Privacy Policy screen

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

  // MODIFICATION: Added Privacy Policy State
  bool _isPolicyAccepted = false;

  final nameController = TextEditingController();
  final idController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final semesterController = TextEditingController();
  final sectionController = TextEditingController();

  void validateName(String value) {
    if (value.isEmpty) { setState(() => nameError = null); return; }
    // UX ENHANCEMENT: Restrict strictly to letters and spaces matching the input formatter
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
    // UX FIX: Removed manual text replacement here as input formatter now handles capitalization safely
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
      await authService.signUp(
        internalId: idController.text,
        password: passwordController.text,
        name: nameController.text,
        semester: int.parse(semesterController.text),
        section: sectionController.text,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact(); // iOS UX success
      Navigator.pop(context, "Account created successfully. Please log in.");

    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      String message = "Signup failed";
      if (e.code == 'email-already-in-use') message = "An account with this Internal ID already exists";
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
    if (nameController.text.isEmpty || idController.text.isEmpty || passwordController.text.isEmpty || confirmPasswordController.text.isEmpty || semesterController.text.isEmpty || sectionController.text.isEmpty) return false;
    if (nameError != null || internalIdError != null || passwordError != null || confirmPasswordError != null || semesterError != null || sectionError != null) return false;
    return true;
  }

  // Refactored helper for clean, perfectly scaled inputs
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
    List<TextInputFormatter>? inputFormatters, // ADDED: For input restrictions
    int? maxLength, // ADDED: For length restrictions
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
            counterText: "", // UX ENHANCEMENT: Hide the character counter for a cleaner look
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
    // MODIFICATION: Wrap Scaffold in GestureDetector for iOS Keyboard dismiss
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 28.w), // Scaled
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20.h),

                // UX ENHANCEMENT: Restrict name input
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

                // UX ENHANCEMENT: Restrict section input and auto-capitalize
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
                SizedBox(height: 24.h),

                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2), // Premium Blue
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      // Visual feedback if disabled (opacity trick)
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
                        color: Colors.white, // High contrast
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