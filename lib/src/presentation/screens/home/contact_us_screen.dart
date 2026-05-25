import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // MODIFICATION: Wrapped in Center to align content in the middle vertically
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h), // MODIFICATION: Bumped padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // MODIFICATION: Centers items perfectly
            children: [
              _buildContactRow(
                imagePath: "assets/avatars/24.png",
                name: "Shimanta Dey",
                id: "230241110",
                role: "Full Stack Developer",
                email: "shimantadey77@gmail.com",
                phone: "+8801848-497083",
              ),
              Divider(color: Colors.white30, thickness: 1, height: 48.h), // MODIFICATION: Bumped
              _buildContactRow(
                imagePath: "assets/avatars/23.png",
                name: "Shatattya Barua",
                id: "230241123",
                role: "Flutter & Backend Developer",
                email: "shatattya@proton.me",
                phone: "+8801740-698959",
              ),
              Divider(color: Colors.white30, thickness: 1, height: 48.h), // MODIFICATION: Bumped
              _buildContactRow(
                imagePath: "assets/avatars/25.png",
                name: "Kamrul Islam Rony",
                id: "230241119",
                role: "Front End & Database Developer",
                email: "kamrulislam2089@gmail.com",
                phone: "+8801964-815852",
              ),
              Divider(color: Colors.white30, thickness: 1, height: 48.h), // MODIFICATION: Bumped
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow({
    required String imagePath,
    required String name,
    required String id,
    required String role,
    required String email,
    required String phone,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 48.r, // MODIFICATION: Bumped avatar size to remain prominent
          backgroundColor: Colors.white12,
          backgroundImage: AssetImage(imagePath),
        ),
        SizedBox(width: 24.w), // MODIFICATION: Bumped horizontal spacing
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w500)), // MODIFICATION: Bumped
              SizedBox(height: 2.h),
              Text(id, style: TextStyle(color: Colors.white, fontSize: 16.sp)), // MODIFICATION: Bumped
              SizedBox(height: 2.h),
              Text(role, style: TextStyle(color: Colors.white, fontSize: 15.sp)), // MODIFICATION: Bumped
              SizedBox(height: 2.h),
              Text(email, style: TextStyle(color: Colors.white, fontSize: 15.sp)), // MODIFICATION: Bumped
              SizedBox(height: 2.h),
              Text(phone, style: TextStyle(color: Colors.white, fontSize: 15.sp)), // MODIFICATION: Bumped
            ],
          ),
        ),
      ],
    );
  }
}