import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil

import '../../../data/repositories/announcement_repository.dart';

class EditAnnouncementScreen extends ConsumerStatefulWidget {
  final dynamic notice;

  const EditAnnouncementScreen({super.key, required this.notice});

  @override
  ConsumerState<EditAnnouncementScreen> createState() => _EditAnnouncementScreenState();
}

class _EditAnnouncementScreenState extends ConsumerState<EditAnnouncementScreen> {
  late TextEditingController titleController;
  late TextEditingController bodyController;

  late bool isGlobal;
  bool isLoading = false;

  // RESTORED: Functional Target Group Logic variables
  String currentSem = "1";
  String currentSec = "A";
  List<Map<String, String>> addedTargets = [];

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.notice.title);
    bodyController = TextEditingController(text: widget.notice.body);
    isGlobal = widget.notice.isGlobal;

    // Reverse-engineer the separate lists back into paired targets for the UI
    try {
      final semList = widget.notice.targetSemesters is String
          ? _decodeJsonList(widget.notice.targetSemesters)
          : widget.notice.targetSemesters;

      final secList = widget.notice.targetSections is String
          ? _decodeJsonList(widget.notice.targetSections)
          : widget.notice.targetSections;

      // Cartesian logic: matches how the backend previously broadcasted
      addedTargets = [];
      for (var s in semList) {
        for (var c in secList) {
          if (s != null && c != null) {
            addedTargets.add({'sem': s.toString().trim(), 'sec': c.toString().trim()});
          }
        }
      }
    } catch (e) {
      addedTargets = [];
    }
  }

  List<dynamic> _decodeJsonList(String source) {
    if (source.isEmpty || source == "[]") return [];
    final clean = source.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
    if (clean.isEmpty) return [];
    return clean.split(',').map((e) => e.trim()).toList();
  }

  void handleUpdate() async {
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
      // Extract unique lists from the paired target groups
      List<int> targetSemesters = addedTargets.map((t) => int.parse(t['sem']!)).toSet().toList();
      List<String> targetSections = addedTargets.map((t) => t['sec']!).toSet().toList();

      await ref.read(announcementRepositoryProvider).updateAnnouncement(
        noticeId: widget.notice.id,
        title: title,
        body: body,
        targetSemesters: isGlobal ? [] : targetSemesters,
        targetSections: isGlobal ? [] : targetSections,
        isGlobal: isGlobal,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Announcement updated!"), backgroundColor: Colors.green),
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
        title: Text("Edit Announcement", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w500)),
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

              if (addedTargets.isNotEmpty)
                Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: addedTargets.map((target) => Chip(
                    label: Text("Sem ${target['sem']} - Sec ${target['sec']}", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                    backgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.2),
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
                onPressed: isLoading ? null : handleUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2), // Premium Blue
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                child: isLoading
                    ? SizedBox(height: 20.h, width: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Update Announcement", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}