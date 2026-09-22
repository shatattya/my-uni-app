import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/local/app_database.dart';
import '../../../data/models/announcement_target.dart';
import '../../../data/repositories/announcement_repository.dart';

class EditAnnouncementScreen
    extends ConsumerStatefulWidget {
  final Announcement notice;

  const EditAnnouncementScreen({
    super.key,
    required this.notice,
  });

  @override
  ConsumerState<EditAnnouncementScreen> createState() =>
      _EditAnnouncementScreenState();
}

class _EditAnnouncementScreenState
    extends ConsumerState<EditAnnouncementScreen> {
  late TextEditingController titleController;
  late TextEditingController bodyController;

  late bool isGlobal;

  bool isLoading = false;

  int currentSem = 1;
  String currentSec = 'A';

  final List<AnnouncementTarget> addedTargets = [];

  @override
  void initState() {
    super.initState();

    titleController =
        TextEditingController(
          text: widget.notice.title,
        );

    bodyController =
        TextEditingController(
          text: widget.notice.body,
        );

    isGlobal = widget.notice.isGlobal;

    final canonicalTargets =
    AnnouncementTarget.decodeList(
      widget.notice.targetGroups,
    );

    if (canonicalTargets.isNotEmpty) {
      addedTargets.addAll(
        canonicalTargets,
      );
      return;
    }

    if (!widget.notice.isGlobal) {
      addedTargets.addAll(
        _decodeLegacyTargets(),
      );
    }
  }

  List<AnnouncementTarget> _decodeLegacyTargets() {
    try {
      final semesters =
      jsonDecode(widget.notice.targetSemesters);

      final sections =
      jsonDecode(widget.notice.targetSections);

      return AnnouncementTarget.fromLegacyLists(
        semesters,
        sections,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<void> handleUpdate() async {
    final title = titleController.text.trim();
    final body = bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Title and body cannot be empty',
          ),
        ),
      );
      return;
    }

    if (!isGlobal && addedTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add at least one target group.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await ref
          .read(announcementRepositoryProvider)
          .updateAnnouncement(
        noticeId: widget.notice.id,
        title: title,
        body: body,
        targetGroups:
        List.unmodifiable(addedTargets),
        isGlobal: isGlobal,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Announcement updated!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Edit Announcement',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme:
        const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              maxLength: 200,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(
                  color: Colors.white54,
                  fontSize: 16.sp,
                ),
                counterStyle:
                const TextStyle(color: Colors.white38),
                filled: true,
                fillColor:
                const Color(0xFF1E1E1E),
                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: bodyController,
              maxLines: 6,
              maxLength: 10000,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
              ),
              decoration: InputDecoration(
                hintText:
                'Write your message here...',
                hintStyle: TextStyle(
                  color: Colors.white54,
                  fontSize: 16.sp,
                ),
                counterStyle:
                const TextStyle(color: Colors.white38),
                filled: true,
                fillColor:
                const Color(0xFF1E1E1E),
                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius:
                BorderRadius.circular(12.r),
              ),
              child: SwitchListTile(
                title: Text(
                  'Global Announcement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Send to everyone',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12.sp,
                  ),
                ),
                value: isGlobal,
                activeThumbColor:
                const Color(0xFF1877F2),
                activeTrackColor:
                const Color(0xFF1877F2)
                    .withValues(alpha: 0.5),
                onChanged: (value) {
                  setState(() {
                    isGlobal = value;

                    if (isGlobal) {
                      addedTargets.clear();
                    }
                  });
                },
              ),
            ),
            if (!isGlobal) ...[
              SizedBox(height: 24.h),
              Text(
                'Target Groups',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Semester',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          height: 48.h,
                          padding:
                          EdgeInsets.symmetric(
                            horizontal: 12.w,
                          ),
                          decoration: BoxDecoration(
                            color:
                            const Color(0xFF1E1E1E),
                            borderRadius:
                            BorderRadius.circular(
                              12.r,
                            ),
                          ),
                          child:
                          DropdownButtonHideUnderline(
                            child:
                            DropdownButton<int>(
                              value: currentSem,
                              dropdownColor:
                              const Color(0xFF1E1E1E),
                              isExpanded: true,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                              ),
                              items: List.generate(
                                8,
                                    (index) => index + 1,
                              )
                                  .map(
                                    (value) =>
                                    DropdownMenuItem(
                                      value: value,
                                      child:
                                      Text('$value'),
                                    ),
                              )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  currentSem =
                                      value;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Section',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          height: 48.h,
                          padding:
                          EdgeInsets.symmetric(
                            horizontal: 12.w,
                          ),
                          decoration: BoxDecoration(
                            color:
                            const Color(0xFF1E1E1E),
                            borderRadius:
                            BorderRadius.circular(
                              12.r,
                            ),
                          ),
                          child:
                          DropdownButtonHideUnderline(
                            child:
                            DropdownButton<String>(
                              value: currentSec,
                              dropdownColor:
                              const Color(0xFF1E1E1E),
                              isExpanded: true,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                              ),
                              items: const [
                                'A',
                                'B',
                                'C',
                              ]
                                  .map(
                                    (value) =>
                                    DropdownMenuItem(
                                      value: value,
                                      child:
                                      Text(value),
                                    ),
                              )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  currentSec =
                                      value;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Container(
                    height: 48.h,
                    width: 48.w,
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFF1877F2),
                      borderRadius:
                      BorderRadius.circular(12.r),
                    ),
                    child: IconButton(
                      tooltip: 'Add target group',
                      icon: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24.sp,
                      ),
                      onPressed: () {
                        final target =
                        AnnouncementTarget(
                          semester: currentSem,
                          section: currentSec,
                        );

                        if (addedTargets
                            .contains(target)) {
                          return;
                        }

                        setState(() {
                          addedTargets.add(target);
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (addedTargets.isNotEmpty)
                Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: addedTargets
                      .map(
                        (target) => Chip(
                      label: Text(
                        'Sem ${target.semester} - Sec ${target.normalizedSection}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                        ),
                      ),
                      backgroundColor:
                      const Color(0xFF1877F2)
                          .withValues(
                        alpha: 0.2,
                      ),
                      deleteIcon: Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 18.sp,
                      ),
                      onDeleted: () {
                        setState(() {
                          addedTargets.remove(
                            target,
                          );
                        });
                      },
                      side: BorderSide.none,
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(
                          8.r,
                        ),
                      ),
                    ),
                  )
                      .toList(),
                ),
            ],
            SizedBox(height: 40.h),
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed:
                isLoading ? null : handleUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(0xFF1877F2),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(16.r),
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                  height: 20.h,
                  width: 20.w,
                  child:
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  'Update Announcement',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}