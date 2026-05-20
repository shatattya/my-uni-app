import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          "Privacy Policy",
          style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), // Native iOS scroll feel
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PRIVACY POLICY",
              style: TextStyle(color: Colors.white, fontSize: 26.sp, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            SizedBox(height: 8.h),
            Text(
              "Last Updated: May 2026",
              style: TextStyle(color: Colors.white54, fontSize: 14.sp, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 24.h),
            Text(
              "This Privacy Policy describes how our campus companion application (\"the Application\") collects, uses, shares, and protects your information. This policy applies equally to all registered users, including students and academic faculty/teachers (\"Users\").\n\nBy creating an account or using the Application, you explicitly agree to the collection and use of information in accordance with this policy.",
              style: TextStyle(color: Colors.white70, fontSize: 15.sp, height: 1.5),
            ),

            _buildSectionHeader("1. Information Collection and Use"),
            Text(
              "To provide a synchronized, role-based campus experience, the Application processes specific identifiers depending on your account classification:",
              style: TextStyle(color: Colors.white70, fontSize: 15.sp, height: 1.5),
            ),
            SizedBox(height: 12.h),
            _buildSubHeader("A. Student Accounts"),
            _buildBulletPoint("Institutional Identifiers", "We collect your campus-issued institutional email address and your unique Internal ID."),
            _buildBulletPoint("Academic Routing Data", "We store and process your current Semester (Integers 1–8) and Section (A, B, or C) to automatically map your localized academic timetable, notice boards, and attendance metrics."),
            _buildBulletPoint("Profile Customization", "We store your preferred display name and selected localized asset avatar ID."),

            SizedBox(height: 16.h),
            _buildSubHeader("B. Teacher / Faculty Accounts"),
            _buildBulletPoint("Professional Identifiers", "We collect your verified institutional email address (e.g., matching @bgctub.ac.bd) and professional display name."),
            _buildBulletPoint("Privileged Administrative Data", "We log internal verification records confirming your administrative role to grant secure access to system utilities (e.g., creating class announcements, managing attendance logs, or viewing analytics panels)."),

            _buildSectionHeader("2. Data Storage Architecture: Offline-First Philosophy"),
            Text(
              "The Application operates on a local-first data lifecycle management strategy:",
              style: TextStyle(color: Colors.white70, fontSize: 15.sp, height: 1.5),
            ),
            SizedBox(height: 12.h),
            _buildBulletPoint("On-Device Storage", "Your academic data, profile configuration, and local logs are securely written to an encrypted on-device SQLite database utilizing the Drift persistence engine. This data remains on your physical device and is accessible without an active internet connection."),
            _buildBulletPoint("Cloud Synchronization", "When a network connection is available, essential role verification tokens and structural documents securely synchronize with our Firebase Cloud Firestore backend to protect identity integrity and distribute active announcements across matching academic routes."),

            _buildSectionHeader("3. Future Monetization & Advertising Disclosures"),
            Text(
              "To sustain free operations without subscription fees, upcoming versions of the Application will integrate programmatic advertising frameworks (including, but not limited to, Google AdMob).",
              style: TextStyle(color: Colors.white70, fontSize: 15.sp, height: 1.5),
            ),
            SizedBox(height: 12.h),
            _buildBulletPoint("Third-Party Advertising Identifiers", "Future iterations will utilize standardized mobile advertising SDKs to serve contextual or personalized banner, interstitial, and rewarded ads. These third-party networks may collect your device's Advertising ID (e.g., Google AAID or Apple IDFA), device model, mobile carrier, and basic telemetry data."),
            _buildBulletPoint("Privacy Controls", "You retain the right to reset or restrict tracking via your native mobile operating system settings (e.g., via \"Limit Ad Tracking\" on iOS or \"Opt-out of Ads Personalization\" on Android)."),

            _buildSectionHeader("4. Push Notification Telemetry"),
            Text(
              "The Application utilizes Firebase Cloud Messaging (FCM) to instantly dispatch critical academic routing updates and class notices.",
              style: TextStyle(color: Colors.white70, fontSize: 15.sp, height: 1.5),
            ),
            SizedBox(height: 12.h),
            _buildBulletPoint("Topic Routing", "Your device automatically subscribes to generalized structural topics (e.g., matching your specific cohort route string layout)."),
            _buildBulletPoint("Data Protection", "No personally identifiable historical telemetry is leaked through these messaging loops; topic distribution keys are used solely for localized message delivery."),

            _buildSectionHeader("5. Your Rights and Data Deletion"),
            Text(
              "You maintain full control over your structural data footprints:",
              style: TextStyle(color: Colors.white70, fontSize: 15.sp, height: 1.5),
            ),
            SizedBox(height: 12.h),
            _buildBulletPoint("Data Rectification", "You can modify your profile data (subject to localized anti-abuse verification cooldown intervals) directly through the account settings panel."),
            _buildBulletPoint("Account Deletion", "You may initiate an account deletion request at any time. Executing a deletion completely clears your profile document from our remote cloud backends and erases your active local database storage tables."),

            _buildSectionHeader("6. Changes to This Privacy Policy"),
            Text(
              "We may update our Privacy Policy from time to time. We will notify you of any changes by updating the \"Last Updated\" timestamp at the top of this document and displaying an interrupt modal or system notice within the Application prior to the changes taking effect.",
              style: TextStyle(color: Colors.white70, fontSize: 15.sp, height: 1.5),
            ),

            SizedBox(height: 60.h), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 32.h, bottom: 12.h),
      child: Text(
        title,
        style: TextStyle(color: const Color(0xFF1877F2), fontSize: 18.sp, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSubHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        title,
        style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBulletPoint(String boldTerm, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 8.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("• ", style: TextStyle(color: const Color(0xFF1877F2), fontSize: 16.sp, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: "$boldTerm: ", style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold)),
                  TextSpan(text: description, style: TextStyle(color: Colors.white70, fontSize: 15.sp, height: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}