import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../providers/db_provider.dart';

class SystemInsightsScreen extends ConsumerStatefulWidget {
  const SystemInsightsScreen({super.key});

  @override
  ConsumerState<SystemInsightsScreen> createState() => _SystemInsightsScreenState();
}

class _SystemInsightsScreenState extends ConsumerState<SystemInsightsScreen> {
  late Future<Map<String, dynamic>> _diagnosticsFuture;

  @override
  void initState() {
    super.initState();
    _refreshDiagnostics();
  }

  void _refreshDiagnostics() {
    setState(() {
      _diagnosticsFuture = _loadDiagnostics();
    });
  }

  Future<Map<String, dynamic>> _loadDiagnostics() async {
    final db = ref.read(dbProvider);
    final packageInfo = await PackageInfo.fromPlatform();

    // 1. Fetch App Telemetry
    String lastSync = "Never";
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/last_sync_time.txt');
      if (await file.exists()) {
        final timestampString = await file.readAsString();
        final date = DateTime.tryParse(timestampString);
        if (date != null) {
          lastSync = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
        }
      }
    } catch (_) {}

    // 2. Fetch SQLite Row Counts efficiently using raw COUNT queries
    Future<int> getCount(String table) async {
      try {
        final result = await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle();
        return result.read<int>('c');
      } catch (_) {
        return 0;
      }
    }

    return {
      "version": "${packageInfo.version}+${packageInfo.buildNumber}",
      "lastSync": lastSync,
      "users": await getCount('users'),
      "routines": await getCount('routines'),
      "examRoutines": await getCount('exam_routines'),
      "announcements": await getCount('announcements'),
      "books": await getCount('books'),
      "notes": await getCount('notes'),
      "attendance": await getCount('attendance_records'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("System Insights", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.lightImpact();
              _refreshDiagnostics();
            },
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _diagnosticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Failed to load diagnostics.", style: TextStyle(color: Colors.redAccent, fontSize: 16.sp)));
          }

          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.all(24.w),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSectionHeader("App Telemetry"),
              _buildInsightCard([
                _buildDataRow("Build Version", data["version"].toString(), Icons.build_circle_outlined),
                _buildDataRow("Last Sync", data["lastSync"].toString(), Icons.sync_outlined),
              ]),
              SizedBox(height: 32.h),
              _buildSectionHeader("Local SQLite Cache (Drift)"),
              _buildInsightCard([
                _buildDataRow("Active Users", data["users"].toString(), Icons.people_outline),
                _buildDataRow("Routines", data["routines"].toString(), Icons.calendar_today_outlined),
                _buildDataRow("Exam Routines", data["examRoutines"].toString(), Icons.assignment_outlined),
                _buildDataRow("Announcements", data["announcements"].toString(), Icons.campaign_outlined),
                _buildDataRow("Books Cached", data["books"].toString(), Icons.menu_book_outlined),
                _buildDataRow("Notes Cached", data["notes"].toString(), Icons.picture_as_pdf_outlined),
                _buildDataRow("Attendance Records", data["attendance"].toString(), Icons.fact_check_outlined),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Text(title, style: TextStyle(color: Colors.white70, fontSize: 14.sp, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildInsightCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDataRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1877F2), size: 22.sp),
          SizedBox(width: 16.w),
          Text(label, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: TextStyle(color: Colors.white70, fontSize: 16.sp, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}