import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../../widgets/home_feature_tile.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/live_event_repository.dart'; // For dynamic event button
import '../../../../services/update_service.dart';
import '../../../widgets/update_notice_sheet.dart';
import '../contact_us_screen.dart';
import '../exam_routine_screen.dart';
import '../live_events_screen.dart'; // ADDED: Import for the Live Events Screen
import '../../attendance/attendance_setup_screen.dart';
import '../../attendance/attendance_export_screen.dart';
import '../developer_triage_screen.dart';
import '../../books_catalog_screen.dart';
import '../../notes_catalog_screen.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  bool _isCheckingUpdate = false;

  void _manualUpdateCheck() async {
    setState(() => _isCheckingUpdate = true);

    final updateService = ref.read(updateServiceProvider);
    final info = await updateService.checkForUpdates();

    setState(() => _isCheckingUpdate = false);

    if (mounted) {
      if (info.hasUpdate) {
        UpdateNoticeSheet.show(context, info);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("App is up to date!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final userStream = firebaseUser != null
        ? ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid)
        : const Stream.empty();

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: _buildDrawer(context, ref),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 20.w, top: 10.h, bottom: 10.h),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Builder(
                  builder: (ctx) => IconButton(
                    icon: Icon(Icons.menu, color: Colors.white, size: 30.r),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: SizedBox(
                width: double.infinity,
                height: 230.h,
                child: _buildBannerContainer(),
              ),
            ),
            SizedBox(height: 24.h),
            Expanded(
              child: StreamBuilder(
                  stream: userStream,
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final isTeacher = user != null && user.role == 'teacher';
                    final isDev = user != null && user.isDev == true;

                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: GridView(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 14.w,
                          mainAxisSpacing: 18.h,
                          mainAxisExtent: 115.h,
                        ),
                        children: [
                          const HomeFeatureTile(icon: Icons.calendar_today_outlined, label: "Academic\nCalendar"),

                          if (!isTeacher)
                            HomeFeatureTile(
                              icon: Icons.assignment_outlined,
                              label: "Exam\nRoutine",
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamRoutineScreen()));
                              },
                            ),

                          HomeFeatureTile(
                            icon: Icons.picture_as_pdf_outlined,
                            label: "Notes",
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesCatalogScreen()));
                            },
                          ),
                          HomeFeatureTile(
                            icon: Icons.menu_book_outlined,
                            label: "Books",
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const BooksCatalogScreen()));
                            },
                          ),

                          if (!isTeacher)
                            const HomeFeatureTile(icon: Icons.directions_bus_outlined, label: "Bus\nSchedule"),

                          const HomeFeatureTile(icon: Icons.sports_score_outlined, label: "Clubs"),

                          // Dynamic Live Events Button natively routed
                          FutureBuilder<String>(
                            future: ref.read(liveEventRepositoryProvider).getHomeTabButtonLabel(),
                            initialData: "Events",
                            builder: (context, snapshot) {
                              return HomeFeatureTile(
                                icon: Icons.emoji_events_outlined,
                                label: snapshot.data ?? "Events",
                                onTap: () {
                                  // MODIFICATION: Wired up the live events screen natively
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveEventsScreen()));
                                },
                              );
                            },
                          ),

                          if (isTeacher) ...[
                            HomeFeatureTile(
                              icon: Icons.sentiment_satisfied_outlined,
                              label: "Attendance",
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceSetupScreen()));
                              },
                            ),
                            HomeFeatureTile(
                              icon: Icons.ios_share_outlined,
                              label: "Attendance\nDashboard",
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceExportScreen()));
                              },
                            ),
                          ],

                          if (isDev)
                            HomeFeatureTile(
                              icon: Icons.pending_actions_outlined,
                              label: "Pending",
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperTriageScreen()));
                              },
                            ),
                        ],
                      ),
                    );
                  }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerContainer() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        image: const DecorationImage(
          image: AssetImage("assets/images/home_banner.png"),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          color: Colors.black.withValues(alpha: 0.35),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "All In One\nAcademics",
              style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
            ),
            SizedBox(height: 8.h),
            Text(
              "Look What Is Going On In Campus –\nNotices, Events & Academics",
              style: TextStyle(fontSize: 15.sp, color: Colors.white.withValues(alpha: 0.9), height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final userStream = firebaseUser != null
        ? ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid)
        : const Stream.empty();

    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 20.w, right: 10.w, top: 10.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Menu", style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.cancel_outlined, color: Colors.white, size: 30.r),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            StreamBuilder(
              stream: userStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final user = snapshot.data;
                final formattedAvatarId = user?.avatarId.toString().padLeft(2, '0') ?? '01';

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 34.r,
                        backgroundColor: Colors.transparent,
                        backgroundImage: AssetImage("assets/avatars/$formattedAvatarId.png"),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? "User", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4.h),
                            Text(user?.internalId ?? "", style: TextStyle(color: Colors.white54, fontSize: 15.sp)),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 40.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  _buildDrawerButton(
                    icon: Icons.sync,
                    label: _isCheckingUpdate ? "Checking..." : "Check For Updates",
                    onTap: _isCheckingUpdate ? null : () {
                      Navigator.pop(context);
                      _manualUpdateCheck();
                    },
                  ),
                  SizedBox(height: 16.h),
                  _buildDrawerButton(
                    icon: Icons.contact_mail_outlined,
                    label: "Contact Us",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen()));
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerButton({required IconData icon, required String label, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1877F2),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24.sp),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}