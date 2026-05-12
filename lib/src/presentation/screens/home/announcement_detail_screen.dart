import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil

class AnnouncementDetailScreen extends StatelessWidget {
  final dynamic notice;

  const AnnouncementDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text("Announcement", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 20.sp)), // Scaled
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w), // Scaled
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// TITLE
            Text(
              notice.title,
              style: TextStyle(color: Colors.white, fontSize: 26.sp, fontWeight: FontWeight.bold, height: 1.3), // Scaled
            ),

            SizedBox(height: 24.h), // Scaled

            /// AUTHOR & DATE ROW
            Row(
              children: [
                CircleAvatar(
                  radius: 20.r, // Scaled
                  backgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.2), // Premium subtle blue
                  child: Icon(Icons.person_outline, color: const Color(0xFF1877F2), size: 24.sp), // Premium outlined icon & scaled
                ),
                SizedBox(width: 16.w), // Scaled
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notice.authorName, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500)), // Scaled
                    SizedBox(height: 4.h), // Scaled
                    Text(
                      DateFormat('dd MMMM yyyy • hh:mm a').format(notice.createdAt),
                      style: TextStyle(color: Colors.white54, fontSize: 13.sp), // Scaled
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 32.h), // Scaled
            const Divider(color: Colors.white12, thickness: 1),
            SizedBox(height: 24.h), // Scaled

            /// BODY TEXT
            Text(
              notice.body,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 17.sp, // Scaled and refined for readability
                height: 1.6,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}