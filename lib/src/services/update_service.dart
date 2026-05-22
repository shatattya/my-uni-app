import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final updateServiceProvider = Provider((ref) => UpdateService());

class AppUpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  AppUpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  // UX ENHANCEMENT: Added strict timeouts to prevent infinite UI hangs on slow networks
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  // Connects directly to your GitHub repository API
  final String _githubApiUrl = "https://api.github.com/repos/shatattya/my-uni-app/releases/latest";

  Future<AppUpdateInfo> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _dio.get(_githubApiUrl);

      if (response.statusCode == 200) {
        final data = response.data;
        final String latestTagName = data['tag_name'];
        final String downloadUrl = data['html_url'];
        final String releaseNotes = data['body'] ?? "Minor bug fixes and performance improvements.";

        final latestVersion = latestTagName.replaceAll('v', '');
        bool hasUpdate = _isVersionGreater(latestVersion, currentVersion);

        return AppUpdateInfo(
          hasUpdate: hasUpdate,
          latestVersion: latestTagName,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
        );
      }
    } catch (e) {
      print("DEBUG: Update check failed: $e");
    }

    return AppUpdateInfo(hasUpdate: false, latestVersion: "", downloadUrl: "", releaseNotes: "");
  }

  bool _isVersionGreater(String latest, String current) {
    try {
      // UX ENHANCEMENT: Sanitize version strings to prevent crashes if tags contain suffixes like "-beta"
      String cleanLatest = latest.split('-').first.split('+').first;
      String cleanCurrent = current.split('-').first.split('+').first;

      List<int> v1 = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> v2 = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < v1.length; i++) {
        if (i >= v2.length) return true;
        if (v1[i] > v2[i]) return true;
        if (v1[i] < v2[i]) return false;
      }
    } catch (e) {
      print("DEBUG: Version parsing failed: $e");
    }
    return false;
  }
}