import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';

class UpdateNoticeSheet extends StatelessWidget {
  final AppUpdateInfo updateInfo;

  const UpdateNoticeSheet({super.key, required this.updateInfo});

  static void show(BuildContext context, AppUpdateInfo info) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UpdateNoticeSheet(updateInfo: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.only(left: 24.w, right: 24.w, top: 12.h, bottom: 34.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // iOS style pill
          Container(
            width: 40.w,
            height: 5.h,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4.r)),
          ),
          SizedBox(height: 24.h),

          Icon(Icons.system_update, color: const Color(0xFF1877F2), size: 50.sp),
          SizedBox(height: 16.h),

          Text(
            "Update Required",
            style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(
            "Version ${updateInfo.latestVersion} is now available.",
            style: TextStyle(color: Colors.white54, fontSize: 15.sp),
          ),

          Container(
            margin: EdgeInsets.symmetric(vertical: 24.h),
            padding: EdgeInsets.all(16.w),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Release Notes", style: TextStyle(color: const Color(0xFF1877F2), fontWeight: FontWeight.w600, fontSize: 13.sp)),
                SizedBox(height: 8.h),
                Text(
                  updateInfo.releaseNotes,
                  style: TextStyle(color: Colors.white70, fontSize: 14.sp, height: 1.4),
                ),
              ],
            ),
          ),

          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: () {
                launchUrl(Uri.parse(updateInfo.downloadUrl), mode: LaunchMode.externalApplication);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              ),
              child: Text("Download Update", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: 12.h),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Not Now", style: TextStyle(color: Colors.white54, fontSize: 16.sp)),
          ),
        ],
      ),
    );
  }
}