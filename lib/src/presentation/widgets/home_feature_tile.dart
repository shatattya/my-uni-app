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
            // Use .r for a perfect, compact square that matches the mockup
            height: 56.r,
            width: 56.r,
            decoration: BoxDecoration(
              color: const Color(0xFF1877F2), // Premium Blue
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: Colors.white, size: 28.r), // Elegant icon sizing
          ),

          SizedBox(height: 8.h),

          Expanded( // Expanded forces the text into its own safe zone, preventing overlap
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp, // Crisp, premium font size
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