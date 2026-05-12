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
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
        child: Column(
          children: [
            _buildContactRow(
              imagePath: "assets/avatars/24.png",
              name: "Shimanta Dey",
              id: "230241110",
              role: "Full Stack Developer",
              email: "shimantadey77@gmail.com",
              phone: "+8801848-497083",
            ),
            Divider(color: Colors.white30, thickness: 1, height: 40.h),
            _buildContactRow(
              imagePath: "assets/avatars/23.png",
              name: "Shatattya Barua",
              id: "230241123",
              role: "Flutter & Backend Developer",
              email: "shatattya@proton.me",
              phone: "+8801740-698959",
            ),
            Divider(color: Colors.white30, thickness: 1, height: 40.h),
            _buildContactRow(
              imagePath: "assets/avatars/25.png",
              name: "Kamrul Islam Rony",
              id: "230241119",
              role: "Front End & Database Developer",
              email: "kamrulislam2089@gmail.com",
              phone: "+8801964-815852",
            ),
            Divider(color: Colors.white30, thickness: 1, height: 40.h),
          ],
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
          radius: 40.r,
          backgroundColor: Colors.white12,
          backgroundImage: AssetImage(imagePath),
        ),
        SizedBox(width: 20.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500)),
              SizedBox(height: 2.h),
              Text(id, style: TextStyle(color: Colors.white, fontSize: 14.sp)),
              SizedBox(height: 2.h),
              Text(role, style: TextStyle(color: Colors.white, fontSize: 13.sp)),
              SizedBox(height: 2.h),
              Text(email, style: TextStyle(color: Colors.white, fontSize: 13.sp)),
              SizedBox(height: 2.h),
              Text(phone, style: TextStyle(color: Colors.white, fontSize: 13.sp)),
            ],
          ),
        ),
      ],
    );
  }
}