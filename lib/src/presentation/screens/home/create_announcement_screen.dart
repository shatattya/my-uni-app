import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil

import '../../../data/repositories/announcement_repository.dart';
import '../../../data/repositories/user_repository.dart';

class CreateAnnouncementScreen extends ConsumerStatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  ConsumerState<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends ConsumerState<CreateAnnouncementScreen> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();

  bool isGlobal = true;
  bool isLoading = false;

  // RESTORED: Functional Target Group Logic variables
  String currentSem = "1";
  String currentSec = "A";
  List<Map<String, String>> addedTargets = [];

  void handleCreate() async {
    final title = titleController.text.trim();
    final body = bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and body cannot be empty", style: TextStyle(color: Colors.white))),
      );
      return;
    }

    if (!isGlobal && addedTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one target group using the + button")),
      );
      return;
    }

    setState(() { isLoading = true; });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final user = await ref.read(userRepositoryProvider).watchUser(uid).first;
      if (user == null) throw Exception("User profile not found");

      // Extract unique lists from the paired target groups to satisfy the backend
      List<int> targetSemesters = addedTargets.map((t) => int.parse(t['sem']!)).toSet().toList();
      List<String> targetSections = addedTargets.map((t) => t['sec']!).toSet().toList();

      await ref.read(announcementRepositoryProvider).createAnnouncement(
        title: title,
        body: body,
        authorName: user.name,
        authorUid: user.id,
        targetSemesters: isGlobal ? [] : targetSemesters,
        targetSections: isGlobal ? [] : targetSections,
        isGlobal: isGlobal,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Announcement created!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("New Announcement", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w500)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "Title",
                hintStyle: TextStyle(color: Colors.white54, fontSize: 16.sp),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: bodyController,
              maxLines: 6,
              style: TextStyle(color: Colors.white, fontSize: 16.sp),
              decoration: InputDecoration(
                hintText: "Write your message here...",
                hintStyle: TextStyle(color: Colors.white54, fontSize: 16.sp),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
              ),
            ),

            SizedBox(height: 24.h),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: SwitchListTile(
                title: Text("Global Announcement", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500)),
                subtitle: Text("Send to everyone", style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                value: isGlobal,
                activeThumbColor: const Color(0xFF1877F2), // Premium Blue
                activeTrackColor: const Color(0xFF1877F2).withValues(alpha: 0.5),
                onChanged: (val) {
                  setState(() {
                    isGlobal = val;
                    if (isGlobal) {
                      addedTargets.clear();
                    }
                  });
                },
              ),
            ),

            if (!isGlobal) ...[
              SizedBox(height: 24.h),
              Text("Target Groups", style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 12.h),

              // RESTORED: Functional Add Group Row
              Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Semester", style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                              SizedBox(height: 6.h),
                              Container(
                                  height: 48.h,
                                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12.r)),
                                  child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: currentSem,
                                        dropdownColor: const Color(0xFF1E1E1E),
                                        isExpanded: true,
                                        style: TextStyle(color: Colors.white, fontSize: 16.sp),
                                        items: ['1','2','3','4','5','6','7','8'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                        onChanged: (val) => setState(() => currentSem = val!),
                                      )
                                  )
                              )
                            ]
                        )
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Section", style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                              SizedBox(height: 6.h),
                              Container(
                                  height: 48.h,
                                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12.r)),
                                  child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: currentSec,
                                        dropdownColor: const Color(0xFF1E1E1E),
                                        isExpanded: true,
                                        style: TextStyle(color: Colors.white, fontSize: 16.sp),
                                        items: ['A','B','C'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                        onChanged: (val) => setState(() => currentSec = val!),
                                      )
                                  )
                              )
                            ]
                        )
                    ),
                    SizedBox(width: 12.w),
                    Container(
                        height: 48.h,
                        width: 48.h,
                        decoration: BoxDecoration(
                            color: const Color(0xFF1877F2), // Premium Blue
                            borderRadius: BorderRadius.circular(12.r)
                        ),
                        child: IconButton(
                            icon: Icon(Icons.add, color: Colors.white, size: 24.sp),
                            onPressed: () {
                              // Prevent adding duplicates
                              bool exists = addedTargets.any((t) => t['sem'] == currentSem && t['sec'] == currentSec);
                              if (!exists) {
                                setState(() => addedTargets.add({'sem': currentSem, 'sec': currentSec}));
                              }
                            }
                        )
                    )
                  ]
              ),

              SizedBox(height: 16.h),

              // Displaying the added target combinations
              if (addedTargets.isNotEmpty)
                Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: addedTargets.map((target) => Chip(
                    label: Text("Sem ${target['sem']} - Sec ${target['sec']}", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                    backgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.2), // Premium subtle background
                    deleteIcon: Icon(Icons.close, color: Colors.white70, size: 18.sp),
                    onDeleted: () => setState(() => addedTargets.remove(target)),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  )).toList(),
                ),
            ],

            SizedBox(height: 40.h),

            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: isLoading ? null : handleCreate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2), // Premium Blue
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                child: isLoading
                    ? SizedBox(height: 20.h, width: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Post Announcement", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}