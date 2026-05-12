import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Added ScreenUtil

import '../../../../data/repositories/announcement_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../create_announcement_screen.dart';
import '../announcement_detail_screen.dart';
import '../edit_announcement_screen.dart';

class NoticeTab extends ConsumerStatefulWidget {
  const NoticeTab({super.key});

  @override
  ConsumerState<NoticeTab> createState() => _NoticeTabState();
}

class _NoticeTabState extends ConsumerState<NoticeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(announcementRepositoryProvider).syncAnnouncements();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text("Please login", style: TextStyle(color: Colors.white, fontSize: 16.sp)),
        ),
      );
    }

    return StreamBuilder(
      stream: ref.watch(userRepositoryProvider).watchUser(uid),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1877F2)), // Premium Blue
            ),
          );
        }

        final user = userSnapshot.data;

        if (user == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: ElevatedButton(
                onPressed: () => ref.read(userRepositoryProvider).syncUser(uid),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
                child: Text("User data not synced. Tap to Sync", style: TextStyle(fontSize: 14.sp)),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            centerTitle: true,
            title: Text(
              "Announcements",
              style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w600), // Scaled
            ),
          ),
          floatingActionButton:
          (user.role == "teacher" || user.isDev || user.isCR)
              ? FloatingActionButton(
            backgroundColor: const Color(0xFF1877F2), // Premium Blue
            tooltip: "Create Announcement",
            elevation: 4,
            child: Icon(Icons.add, color: Colors.white, size: 28.sp),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateAnnouncementScreen(),
                ),
              );
            },
          )
              : null,
          body: StreamBuilder(
            stream: ref
                .watch(announcementRepositoryProvider)
                .watchMyAnnouncements(user.semester, user.section, user.role, user.id),
            builder: (context, announcementSnapshot) {
              if (announcementSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1877F2)),
                );
              }

              final notices = announcementSnapshot.data ?? [];

              if (notices.isEmpty) {
                return Center(
                  child: Text(
                    "No notices for your section.",
                    style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                  ),
                );
              }

              return RefreshIndicator(
                color: const Color(0xFF1877F2),
                onRefresh: () => ref.read(announcementRepositoryProvider).syncAnnouncements(),
                child: ListView.builder(
                  padding: EdgeInsets.all(16.w), // Scaled padding
                  itemCount: notices.length,
                  itemBuilder: (context, index) =>
                      _buildNoticeCard(context, notices[index], user.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNoticeCard(BuildContext context, dynamic notice, String currentUserId) {
    bool isAuthor = notice.authorUid == currentUserId;

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h), // Scaled
      child: Material(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16.r), // Scaled radius
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnnouncementDetailScreen(notice: notice),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16.w), // Scaled
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14.r, // Scaled
                          backgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.2), // Premium subtle background
                          child: Icon(
                            Icons.person_outline, // Premium outlined icon
                            color: const Color(0xFF1877F2),
                            size: 16.sp, // Scaled
                          ),
                        ),
                        SizedBox(width: 8.w), // Scaled
                        if (!isAuthor)
                          Text(
                            notice.authorName,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14.sp, // Scaled
                            ),
                          ),
                      ],
                    ),
                    if (isAuthor)
                      Text(
                        "You",
                        style: TextStyle(
                          color: const Color(0xFF1877F2), // Premium Blue
                          fontSize: 14.sp, // Scaled
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 16.h), // Scaled

                Text(
                  notice.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp, // Scaled
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h), // Scaled
                Text(
                  notice.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14.sp, // Scaled
                    height: 1.4,
                  ),
                ),

                SizedBox(height: 16.h), // Scaled

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('MM/dd/yyyy').format(notice.createdAt),
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12.sp, // Scaled
                      ),
                    ),

                    if (isAuthor)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6.r),
                              splashColor: Colors.blueAccent.withValues(alpha: 0.1),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditAnnouncementScreen(notice: notice),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h), // Scaled
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20.sp), // Scaled & Outlined
                                    SizedBox(width: 4.w),
                                    Text("Edit", style: TextStyle(color: Colors.blueAccent, fontSize: 14.sp)),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 12.w), // Scaled

                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6.r),
                              splashColor: Colors.redAccent.withValues(alpha: 0.1),
                              onTap: () => _showDeleteConfirmation(context, notice.id),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h), // Scaled
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 20.sp), // Scaled & Outlined
                                    SizedBox(width: 4.w),
                                    Text("Delete", style: TextStyle(color: Colors.redAccent, fontSize: 14.sp)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String noticeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)), // Scaled
        title: Text(
          "Delete Announcement?",
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Text(
          "This will remove the announcement from the feed.",
          style: TextStyle(color: Colors.white70, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.white54, fontSize: 16.sp)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first

              // MODIFICATION: Added bug-fix for silent deletion handling
              try {
                await ref.read(announcementRepositoryProvider).softDeleteAnnouncement(noticeId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Announcement deleted successfully"), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to delete announcement"), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: Text("Delete", style: TextStyle(color: Colors.redAccent, fontSize: 16.sp)),
          ),
        ],
      ),
    );
  }
}