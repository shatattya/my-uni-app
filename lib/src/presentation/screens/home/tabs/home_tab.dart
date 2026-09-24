import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../data/local/app_database.dart' as local_db;
import '../../../../data/repositories/user_repository.dart';
import '../../../../services/update_service.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/update_notice_sheet.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  late final Stream<local_db.User?> _userStream;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    _userStream = firebaseUser == null
        ? const Stream<local_db.User?>.empty()
        : ref.read(userRepositoryProvider).watchUser(firebaseUser.uid);
  }

  Future<void> _manualUpdateCheck() async {
    if (_isCheckingUpdate) {
      return;
    }

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final updateService = ref.read(updateServiceProvider);
      final info = await updateService.checkForUpdates();

      if (!mounted) {
        return;
      }

      if (info.hasUpdate) {
        UpdateNoticeSheet.show(context, info);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App is up to date!'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check for updates. Please try again.'),
        ),
      );
      debugPrint('Manual update check failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  String _greetingForCurrentTime() {
    final hour = DateTime.now().hour;
    // Culturally accurate timeframes for Bangladesh
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 16) {
      return 'Good afternoon';
    } else if (hour >= 16 && hour < 20) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
  }

  String _formatAvatarId(int avatarId) {
    return avatarId.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userStream = _userStream;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: StreamBuilder<local_db.User?>(
          stream: userStream,
          builder: (context, snapshot) {
            final user = snapshot.data;
            final isTeacher = user?.role == 'teacher';
            final isDeveloper = user?.isDev == true;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
                  sliver: SliverToBoxAdapter(
                    child: _buildHeader(context, user),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  sliver: SliverToBoxAdapter(
                    child: _buildBanner(context),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 12.h),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text(
                          'Quick access',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 28.h),
                  sliver: SliverGrid(
                    delegate: SliverChildListDelegate(
                      _buildFeatureTiles(
                        context,
                        isTeacher: isTeacher,
                        isDeveloper: isDeveloper,
                      ),
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h,
                      mainAxisExtent: 96.h,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, local_db.User? user) {
    final theme = Theme.of(context);
    final displayName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'Welcome back';
    final subtitle = user == null
        ? _greetingForCurrentTime()
        : '${_greetingForCurrentTime()}${user.role == 'teacher' ? ', Teacher' : ''}';

    return Row(
      children: [
        Builder(
          builder: (drawerContext) {
            return Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.medium.r),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.medium.r),
                onTap: () {
                  Scaffold.of(drawerContext).openDrawer();
                },
                child: SizedBox(
                  width: 46.r,
                  height: 46.r,
                  child: Icon(
                    Icons.menu_rounded,
                    color: AppColors.textPrimary,
                    size: 24.r,
                  ),
                ),
              ),
            );
          },
        ),
        SizedBox(width: 12.w),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),

        if (user != null)
          CircleAvatar(
            radius: 23.r,
            backgroundColor: AppColors.surface,
            backgroundImage: AssetImage(
              'assets/avatars/${_formatAvatarId(user.avatarId)}.png',
            ),
          )
        else
          CircleAvatar(
            radius: 23.r,
            backgroundColor: AppColors.surface,
            child: Icon(
              Icons.person_outline_rounded,
              color: AppColors.textSecondary,
              size: 24.r,
            ),
          ),
      ],
    );
  }

  Widget _buildBanner(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.large.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/home_banner.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.38),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      'BGCTUB',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'All in one academics',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Your digital campus companion',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large.r),
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Padding(
          padding: EdgeInsets.all(14.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22.r,
                ),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _safeRoute(BuildContext context, String routeName) {
    try {
      Navigator.pushNamed(context, routeName);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Module under construction.')),
      );
    }
  }

  List<Widget> _buildFeatureTiles(
      BuildContext context, {
        required bool isTeacher,
        required bool isDeveloper,
      }) {
    return [
      _buildFeatureTile(
        context: context,
        label: 'Academic Calendar',
        icon: Icons.calendar_month_outlined,
        color: const Color(0xFF1877F2),
        onTap: () => _safeRoute(context, '/calendar'),
      ),
      _buildFeatureTile(
        context: context,
        label: 'Clubs',
        icon: Icons.groups_outlined,
        color: const Color(0xFF9C27B0),
        onTap: () => _safeRoute(context, '/clubs'),
      ),
      if (!isTeacher)
        _buildFeatureTile(
          context: context,
          label: 'Exam Routine',
          icon: Icons.assignment_outlined,
          color: const Color(0xFFE91E63),
          onTap: () => Navigator.pushNamed(context, AppRoutes.examRoutine),
        ),
      _buildFeatureTile(
        context: context,
        label: 'Books Library',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF4CAF50),
        onTap: () => Navigator.pushNamed(context, AppRoutes.books),
      ),
      _buildFeatureTile(
        context: context,
        label: 'Notes Catalog',
        icon: Icons.description_outlined,
        color: const Color(0xFFFF9800),
        onTap: () => Navigator.pushNamed(context, AppRoutes.notes),
      ),
      _buildFeatureTile(
        context: context,
        label: 'Live Events',
        icon: Icons.sports_soccer_rounded,
        color: const Color(0xFF00BCD4),
        onTap: () => Navigator.pushNamed(context, AppRoutes.liveEvents),
      ),
      if (isTeacher) ...[
        _buildFeatureTile(
          context: context,
          label: 'Attendance',
          icon: Icons.fact_check_outlined,
          color: const Color(0xFF607D8B),
          onTap: () => Navigator.pushNamed(context, AppRoutes.attendanceSetup),
        ),
        _buildFeatureTile(
          context: context,
          label: 'Attendance Dashboard',
          icon: Icons.dashboard_outlined,
          color: const Color(0xFF795548),
          onTap: () => Navigator.pushNamed(context, AppRoutes.attendanceExport),
        ),
      ],
      if (isDeveloper && !isTeacher)
        _buildFeatureTile(
          context: context,
          label: 'Pending',
          icon: Icons.pending_actions_outlined,
          color: Colors.redAccent,
          onTap: () => Navigator.pushNamed(context, AppRoutes.devTriage),
        ),
    ];
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: theme.colorScheme.primary,
                      size: 32.r,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    'BGCTUB\nCompanion',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            SizedBox(height: 16.h),
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 24.w),
              leading: Icon(
                Icons.update_rounded,
                color: AppColors.textSecondary,
                size: 24.r,
              ),
              title: Text(
                'Check for Updates',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _manualUpdateCheck();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 24.w),
              leading: Icon(
                Icons.support_agent_rounded,
                color: AppColors.textSecondary,
                size: 24.r,
              ),
              title: Text(
                'Contact Us',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.contact);
              },
            ),
          ],
        ),
      ),
    );
  }
}