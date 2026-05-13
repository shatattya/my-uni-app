import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added for Provider access

import 'tabs/home_tab.dart';
import 'tabs/routine_tab.dart';
import 'tabs/notice_tab.dart';
import 'tabs/profile_tab.dart';
import '../../../services/update_service.dart'; // Added
import '../../widgets/update_notice_sheet.dart'; // Added

class HomeScreen extends ConsumerStatefulWidget { // Changed to ConsumerStatefulWidget
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeTab(),
    RoutineTab(),
    NoticeTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _setupInteractedMessage();

    // MODIFICATION: Trigger automatic background update check on startup after a 7-second delay
    Future.delayed(const Duration(seconds: 7), () {
      if (mounted) {
        _checkForUpdatesSilently();
      }
    });
  }

  Future<void> _checkForUpdatesSilently() async {
    try {
      final updateService = ref.read(updateServiceProvider);
      final info = await updateService.checkForUpdates();

      if (info.hasUpdate && mounted) {
        UpdateNoticeSheet.show(context, info);
      }
    } catch (e) {
      print("DEBUG: Background update check failed: $e");
    }
  }

  Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _navigateToNotices();
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _navigateToNotices());
  }

  void _navigateToNotices() {
    setState(() => _currentIndex = 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        height: 85.h,
        padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
        color: Colors.black,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _navItem(Icons.home, Icons.home_outlined, "Home", 0),
            _navItem(Icons.calendar_today, Icons.calendar_today_outlined, "Routine", 1),
            _navItem(Icons.campaign, Icons.campaign_outlined, "Notice", 2),
            _navItem(Icons.person, Icons.person_outline, "Profile", 3),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData activeIcon, IconData inactiveIcon, String label, int index) {
    bool isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1877F2) : Colors.transparent,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : inactiveIcon,
                size: 26.r,
                color: isActive ? const Color(0xFFFFFFFF) : Colors.white54,
              ),
              SizedBox(height: 4.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? const Color(0xFFFFFFFF) : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}