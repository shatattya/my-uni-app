import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../data/repositories/live_event_repository.dart';
import '../../theme/app_theme.dart';

/// Provides the dynamic title displayed in the event screen AppBar.
///
/// The repository supplies the configured title and falls back to
/// "Campus Events" when no title has been configured.
final liveEventTitleProvider =
FutureProvider.autoDispose<String>((ref) {
  return ref
      .watch(liveEventRepositoryProvider)
      .getEventTitle();
});

/// Provides a real-time, searchable stream of events from the local
/// SQLite/Drift database.
final liveEventsProvider =
StreamProvider.autoDispose.family<
    List<LiveEvent>,
    String>((ref, query) {
  return ref
      .watch(liveEventRepositoryProvider)
      .watchEvents(
    query: query,
  );
});

class LiveEventsScreen extends ConsumerStatefulWidget {
  const LiveEventsScreen({
    super.key,
  });

  @override
  ConsumerState<LiveEventsScreen> createState() =>
      _LiveEventsScreenState();
}

class _LiveEventsScreenState
    extends ConsumerState<LiveEventsScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleAsync =
    ref.watch(liveEventTitleProvider);

    final eventsAsync = ref.watch(
      liveEventsProvider(_searchQuery),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
        ),
        title: titleAsync.when(
          data: (title) => Text(
            title.isEmpty ? 'Campus Events' : title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          loading: () => const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textSecondary,
            ),
          ),
          error: (_, _) => Text(
            'Campus Events',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            SizedBox(height: 10.h),
            Expanded(
              child: eventsAsync.when(
                data: _buildEventsList,
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
                error: (_, _) => _buildErrorState(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20.w,
        vertical: 10.h,
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: AppColors.textPrimary,
        ),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search events, venues, or topics...',
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textTertiary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(
              Icons.clear,
              color: AppColors.textTertiary,
            ),
            tooltip: 'Clear search',
            onPressed: () {
              _searchController.clear();

              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(16.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(16.r),
            borderSide: const BorderSide(
              color: AppColors.primary,
            ),
          ),
          contentPadding:
          EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim();
          });
        },
      ),
    );
  }

  Widget _buildEventsList(
      List<LiveEvent> events,
      ) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 32.w,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_busy_outlined,
                color: AppColors.textTertiary,
                size: 52.sp,
              ),
              SizedBox(height: 14.h),
              Text(
                _searchQuery.isEmpty
                    ? 'No events scheduled.'
                    : 'No events found.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16.sp,
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text(
                  'Try a different search term.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: 20.w,
        vertical: 10.h,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        return _buildEventCard(
          events[index],
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32.w,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48.sp,
            ),
            SizedBox(height: 12.h),
            Text(
              'Failed to load events.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Please try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(
      LiveEvent event,
      ) {
    final localTime = DateTime.tryParse(
      event.utcTime,
    )?.toLocal();

    final dateString = localTime != null
        ? DateFormat(
      'EEE, MMM d, yyyy',
    ).format(localTime)
        : 'Date unavailable';

    final timeString = localTime != null
        ? DateFormat(
      'hh:mm a',
    ).format(localTime)
        : 'Time unavailable';

    final primaryTitle =
    event.titlePrimary.trim();

    final secondaryTitle =
    event.titleSecondary.trim();

    final groupText =
    event.groupLabel.trim();

    final headingText =
    event.heading.trim();

    final subtitleText =
    event.subtitle.trim();

    final hasGroup =
        groupText.isNotEmpty;

    final hasHeading =
        headingText.isNotEmpty;

    final hasSecondary =
        secondaryTitle.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(
        bottom: 16.h,
      ),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
        BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.divider,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          if (hasGroup || hasHeading)
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    hasGroup
                        ? groupText
                        : headingText,
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                      const Color(0xFF00E5FF),
                      fontSize: 14.sp,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          if (hasGroup || hasHeading)
            SizedBox(height: 14.h),
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withValues(
                    alpha: 0.15,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    12.r,
                  ),
                ),
                child: Icon(
                  Icons.event_outlined,
                  color:
                  const Color(0xFF7C8BFF),
                  size: 24.sp,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    if (primaryTitle.isNotEmpty)
                      Text(
                        primaryTitle,
                        style: TextStyle(
                          color:
                          AppColors.textPrimary,
                          fontSize: 19.sp,
                          fontWeight:
                          FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    if (hasSecondary) ...[
                      SizedBox(height: 8.h),
                      Text(
                        secondaryTitle,
                        style: TextStyle(
                          color:
                          AppColors.textSecondary,
                          fontSize: 16.sp,
                          fontWeight:
                          FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Container(
            padding:
            EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 10.h,
            ),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface,
              borderRadius:
              BorderRadius.circular(
                12.r,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  color:
                  AppColors.textSecondary,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '$dateString  •  $timeString',
                    style: TextStyle(
                      color:
                      AppColors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight:
                      FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (subtitleText.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color:
                  AppColors.textTertiary,
                  size: 17.sp,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    subtitleText,
                    style: TextStyle(
                      color:
                      AppColors.textTertiary,
                      fontSize: 14.sp,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}