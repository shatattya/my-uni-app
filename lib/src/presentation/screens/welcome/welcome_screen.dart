import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil
import '../login/login_sceen.dart';
import '../signup/signup_screen.dart';
import '../signup/teacher_signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28.w), // Scaled
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 60.h), // Scaled

              /// Illustration
              Image.asset(
                "assets/images/welcome_image.png",
                height: 260.h, // Scaled
              ),

              SizedBox(height: 40.h), // Scaled

              /// App Title
              Text(
                "My Uni App",
                style: TextStyle(
                  fontSize: 32.sp, // Scaled
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),

              SizedBox(height: 12.h), // Scaled

              /// Subtitle
              Text(
                "Your all-in-one campus companion.\nStay updated with routines, notices, and events.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp, // Scaled
                  color: Colors.white54,
                  height: 1.4,
                ),
              ),

              SizedBox(height: 50.h), // Scaled

              /// Login Button
              SizedBox(
                width: double.infinity,
                height: 56.h, // Scaled
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2), // Premium Blue
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r), // Scaled
                    ),
                  ),
                  child: Text(
                    "Log in",
                    style: TextStyle(
                      fontSize: 18.sp, // Scaled
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16.h), // Scaled

              /// Sign Up Button (Student)
              SizedBox(
                width: double.infinity,
                height: 56.h, // Scaled
                child: OutlinedButton(
                  // MODIFICATION: Await the result and show a SnackBar if successful
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );

                    if (result != null && result is String && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result, style: const TextStyle(color: Colors.white)),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFF1877F2), width: 1.5.w), // Premium Blue & Scaled
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r), // Scaled
                    ),
                  ),
                  child: Text(
                    "Sign Up as Student",
                    style: TextStyle(
                      fontSize: 16.sp, // Scaled
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1877F2), // Premium Blue
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16.h), // Scaled

              /// Sign Up Button (Teacher)
              SizedBox(
                width: double.infinity,
                height: 56.h, // Scaled
                child: OutlinedButton(
                  // MODIFICATION: Await the result and show a SnackBar if successful
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeacherSignupScreen()),
                    );

                    if (result != null && result is String && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result, style: const TextStyle(color: Colors.white)),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white24, width: 1.5.w), // Scaled
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r), // Scaled
                    ),
                  ),
                  child: Text(
                    "Sign Up as Teacher",
                    style: TextStyle(
                      fontSize: 16.sp, // Scaled
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 40.h), // Scaled
            ],
          ),
        ),
      ),
    );
  }
}