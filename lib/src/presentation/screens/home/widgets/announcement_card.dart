import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../data/local/app_database.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_theme.dart';

class AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final String currentUserId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.currentUserId,
    this.onEdit,
    this.onDelete,
  });

  bool get _isAuthor => announcement.authorUid == currentUserId;

  String get _audienceLabel {
    if (announcement.isGlobal) {
      return 'Everyone';
    }

    if (_isAuthor) {
      return 'Posted by you';
    }

    return 'For your section';
  }

  String get _formattedDate {
    final now = DateTime.now();
    final date = announcement.createdAt;

    final isToday =
        date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;

    if (isToday) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    }

    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));

    final isYesterday =
        date.year == yesterday.year &&
            date.month == yesterday.month &&
            date.day == yesterday.day;

    if (isYesterday) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    }

    return DateFormat('d MMM yyyy, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final authorName = _isAuthor
        ? 'You'
        : announcement.authorName.trim().isEmpty
        ? 'Unknown author'
        : announcement.authorName.trim();

    return Semantics(
      container: true,
      label:
      '${announcement.title}. Posted by $authorName. $_audienceLabel. $_formattedDate.',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(
              AppRadii.large.r,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();

              Navigator.pushNamed(
                context,
                AppRoutes.detailAnnouncement,
                arguments: announcement,
              );
            },
            borderRadius: BorderRadius.circular(
              AppRadii.large.r,
            ),
            splashColor: colorScheme.primary.withValues(alpha: 0.08),
            highlightColor:
            colorScheme.primary.withValues(alpha: 0.04),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16.w,
                15.h,
                12.w,
                14.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(
                    context,
                    authorName,
                  ),
                  SizedBox(height: 15.h),
                  _buildTitle(context),
                  SizedBox(height: 7.h),
                  _buildBody(context),
                  SizedBox(height: 15.h),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context,
      String authorName,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42.r,
          height: 42.r,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(13.r),
          ),
          child: Icon(
            announcement.isGlobal
                ? Icons.campaign_outlined
                : Icons.notifications_none_rounded,
            color: colorScheme.primary,
            size: 21.r,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _audienceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    width: 3.r,
                    height: 3.r,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      _formattedDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_isAuthor && (onEdit != null || onDelete != null))
          _buildActionsMenu(context),
      ],
    );
  }

  Widget _buildActionsMenu(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopupMenuButton<String>(
      tooltip: 'Announcement options',
      icon: Icon(
        Icons.more_horiz_rounded,
        color: AppColors.textTertiary,
        size: 22.r,
      ),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: 42.r,
        minHeight: 42.r,
      ),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            HapticFeedback.lightImpact();
            onEdit?.call();
            break;
          case 'delete':
            HapticFeedback.mediumImpact();
            onDelete?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (onEdit != null)
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 19.r,
                  color: colorScheme.primary,
                ),
                SizedBox(width: 10.w),
                const Text('Edit'),
              ],
            ),
          ),
        if (onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 19.r,
                  color: colorScheme.error,
                ),
                SizedBox(width: 10.w),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      announcement.title.trim().isEmpty
          ? 'Untitled announcement'
          : announcement.title.trim(),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      announcement.body.trim().isEmpty
          ? 'No content'
          : announcement.body.trim(),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
        height: 1.45,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          Icons.touch_app_outlined,
          size: 15.r,
          color: AppColors.textTertiary,
        ),
        SizedBox(width: 5.w),
        Text(
          'Tap to read',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.arrow_forward_rounded,
          size: 17.r,
          color: colorScheme.primary.withValues(alpha: 0.75),
        ),
      ],
    );
  }
}