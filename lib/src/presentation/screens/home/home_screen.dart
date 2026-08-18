import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'tabs/home_tab.dart';
import 'tabs/routine_tab.dart';
import 'tabs/notice_tab.dart';
import 'tabs/profile_tab.dart';
import '../../../services/update_service.dart';
import '../../widgets/update_notice_sheet.dart';
import '../../../data/repositories/announcement_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../routes/app_router.dart';

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
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      ref.read(announcementRepositoryProvider).syncAnnouncements();
    });

    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _navigateToNotices(initialMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToNotices(message);
    });
  }

  Future<void> _navigateToNotices(RemoteMessage message) async {
    setState(() => _currentIndex = 2);
    final String? noticeId = message.data['id'] ?? message.data['noticeId'] ?? message.data['announcementId'];
    if (noticeId != null) {
      try {
        await ref.read(announcementRepositoryProvider).syncAnnouncements();
        final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;
        final user = await ref.read(userRepositoryProvider).watchUser(uid).first;
        if (user == null) return;
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
        if (targetNotice != null && mounted) {
          Navigator.pushNamed(context, AppRoutes.detailAnnouncement, arguments: targetNotice);
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
        height: 95.h,
        padding: EdgeInsets.only(top: 10.h, bottom: 12.h),
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
                size: 28.r,
                color: isActive ? const Color(0xFFFFFFFF) : Colors.white54,
              ),
              SizedBox(height: 4.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
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