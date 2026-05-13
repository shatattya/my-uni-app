import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../../widgets/home_feature_tile.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../services/update_service.dart';
import '../../../widgets/update_notice_sheet.dart';
import '../contact_us_screen.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent, // Keeps the underlying black background from IndexedStack
      drawer: _buildDrawer(context, ref),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 20.w, top: 10.h, bottom: 10.h),
              child: Align(
                alignment: Alignment.centerLeft,
                // Wrapped the icon in a Builder so it can find the Scaffold context to open the drawer
                child: Builder(
                  builder: (ctx) => IconButton(
                    icon: Icon(Icons.menu, color: Colors.white, size: 28.r),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: SizedBox(
                width: double.infinity,
                height: 200.h,
                child: _buildBannerContainer(),
              ),
            ),
            SizedBox(height: 24.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: GridView(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 16.h,
                    mainAxisExtent: 100.h,
                  ),
                  children: const [
                    HomeFeatureTile(icon: Icons.calendar_today_outlined, label: "Academic\nCalendar"),
                    HomeFeatureTile(icon: Icons.picture_as_pdf_outlined, label: "Notes"),
                    HomeFeatureTile(icon: Icons.menu_book_outlined, label: "Books"),
                    HomeFeatureTile(icon: Icons.directions_bus_outlined, label: "Bus\nSchedule"),
                    HomeFeatureTile(icon: Icons.sports_score_outlined, label: "Clubs"),
                    HomeFeatureTile(icon: Icons.directions_run_outlined, label: "Festivals"),
                    HomeFeatureTile(icon: Icons.sentiment_satisfied_outlined, label: "Attendance"),
                  ],
                ),
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
              style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
            ),
            SizedBox(height: 8.h),
            Text(
              "Look What Is Going On In Campus –\nNotices, Events & Academics",
              style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.9), height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  // The Drawer Menu based on your mockup
  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final userStream = firebaseUser != null
        ? ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid)
        : const Stream.empty();

    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E), // Dark grey background
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close Button Row
            Padding(
              padding: EdgeInsets.only(left: 20.w, right: 10.w, top: 10.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Menu", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.cancel_outlined, color: Colors.white, size: 28.r),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Profile Header
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
                        radius: 30.r,
                        backgroundColor: Colors.transparent,
                        backgroundImage: AssetImage("assets/avatars/$formattedAvatarId.png"),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? "User", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4.h),
                            Text(user?.internalId ?? "", style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 40.h),

            // Drawer Action Buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  _buildDrawerButton(
                    icon: Icons.sync,
                    label: _isCheckingUpdate ? "Checking..." : "Check For Updates",
                    onTap: _isCheckingUpdate ? null : () {
                      Navigator.pop(context); // Close drawer
                      _manualUpdateCheck(); // Trigger check
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
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1877F2), // Premium Blue
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22.sp),
            SizedBox(width: 16.w),
            // MODIFICATION: Wrapped Text in Expanded to prevent right-side overflow
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}