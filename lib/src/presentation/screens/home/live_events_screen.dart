import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_database.dart';
import '../../../data/repositories/live_event_repository.dart';

// Provides the dynamic title for the App Bar (e.g., "FIFA World Cup 2026")
final liveEventTitleProvider = FutureProvider.autoDispose<String>((ref) {
  return ref.watch(liveEventRepositoryProvider).getEventTitle();
});

// Provides a real-time, searchable stream of events directly from the local SQLite database
final liveEventsProvider = StreamProvider.autoDispose.family<List<LiveEvent>, String>((ref, query) {
  return ref.watch(liveEventRepositoryProvider).watchEvents(query: query);
});

class LiveEventsScreen extends ConsumerStatefulWidget {
  const LiveEventsScreen({super.key});

  @override
  ConsumerState<LiveEventsScreen> createState() => _LiveEventsScreenState();
}

class _LiveEventsScreenState extends ConsumerState<LiveEventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Maps Unicode Emoji Flags to Team Names
  String _getFlag(String teamName) {
    const flags = {
      "Mexico": "🇲🇽", "United States": "🇺🇸", "Argentina": "🇦🇷", "Brazil": "🇧🇷",
      "Canada": "🇨🇦", "Switzerland": "🇨🇭", "Australia": "🇦🇺", "South Korea": "🇰🇷",
      "Egypt": "🇪🇬", "Nigeria": "🇳🇬", "France": "🇫🇷", "Japan": "🇯🇵",
      "Cameroon": "🇨🇲", "England": "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "Colombia": "🇨🇴", "Spain": "🇪🇸",
      "Uruguay": "🇺🇾", "Germany": "🇩🇪", "Ivory Coast": "🇨🇮", "Portugal": "🇵🇹",
      "Senegal": "🇸🇳", "Netherlands": "🇳🇱", "Ecuador": "🇪🇨", "Belgium": "🇧🇪",
      "Morocco": "🇲🇦", "Wales": "🏴󠁧󠁢󠁷󠁬󠁳󠁿", "South Africa": "🇿🇦", "Czechia": "🇨🇿",
      "Bosnia and Herzegovina": "🇧🇦", "Croatia": "🇭🇷", "Italy": "🇮🇹", "Denmark": "🇩🇰",
      "Sweden": "🇸🇪", "Poland": "🇵🇱", "Serbia": "🇷🇸", "Ghana": "🇬🇭",
      "Tunisia": "🇹🇳", "Algeria": "🇩🇿", "Saudi Arabia": "🇸🇦", "Iran": "🇮🇷",
      "Peru": "🇵🇪", "Chile": "🇨🇱", "Qatar": "🇶🇦", "Costa Rica": "🇨🇷",
      "Panama": "🇵🇦", "Jamaica": "🇯🇲", "New Zealand": "🇳🇿", "Ukraine": "🇺🇦"
    };
    return flags[teamName.trim()] ?? "";
  }

  // Maps teams to their primary national color for gradient blending
  Color? _getTeamColor(String teamName) {
    const colors = {
      "Mexico": Color(0xFF006847), "USA": Color(0xFF002868), "Argentina": Color(0xFF75AADB),
      "Brazil": Color(0xFFFFDF00), "Canada": Color(0xFFFF0000), "Switzerland": Color(0xFFFF0000),
      "Australia": Color(0xFFFFCD00), "South Korea": Color(0xFFCD2E3A), "Egypt": Color(0xFFCE1126),
      "Nigeria": Color(0xFF008751), "France": Color(0xFF002395), "Japan": Color(0xFF000555),
      "Cameroon": Color(0xFF007A5E), "England": Color(0xFFCE1126), "Colombia": Color(0xFFFCD116),
      "Spain": Color(0xFFAA151B), "Uruguay": Color(0xFF55B5E5), "Germany": Color(0xFF888888),
      "Ivory Coast": Color(0xFFF77F00), "Portugal": Color(0xFFFF0000), "Senegal": Color(0xFF00853F),
      "Netherlands": Color(0xFFF36C21), "Ecuador": Color(0xFFFFD100), "Belgium": Color(0xFFE30613),
      "Morocco": Color(0xFFC1272D), "Wales": Color(0xFFD30731), "South Africa": Color(0xFF007749),
      "Czechia": Color(0xFF11457E), "Bosnia and Herzegovina": Color(0xFF002395), "Croatia": Color(0xFFFF0000),
      "Italy": Color(0xFF0066CC), "Denmark": Color(0xFFC60C30), "Sweden": Color(0xFFFECC00),
      "Poland": Color(0xFFDC143C), "Serbia": Color(0xFFC6363C), "Ghana": Color(0xFFCE1126),
      "Tunisia": Color(0xFFE70013), "Algeria": Color(0xFF006233), "Saudi Arabia": Color(0xFF006C35),
      "Iran": Color(0xFF239F40), "Peru": Color(0xFFD91023), "Chile": Color(0xFF0039A6),
      "Qatar": Color(0xFF8A1538), "Costa Rica": Color(0xFFCE1126), "Panama": Color(0xFFC8102E),
      "Jamaica": Color(0xFF009B3A), "New Zealand": Color(0xFFFFFFFF), "Ukraine": Color(0xFFFFD700)
    };
    return colors[teamName.trim()];
  }

  @override
  Widget build(BuildContext context) {
    final titleAsync = ref.watch(liveEventTitleProvider);
    final eventsAsync = ref.watch(liveEventsProvider(_searchQuery));

    return Scaffold(
      // MODIFICATION: Replaced pure black with a cheerful, deep modern Navy Blue
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: titleAsync.when(
          data: (title) => Text(
            title,
            style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w500),
          ),
          loading: () => const SizedBox(),
          error: (_, __) => Text("Live Events", style: TextStyle(color: Colors.white, fontSize: 22.sp)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search teams, venues, or stages...",
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                      : null,
                  filled: true,
                  // Adjusted input field color to match the new bright background
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            SizedBox(height: 10.h),

            // Events List
            Expanded(
              child: eventsAsync.when(
                data: (events) {
                  // Filter out past matches. Matches disappear 105 mins after start time.
                  final now = DateTime.now();
                  final upcomingEvents = events.where((e) {
                    final localTime = DateTime.tryParse(e.utcTime)?.toLocal();
                    if (localTime == null) return true;
                    final matchEndTime = localTime.add(const Duration(minutes: 105));
                    return now.isBefore(matchEndTime);
                  }).toList();

                  if (upcomingEvents.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty ? "No upcoming events scheduled." : "No matches found.",
                        style: TextStyle(color: Colors.white54, fontSize: 16.sp),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                    physics: const BouncingScrollPhysics(),
                    itemCount: upcomingEvents.length,
                    itemBuilder: (context, index) {
                      return _buildEventCard(upcomingEvents[index]);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF5667FD))),
                error: (err, _) => Center(
                  child: Text("Failed to load events.", style: TextStyle(color: Colors.redAccent, fontSize: 16.sp)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(LiveEvent event) {
    final localTime = DateTime.tryParse(event.utcTime)?.toLocal();
    final timeString = localTime != null
        ? DateFormat('EEE, MMM d  •  hh:mm a').format(localTime)
        : 'TBA';

    final bool isVersus = event.titleSecondary.isNotEmpty;

    // Live Match Detection (Standard 105-minute match window)
    final now = DateTime.now();
    bool isLive = false;
    if (localTime != null) {
      final endTime = localTime.add(const Duration(minutes: 105));
      isLive = now.isAfter(localTime) && now.isBefore(endTime);
    }

    // Fetch Flags
    final String flagPrimary = _getFlag(event.titlePrimary);
    final String flagSecondary = _getFlag(event.titleSecondary);

    // Dynamic Immersive Gradients
    final bool isTBD = event.titlePrimary.contains("TBD") ||
        event.titlePrimary.contains("Winner") ||
        event.titlePrimary.contains("Loser");

    final Color rawColor1 = _getTeamColor(event.titlePrimary) ?? const Color(0xFF2A2A30);
    final Color rawColor2 = _getTeamColor(event.titleSecondary) ?? const Color(0xFF1E1E1E);

    // MODIFICATION: Reduced black blending from 82% to 60%.
    // This allows the bright team colors (Red, Yellow, Green) to deeply illuminate the card corners.
    final Color blend1 = Color.lerp(rawColor1, Colors.black, 0.60) ?? const Color(0xFF2A2A30);
    final Color blend2 = Color.lerp(rawColor2, Colors.black, 0.60) ?? const Color(0xFF1E1E1E);

    final bool applyGradient = isVersus && !isTBD;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: applyGradient ? [blend1, blend2] : const [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isLive ? Colors.greenAccent : Colors.white10,
          width: isLive ? 2 : 1,
        ),
        boxShadow: isLive
            ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.15), blurRadius: 15, spreadRadius: 2)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Group/Heading & Time / Live Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.groupLabel.isNotEmpty || event.heading.isNotEmpty)
                Expanded(
                  child: Text(
                    event.groupLabel.isNotEmpty ? event.groupLabel : event.heading,
                    style: TextStyle(color: const Color(0xFF00E5FF), fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              isLive
                  ? Row(
                children: [
                  Container(
                    width: 8.w,
                    height: 8.h,
                    decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    "LIVE",
                    style: TextStyle(color: Colors.greenAccent, fontSize: 13.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              )
                  : Text(
                timeString,
                style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Middle Row: Dynamic Titles with Native Flags
          if (isVersus)
            Row(
              // Ensures the VS stays perfectly vertically centered even if one side wraps
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    "${event.titlePrimary} $flagPrimary".trim(),
                    textAlign: TextAlign.right,
                    // MODIFICATION: Removed line limits/ellipsis. Allow text to wrap cleanly.
                    style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    "VS",
                    style: TextStyle(color: const Color(0xFF5667FD), fontSize: 16.sp, fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(
                  child: Text(
                    "$flagSecondary ${event.titleSecondary}".trim(),
                    textAlign: TextAlign.left,
                    // MODIFICATION: Removed line limits/ellipsis. Allow text to wrap cleanly.
                    style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold, height: 1.2),
                  ),
                ),
              ],
            )
          else
            Text(
              "${event.titlePrimary} $flagPrimary".trim(),
              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold, height: 1.2),
            ),

          SizedBox(height: 16.h),

          // Bottom Row: Venue / Subtitle
          if (event.subtitle.isNotEmpty)
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: Colors.white54, size: 16.sp),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    event.subtitle,
                    style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}