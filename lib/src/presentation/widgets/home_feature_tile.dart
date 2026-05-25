import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeFeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const HomeFeatureTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            // MODIFICATION: Bumped size to maintain a comfortable tap target under the new global scale
            height: 64.r,
            width: 64.r,
            decoration: BoxDecoration(
              color: const Color(0xFF1877F2), // Premium Blue
              borderRadius: BorderRadius.circular(16.r),
            ),
            // MODIFICATION: Scaled icon up slightly
            child: Icon(icon, color: Colors.white, size: 32.r),
          ),

          // MODIFICATION: Increased gap slightly
          SizedBox(height: 10.h),

          Expanded( // Expanded forces the text into its own safe zone, preventing overlap
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: Colors.white,
                // MODIFICATION: Bumped font size up to preserve legibility
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                height: 1.2, // Tighter line height looks cleaner
              ),
            ),
          ),
        ],
      ),
    );
  }
}