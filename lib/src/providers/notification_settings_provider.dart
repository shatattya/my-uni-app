import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final notificationSettingsProvider = AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(() {
  return NotificationSettingsNotifier();
});

class NotificationSettings {
  final bool isRoutineAlarmEnabled;
  final int alarmLeadTimeMinutes;

  NotificationSettings({
    required this.isRoutineAlarmEnabled,
    required this.alarmLeadTimeMinutes,
  });

  NotificationSettings copyWith({
    bool? isRoutineAlarmEnabled,
    int? alarmLeadTimeMinutes,
  }) {
    return NotificationSettings(
      isRoutineAlarmEnabled: isRoutineAlarmEnabled ?? this.isRoutineAlarmEnabled,
      alarmLeadTimeMinutes: alarmLeadTimeMinutes ?? this.alarmLeadTimeMinutes,
    );
  }
}

class NotificationSettingsNotifier extends AsyncNotifier<NotificationSettings> {
  static const _enabledKey = 'routine_alarms_enabled';
  static const _leadTimeKey = 'routine_alarms_lead_time';

  @override
  Future<NotificationSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettings(
      isRoutineAlarmEnabled: prefs.getBool(_enabledKey) ?? false,
      alarmLeadTimeMinutes: prefs.getInt(_leadTimeKey) ?? 15, // Default 15 minutes
    );
  }

  Future<void> updateSettings(bool enabled, int leadTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    await prefs.setInt(_leadTimeKey, leadTime);
    state = AsyncData(NotificationSettings(
      isRoutineAlarmEnabled: enabled,
      alarmLeadTimeMinutes: leadTime,
    ));
  }
}