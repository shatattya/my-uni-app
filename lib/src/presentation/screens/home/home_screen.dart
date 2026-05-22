import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth; // ADDED: For Deep-Link metadata extraction

import 'tabs/home_tab.dart';
import 'tabs/routine_tab.dart';
import 'tabs/notice_tab.dart';
import 'tabs/profile_tab.dart';
import '../../../services/update_service.dart';
import '../../widgets/update_notice_sheet.dart';
import '../../../data/repositories/announcement_repository.dart'; // ADDED: For syncing & querying notices
import '../../../data/repositories/user_repository.dart'; // ADDED: For user scoping
import 'announcement_detail_screen.dart'; // ADDED: For deep-link routing

class HomeScreen extends ConsumerStatefulWidget {
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

    // Trigger automatic background update check on startup after a 7-second delay
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
    // MODIFICATION (BUG 2 FIX): Listen for foreground messages and auto-refresh the notices quietly
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      ref.read(announcementRepositoryProvider).syncAnnouncements();
    });

    // Handle cold boot from a tapped notification
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _navigateToNotices(initialMessage);

    // Handle background wakeup from a tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToNotices(message);
    });
  }

  // MODIFICATION (BUG 1 FIX): Extract ID, fetch local data object, and push to the Detailed Screen
  Future<void> _navigateToNotices(RemoteMessage message) async {
    // 1. Immediately switch to Notice Tab, so popping the detail screen reveals the list
    setState(() => _currentIndex = 2);

    final String? noticeId = message.data['id'] ?? message.data['noticeId'] ?? message.data['announcementId'];

    if (noticeId != null) {
      try {
        // 2. Force an immediate sync to guarantee the tapped notice exists in SQLite
        await ref.read(announcementRepositoryProvider).syncAnnouncements();

        final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        // 3. Fetch localized user data for scope filtering
        final user = await ref.read(userRepositoryProvider).watchUser(uid).first;
        if (user == null) return;

        // 4. Extract the exact notice target dynamically from the local repo
        final notices = await ref.read(announcementRepositoryProvider)
            .watchMyAnnouncements(user.semester, user.section, user.role, user.id)
            .first;

        dynamic targetNotice;
        for (var n in notices) {
          if (n.id == noticeId) {
            targetNotice = n;
            break;
          }
        }

        // 5. Safely push the Detailed screen
        if (targetNotice != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnnouncementDetailScreen(notice: targetNotice),
            ),
          );
        }
      } catch (e) {
        print("DEBUG: Deep link to AnnouncementDetailScreen failed: $e");
      }
    }
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