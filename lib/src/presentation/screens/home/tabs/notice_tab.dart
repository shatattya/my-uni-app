import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../data/local/app_database.dart';
import '../../../../data/repositories/announcement_repository.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_theme.dart';
import '../widgets/announcement_card.dart';

class NoticeTab extends ConsumerStatefulWidget {
  const NoticeTab({super.key});

  @override
  ConsumerState<NoticeTab> createState() => _NoticeTabState();
}

class _NoticeTabState extends ConsumerState<NoticeTab> {
  Stream<dynamic>? _userStream;

  bool _isSyncing = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      _userStream = ref.read(userRepositoryProvider).watchUser(uid);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAnnouncements(silent: true);
    });
  }

  Future<void> _syncAnnouncements({
    bool silent = false,
  }) async {
    if (_isSyncing) {
      return;
    }

    if (mounted) {
      setState(() {
        _isSyncing = true;
        _syncError = null;
      });
    }

    try {
      await ref
          .read(announcementRepositoryProvider)
          .syncAnnouncements();

      if (!mounted) {
        return;
      }

      setState(() {
        _syncError = null;
      });

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcements synced successfully.'),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to sync announcements: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _syncError = 'Could not refresh announcements.';
      });

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error
                  .toString()
                  .replaceFirst('Exception: ', '')
                  .trim()
                  .isEmpty
                  ? 'Could not refresh announcements.'
                  : error
                  .toString()
                  .replaceFirst('Exception: ', '')
                  .trim(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _showDeleteConfirmation(
      BuildContext context,
      String announcementId,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete announcement?'),
          content: const Text(
            'This announcement will be removed from the feed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                try {
                  await ref
                      .read(announcementRepositoryProvider)
                      .softDeleteAnnouncement(
                    announcementId,
                  );

                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Announcement deleted successfully.',
                      ),
                    ),
                  );
                } catch (error, stackTrace) {
                  debugPrint(
                    'Failed to delete announcement: $error',
                  );
                  debugPrintStack(
                    stackTrace: stackTrace,
                  );

                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not delete the announcement.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _openCreateAnnouncement() {
    HapticFeedback.lightImpact();

    Navigator.pushNamed(
      context,
      AppRoutes.createAnnouncement,
    );
  }

  void _openEditAnnouncement(Announcement notice) {
    HapticFeedback.lightImpact();

    Navigator.pushNamed(
      context,
      AppRoutes.editAnnouncement,
      arguments: notice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || _userStream == null) {
      return _buildScaffold(
        context,
        body: _buildCenteredState(
          context,
          icon: Icons.lock_outline_rounded,
          title: 'Please log in',
          subtitle: 'Sign in to view campus announcements.',
        ),
      );
    }

    return StreamBuilder<dynamic>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState ==
            ConnectionState.waiting) {
          return _buildScaffold(
            context,
            body: _buildLoadingState(context),
          );
        }

        if (userSnapshot.hasError) {
          return _buildScaffold(
            context,
            body: _buildCenteredState(
              context,
              icon: Icons.error_outline_rounded,
              title: 'Could not load your profile',
              subtitle: 'Please try again.',
              actionLabel: 'Retry',
              onAction: () => _syncAnnouncements(),
            ),
          );
        }

        final user = userSnapshot.data;

        if (user == null) {
          return _buildScaffold(
            context,
            body: _buildCenteredState(
              context,
              icon: Icons.person_outline_rounded,
              title: 'Profile unavailable',
              subtitle: 'Sync your profile to continue.',
              actionLabel: 'Sync',
              onAction: () async {
                try {
                  await ref
                      .read(userRepositoryProvider)
                      .syncUser(uid);
                } catch (error) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not sync your profile.',
                      ),
                    ),
                  );
                }
              },
            ),
          );
        }

        final canCreateAnnouncement =
            user.role == 'teacher' ||
                user.isDev == true ||
                user.isCR == true;

        return StreamBuilder<List<Announcement>>(
          stream: ref
              .read(announcementRepositoryProvider)
              .watchMyAnnouncements(
            user.semester,
            user.section,
            user.role,
            user.id,
          ),
          builder: (context, announcementSnapshot) {
            if (announcementSnapshot.connectionState ==
                ConnectionState.waiting) {
              return _buildScaffold(
                context,
                showCreateButton: canCreateAnnouncement,
                body: _buildLoadingState(context),
              );
            }

            if (announcementSnapshot.hasError) {
              return _buildScaffold(
                context,
                showCreateButton: canCreateAnnouncement,
                body: _buildCenteredState(
                  context,
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load announcements',
                  subtitle:
                  'Your cached announcements may still be unavailable.',
                  actionLabel: 'Refresh',
                  onAction: () => _syncAnnouncements(),
                ),
              );
            }

            final notices =
                announcementSnapshot.data ??
                    const <Announcement>[];

            return _buildScaffold(
              context,
              showCreateButton: canCreateAnnouncement,
              body: RefreshIndicator(
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  await _syncAnnouncements();
                },
                child: notices.isEmpty
                    ? _buildEmptyList(context)
                    : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    8.h,
                    16.w,
                    110.h,
                  ),
                  physics:
                  const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  itemCount: notices.length + 1,
                  separatorBuilder: (_, __) {
                    return SizedBox(height: 12.h);
                  },
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildFeedHeader(
                        context,
                        notices.length,
                      );
                    }

                    final notice = notices[index - 1];

                    return AnnouncementCard(
                      announcement: notice,
                      currentUserId: user.id,
                      onEdit: notice.authorUid == user.id
                          ? () {
                        _openEditAnnouncement(
                          notice,
                        );
                      }
                          : null,
                      onDelete: notice.authorUid == user.id
                          ? () {
                        _showDeleteConfirmation(
                          context,
                          notice.id,
                        );
                      }
                          : null,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScaffold(
      BuildContext context, {
        required Widget body,
        bool showCreateButton = false,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20.w,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Announcements',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Stay up to date with campus news',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(
              right: 12.w,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(13.r),
              child: Ink(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(13.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: InkWell(
                  borderRadius:
                  BorderRadius.circular(13.r),
                  onTap: _isSyncing
                      ? null
                      : () {
                    HapticFeedback.lightImpact();
                    _syncAnnouncements();
                  },
                  child: SizedBox(
                    width: 42.r,
                    height: 42.r,
                    child: _isSyncing
                        ? Padding(
                      padding: EdgeInsets.all(12.r),
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                        : Icon(
                      Icons.sync_rounded,
                      color: colorScheme.primary,
                      size: 21.r,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: showCreateButton
          ? FloatingActionButton(
        onPressed: _openCreateAnnouncement,
        tooltip: 'Create announcement',
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        child: Icon(
          Icons.add_rounded,
          size: 27.r,
        ),
      )
          : null,
      body: body,
    );
  }

  Widget _buildFeedHeader(
      BuildContext context,
      int count,
      ) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        4.w,
        3.h,
        4.w,
        2.h,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 1
                  ? '1 announcement'
                  : '$count announcements',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_syncError != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 15.r,
                  color: theme.colorScheme.error,
                ),
                SizedBox(width: 4.w),
                Text(
                  'Offline copy',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyList(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        24.w,
        24.h,
        24.w,
        110.h,
      ),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.16,
        ),
        Container(
          width: 76.r,
          height: 76.r,
          margin: EdgeInsets.symmetric(
            horizontal: 110.w,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(
              alpha: 0.09,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.campaign_outlined,
            size: 38.r,
            color: colorScheme.primary,
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          'No announcements yet',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 7.h),
        Text(
          'There are no announcements available for you right now.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        SizedBox(height: 20.h),
        Center(
          child: OutlinedButton.icon(
            onPressed: _isSyncing
                ? null
                : () => _syncAnnouncements(),
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text('Refresh'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(
      BuildContext context,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: CircularProgressIndicator(
        color: colorScheme.primary,
      ),
    );
  }

  Widget _buildCenteredState(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        String? actionLabel,
        VoidCallback? onAction,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 30.w,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70.r,
              height: 70.r,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(
                  alpha: 0.09,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34.r,
                color: colorScheme.primary,
              ),
            ),
            SizedBox(height: 17.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 18.h),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}