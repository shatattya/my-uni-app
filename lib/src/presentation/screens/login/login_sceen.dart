import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added
import '../../../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _obscurePassword = true;

  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void handleLogin() async {
    final idOrEmail = idController.text.trim();
    final password = passwordController.text.trim();

    if (idOrEmail.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your credentials")),
      );
      return;
    }

    try {
      final authService = ref.read(authServiceProvider);
      await authService.login(idOrEmail: idOrEmail, password: password);
      if (!mounted) return;

      Navigator.pushReplacementNamed(context, "/home");

    } on FirebaseAuthException catch (e) {
      String message = "Login failed";

      if (e.code == 'user-not-found') message = "No account found";
      if (e.code == 'wrong-password') message = "Incorrect password";
      if (e.code == 'invalid-teacher-email') message = "Teachers must use @bgctub.ac.bd email";

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    idController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28.w), // Scaled
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 30.h), // Scaled

              /// Illustration
              Center(
                child: Image.asset(
                  "assets/images/login_illustration.png",
                  height: 260.h, // Scaled
                ),
              ),

              SizedBox(height: 40.h), // Scaled

              /// ID Label
              Text(
                "Internal ID or University Mail (For Teachers Only)",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp, // Scaled and refined slightly for elegance
                ),
              ),

              SizedBox(height: 12.h), // Scaled

              /// ID Field
              TextField(
                controller: idController,
                style: TextStyle(color: Colors.black, fontSize: 16.sp), // Scaled
                decoration: InputDecoration(
                  hintText: "ex : 230241123",
                  hintStyle: TextStyle(color: Colors.black54, fontSize: 16.sp), // Scaled
                  filled: true,
                  fillColor: const Color(0xFFE0E0E0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r), // Scaled
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h), // Scaled
                ),
              ),

              SizedBox(height: 30.h), // Scaled

              /// Password Label
              Text(
                "Password",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp, // Scaled
                ),
              ),

              SizedBox(height: 12.h), // Scaled

              /// Password Field
              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: Colors.black, fontSize: 16.sp), // Scaled
                decoration: InputDecoration(
                  hintText: "********",
                  hintStyle: TextStyle(color: Colors.black54, fontSize: 16.sp), // Scaled
                  filled: true,
                  fillColor: const Color(0xFFE0E0E0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r), // Scaled
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h), // Scaled
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                      size: 24.sp, // Scaled
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              SizedBox(height: 60.h), // Scaled

              /// Login Button
              SizedBox(
                width: double.infinity,
                height: 56.h, // Scaled
                child: ElevatedButton(
                  onPressed: handleLogin,
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
                        color: Colors.white // Better contrast for premium blue
                    ),
                  ),
                ),
              ),

              SizedBox(height: 30.h), // Scaled
            ],
          ),
        ),
      ),
    );
  }
}