import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil

class AvatarPickerSheet {
  static void show(BuildContext context, String role, Function(int) onAvatarSelected) {
    int start = 1;
    int end = 9;

    if (role == 'teacher') {
      start = 10;
      end = 19;
    } else if (role == 'developer') {
      start = 20;
      end = 29;
    }

    final avatars = List.generate(end - start + 1, (index) => start + index);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true, // Allows us to use a custom height safely
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)), // Scaled
      ),
      builder: (context) {
        // BUG FIX: Wrapped in a constrained height container so GridView doesn't overflow
        return Container(
          height: 400.h, // Scaled safe constraint
          padding: EdgeInsets.all(20.w), // Scaled
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Select Avatar", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)), // Scaled
              SizedBox(height: 20.h), // Scaled
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16.w, // Scaled
                    mainAxisSpacing: 16.h, // Scaled
                  ),
                  itemCount: avatars.length,
                  itemBuilder: (context, index) {
                    final avatarId = avatars[index];
                    final String formattedId = avatarId.toString().padLeft(2, '0');
                    return GestureDetector(
                      onTap: () {
                        onAvatarSelected(avatarId);
                        Navigator.pop(context);
                      },
                      child: CircleAvatar(
                        backgroundImage: AssetImage("assets/avatars/$formattedId.png"),
                        backgroundColor: Colors.transparent,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}