import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/repositories/announcement_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/update_service.dart';
import '../../routes/app_router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_pressable.dart';
import '../../widgets/update_notice_sheet.dart';
import 'tabs/home_tab.dart';
import 'tabs/notice_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/routine_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  Timer? _updateCheckTimer;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedAppMessageSubscription;
  bool _isOpeningNotice = false;

  // Tracks the timestamp of the last back press for the double-tap exit
  DateTime? _lastPressedAt;

  final List<Widget> _screens = const [
    HomeTab(),
    RoutineTab(),
    NoticeTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _currentIndex,
    );

    _setupInteractedMessage();

    _updateCheckTimer = Timer(
      const Duration(seconds: 7),
          () {
        if (mounted) {
          unawaited(
            _checkForUpdatesSilently(),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    _foregroundMessageSubscription?.cancel();
    _openedAppMessageSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdatesSilently() async {
    try {
      final updateService = ref.read(updateServiceProvider);
      final info = await updateService.checkForUpdates();

      if (!mounted || !info.hasUpdate) {
        return;
      }

      UpdateNoticeSheet.show(
        context,
        info,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Silent update check failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> _setupInteractedMessage() async {
    _foregroundMessageSubscription =
        FirebaseMessaging.onMessage.listen(
              (message) {
            unawaited(
              _syncAnnouncementsFromMessage(),
            );
          },
        );

    _openedAppMessageSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(
              (message) {
            unawaited(
              _navigateToNotices(message),
            );
          },
        );

    try {
      final initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

      if (!mounted || initialMessage == null) {
        return;
      }

      await _navigateToNotices(initialMessage);
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to resolve initial Firebase Messaging message: '
            '$error\n$stackTrace',
      );
    }
  }

  Future<void> _syncAnnouncementsFromMessage() async {
    try {
      await ref
          .read(announcementRepositoryProvider)
          .syncAnnouncements();
    } catch (error, stackTrace) {
      debugPrint(
        'Announcement sync after notification failed: '
            '$error\n$stackTrace',
      );
    }
  }

  Future<void> _navigateToNotices(
      RemoteMessage message,
      ) async {
    if (!mounted || _isOpeningNotice) {
      return;
    }

    _isOpeningNotice = true;

    try {
      _selectTab(2);

      final noticeId =
          message.data['id'] ??
              message.data['noticeId'] ??
              message.data['announcementId'];

      if (noticeId == null ||
          noticeId.toString().trim().isEmpty) {
        return;
      }

      await ref
          .read(announcementRepositoryProvider)
          .syncAnnouncements();

      if (!mounted) {
        return;
      }

      final uid =
          firebase_auth.FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        return;
      }

      final user = await ref
          .read(userRepositoryProvider)
          .watchUser(uid)
          .first;

      if (!mounted || user == null) {
        return;
      }

      final notices = await ref
          .read(announcementRepositoryProvider)
          .watchMyAnnouncements(
        user.semester,
        user.section,
        user.role,
        user.id,
      )
          .first;

      if (!mounted) {
        return;
      }

      dynamic targetNotice;

      for (final notice in notices) {
        if (notice.id == noticeId) {
          targetNotice = notice;
          break;
        }
      }

      if (targetNotice == null) {
        return;
      }

      await Navigator.pushNamed(
        context,
        AppRoutes.detailAnnouncement,
        arguments: targetNotice,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Deep link to AnnouncementDetailScreen failed: '
            '$error\n$stackTrace',
      );
    } finally {
      _isOpeningNotice = false;
    }
  }

  void _selectTab(int index) {
    if (!mounted ||
        index < 0 ||
        index >= _screens.length) {
      return;
    }
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    if (!_pageController.hasClients) {
      return;
    }

    // Jumping prevents viewing intermediate tabs during a bar tap
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;

        // Route back to home tab from any other tab
        if (_currentIndex != 0) {
          _selectTab(0);
          return;
        }

        // Handle double-tap to exit on the home tab
        final now = DateTime.now();
        final canExit = _lastPressedAt != null &&
            now.difference(_lastPressedAt!) <= const Duration(seconds: 2);

        if (canExit) {
          SystemNavigator.pop();
        } else {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Press back again to exit',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.elevatedSurface,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PageView(
          controller: _pageController,
          // Allowed swiping for adjacent tabs. Bar taps will still jump instantly.
          onPageChanged: (index) {
            if (!mounted || _currentIndex == index) {
              return;
            }
            setState(() {
              _currentIndex = index;
            });
          },
          children: _screens,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: EdgeInsets.only(
            left: 8.w,
            right: 8.w,
            top: 8.h,
            bottom: 8.h,
          ),
          child: SizedBox(
            height: 72.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _navItem(
                  activeIcon: Icons.home,
                  inactiveIcon: Icons.home_outlined,
                  label: 'Home',
                  index: 0,
                ),
                _navItem(
                  activeIcon: Icons.calendar_today,
                  inactiveIcon: Icons.calendar_today_outlined,
                  label: 'Routine',
                  index: 1,
                ),
                _navItem(
                  activeIcon: Icons.campaign,
                  inactiveIcon: Icons.campaign_outlined,
                  label: 'Notice',
                  index: 2,
                ),
                _navItem(
                  activeIcon: Icons.person,
                  inactiveIcon: Icons.person_outline,
                  label: 'Profile',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 4.w,
        ),
        child: AppPressable(
          semanticLabel: '$label tab',
          selected: isActive,
          onTap: () => _selectTab(index),
          minHeight: 48.h,
          borderRadius: BorderRadius.circular(16.r),
          padding: EdgeInsets.zero,
          backgroundColor:
          isActive ? AppColors.primary : Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : inactiveIcon,
                size: 28.r,
                color: isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              SizedBox(height: 4.h),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight:
                  isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}