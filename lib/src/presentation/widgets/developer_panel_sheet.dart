import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'routine_upload_sheet.dart';

class DeveloperPanelSheet extends StatelessWidget {
  const DeveloperPanelSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const DeveloperPanelSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.only(
        left: 24.w,
        right: 24.w,
        top: 24.h,
        bottom: 34.h, // Safe bottom padding
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, color: Colors.amber, size: 28.sp),
                  SizedBox(width: 12.w),
                  Text(
                    "Developer Panel",
                    style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white54, size: 24.sp),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            "Authorized access only. Use these tools carefully as they directly impact the production database.",
            style: TextStyle(color: Colors.white54, fontSize: 13.sp, height: 1.4),
          ),
          SizedBox(height: 24.h),

          // --- MENU OPTIONS ---

          _buildMenuOption(
            icon: Icons.cloud_upload_outlined,
            title: "Update Routine Database",
            subtitle: "Upload and deploy the master routine.json",
            color: const Color(0xFF1877F2), // Premium Blue
            onTap: () {
              Navigator.pop(context); // Close the menu first
              RoutineUploadSheet.show(context); // Open the existing routine sheet
            },
          ),

          SizedBox(height: 16.h),

          _buildMenuOption(
            icon: Icons.analytics_outlined,
            title: "System Insights",
            subtitle: "View database reads, active users, and logs",
            color: Colors.teal,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("System Insights module coming soon.")),
              );
            },
          ),

          SizedBox(height: 16.h),

          _buildMenuOption(
            icon: Icons.people_outline,
            title: "Manage Users",
            subtitle: "Edit permissions, assign CRs, or suspend accounts",
            color: Colors.deepPurpleAccent,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("User Management module coming soon.")),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white12, width: 1.w),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: color, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4.h),
                    Text(subtitle, style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white38, size: 24.sp),
            ],
          ),
        ),
      ),
    );
  }
}