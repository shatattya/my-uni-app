import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../data/models/academic_calendar.dart';
import '../../../data/repositories/academic_calendar_repository.dart';
import '../../../providers/academic_calendar_provider.dart';
import '../../theme/app_theme.dart';

class AcademicCalendarScreen extends ConsumerWidget {
  const AcademicCalendarScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(academicCalendarProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                24.w,
                18.h,
                24.w,
                0,
              ),
              sliver: const SliverToBoxAdapter(
                child: _CalendarHeader(),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                24.w,
                28.h,
                24.w,
                28.h,
              ),
              sliver: SliverToBoxAdapter(
                child: _CalendarContainer(
                  calendarAsync: calendarAsync,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        SizedBox(height: 26.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              DateFormat('dd').format(now),
              style: theme.textTheme.displayLarge?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 70.sp,
                fontWeight: FontWeight.w800,
                height: 0.88,
                letterSpacing: -3.2,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEE').format(now),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 7.h),
                  Text(
                    DateFormat('MMMM, yyyy').format(now),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: const Color(0xFF191B1F),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 56.r,
            height: 56.r,
            child: Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textPrimary,
              size: 34.r,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarContainer extends StatelessWidget {
  final AsyncValue<AcademicCalendar> calendarAsync;

  const _CalendarContainer({
    required this.calendarAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111315),
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(
          color: const Color(0xFF1D2024),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16.w,
        28.h,
        16.w,
        28.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ColumnHeaders(),
          SizedBox(height: 16.h),
          calendarAsync.when(
            loading: () => const _LoadingState(),
            error: (error, stackTrace) => _ErrorState(error: error),
            data: (calendar) => _EventTimeline(calendar: calendar),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders();

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: AppColors.textSecondary,
      fontSize: 16.sp,
      fontWeight: FontWeight.w500,
      height: 1,
    );

    return Row(
      children: [
        SizedBox(
          width: _dateColumnWidth(),
          child: Text(
            'Date',
            style: textStyle,
          ),
        ),
        SizedBox(width: _columnGap()),
        Expanded(
          child: Text(
            'Events',
            style: textStyle,
          ),
        ),
      ],
    );
  }
}

class _EventTimeline extends StatelessWidget {
  final AcademicCalendar calendar;

  const _EventTimeline({
    required this.calendar,
  });

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final events = calendar.events
        .where((event) => event.isUpcomingFrom(today))
        .toList(growable: false);

    if (events.isEmpty) {
      return const _EmptyState();
    }

    return _TimelineContent(events: events);
  }
}

class _TimelineContent extends StatelessWidget {
  final List<AcademicCalendarEvent> events;

  const _TimelineContent({
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _dateColumnWidth(),
          child: Column(
            children: List.generate(
              events.length,
                  (index) => _DateTimelineItem(
                event: events[index],
                isLast: index == events.length - 1,
              ),
            ),
          ),
        ),
        SizedBox(width: _columnGap()),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(
              events.length,
                  (index) => _EventTimelineItem(
                event: events[index],
                isLast: index == events.length - 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateTimelineItem extends StatelessWidget {
  final AcademicCalendarEvent event;
  final bool isLast;

  const _DateTimelineItem({
    required this.event,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.type);
    final itemHeight = _timelineItemHeight(isLast: isLast);
    return SizedBox(
      width: double.infinity,
      height: itemHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Container(
              width: 1.5.w,
              color: const Color(0xFF55595F),
            ),
          ),
          Positioned(
            top: (_eventCardHeight() / 2) - (6.r),
            right: -5.r,
            child: Container(
              width: 12.r,
              height: 12.r,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 5.r,
                    spreadRadius: 1.r,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: _eventCardHeight(),
            child: Padding(
              padding: EdgeInsets.only(right: 18.w),
              child: Center(
                child: _DateLabel(event: event),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  final AcademicCalendarEvent event;

  const _DateLabel({
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
      fontSize: 13.5.sp,
      fontWeight: FontWeight.w500,
      height: 1.25,
    );
    final formatter = DateFormat('dd/MM/yyyy');

    if (event.isSingleDay) {
      return Text(
        formatter.format(event.startDate),
        textAlign: TextAlign.center,
        style: style,
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          formatter.format(event.startDate),
          textAlign: TextAlign.center,
          style: style,
        ),
        SizedBox(height: 7.h),
        Text(
          'to',
          style: style?.copyWith(
            color: AppColors.textTertiary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 7.h),
        Text(
          formatter.format(event.endDate),
          textAlign: TextAlign.center,
          style: style,
        ),
      ],
    );
  }
}

class _EventTimelineItem extends StatelessWidget {
  final AcademicCalendarEvent event;
  final bool isLast;

  const _EventTimelineItem({
    required this.event,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 0 : _eventGap(),
      ),
      child: SizedBox(
        width: double.infinity,
        height: _eventCardHeight(),
        child: _EventCard(event: event),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final AcademicCalendarEvent event;

  const _EventCard({
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.type);

    return Semantics(
      container: true,
      label: _semanticLabel(event),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(25.r),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, 0.05) ?? color,
                color,
              ],
            ),
          ),
          child: InkWell(
            onTap: () => _showEventDetails(context, event),
            borderRadius: BorderRadius.circular(25.r),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _CardDecorativeShape(),
                Positioned(
                  right: 13.w,
                  bottom: 10.h,
                  child: _DecorativeIcon(
                    icon: _eventIcon(event),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    15.w,
                    13.h,
                    50.w,
                    13.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _EventBadge(label: event.type.label),
                      SizedBox(height: 9.h),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          color: Colors.white,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      if (event.note != null) ...[
                        SizedBox(height: 7.h),
                        _EventNote(note: event.note!),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: 14.w,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: 29.r,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventBadge extends StatelessWidget {
  final String label;

  const _EventBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: 190.w,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 10.w,
        vertical: 6.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}

class _EventNote extends StatelessWidget {
  final String note;

  const _EventNote({
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: Colors.white,
          size: 18.r,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 11.5.sp,
              height: 1.25,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardDecorativeShape extends StatelessWidget {
  const _CardDecorativeShape();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -42.w,
      top: -76.h,
      child: Container(
        width: 180.w,
        height: 150.h,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(100.r),
        ),
      ),
    );
  }
}

class _DecorativeIcon extends StatelessWidget {
  final IconData icon;

  const _DecorativeIcon({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: 68.r,
      color: Colors.white.withValues(alpha: 0.16),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 80.h),
      child: Column(
        children: [
          SizedBox(
            width: 28.r,
            height: 28.r,
            child: const CircularProgressIndicator(
              strokeWidth: 2.4,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Loading calendar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;

  const _ErrorState({
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12.w,
        54.h,
        12.w,
        54.h,
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: AppColors.textTertiary,
            size: 38.r,
          ),
          SizedBox(height: 15.h),
          Text(
            'Calendar unavailable',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            _friendlyErrorMessage(error),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyErrorMessage(Object error) {
    if (error is AcademicCalendarRepositoryException) {
      return error.message;
    }

    if (error is FormatException) {
      return 'The academic calendar contains invalid or incomplete data.';
    }

    return 'We could not load the saved academic calendar right now.';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12.w,
        54.h,
        12.w,
        54.h,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            color: AppColors.textTertiary,
            size: 38.r,
          ),
          SizedBox(height: 15.h),
          Text(
            'No upcoming events',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            'There are no remaining events in the academic calendar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

void _showEventDetails(
    BuildContext context,
    AcademicCalendarEvent event,
    ) {
  final dateFormat = DateFormat('d MMMM yyyy');
  final dateText = event.isSingleDay
      ? dateFormat.format(event.startDate)
      : '${dateFormat.format(event.startDate)} – '
      '${dateFormat.format(event.endDate)}';

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final color = _eventColor(event.type);

      return SafeArea(
        child: Container(
          margin: EdgeInsets.all(12.w),
          padding: EdgeInsets.fromLTRB(
            22.w,
            18.h,
            22.w,
            24.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28.r),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    event.type.label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  dateText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (event.note != null) ...[
                  SizedBox(height: 18.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.textSecondary,
                          size: 20.r,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            event.note!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

Color _eventColor(AcademicCalendarEventType type) {
  switch (type) {
    case AcademicCalendarEventType.academic:
      return const Color(0xFF315DDB);
    case AcademicCalendarEventType.holiday:
      return const Color(0xFFA81E7D);
    case AcademicCalendarEventType.observance:
      return const Color(0xFF0FB956);
    case AcademicCalendarEventType.other:
      return const Color(0xFF69717C);
  }
}

IconData _eventIcon(AcademicCalendarEvent event) {
  final title = event.title.toLowerCase();

  if (title.contains('durga')) {
    return Icons.local_florist_outlined;
  }

  if (title.contains('lakshmi')) {
    return Icons.wb_sunny_outlined;
  }

  if (title.contains('christmas') ||
      title.contains('x-mas') ||
      title.contains('x mas')) {
    return Icons.park_outlined;
  }

  if (title.contains('victory')) {
    return Icons.flag_outlined;
  }

  if (title.contains('result')) {
    return Icons.analytics_outlined;
  }

  if (title.contains('examination') || title.contains('exam')) {
    return Icons.assignment_outlined;
  }

  if (event.type == AcademicCalendarEventType.holiday) {
    return Icons.event_busy_outlined;
  }

  if (event.type == AcademicCalendarEventType.observance) {
    return Icons.flag_outlined;
  }

  return Icons.event_note_outlined;
}

double _dateColumnWidth() => 108.w;
double _columnGap() => 18.w;
double _eventGap() => 12.h;
double _eventCardHeight() => 150.h;

double _timelineItemHeight({
  required bool isLast,
}) {
  return _eventCardHeight() + (isLast ? 0 : _eventGap());
}

String _semanticLabel(AcademicCalendarEvent event) {
  final formatter = DateFormat('d MMMM yyyy');
  final start = formatter.format(event.startDate);
  final end = formatter.format(event.endDate);
  final dateDescription = event.isSingleDay ? start : '$start to $end';
  final noteDescription = event.note == null ? '' : ', ${event.note}';

  return '${event.title}, ${event.type.label}, '
      '$dateDescription$noteDescription';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(
    date.year,
    date.month,
    date.day,
  );
}