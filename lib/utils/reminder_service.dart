import 'dart:convert';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReminderFrequency { once, daily, weekly, monthly }

enum ReminderCategory {
  extraPrayer('Extra prayer', Icons.self_improvement_rounded),
  quran('Qur\'an', Icons.menu_book_rounded),
  dhikr('Dhikr', Icons.spa_rounded),
  fasting('Fasting', Icons.no_food_rounded),
  charity('Charity', Icons.volunteer_activism_rounded),
  other('Other', Icons.notifications_rounded);

  final String label;
  final IconData icon;
  const ReminderCategory(this.label, this.icon);
}

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class Reminder {
  final String id;
  final int notifId;
  String title;
  String body;
  ReminderCategory category;
  ReminderFrequency frequency;
  DateTime start; // first occurrence; also fixes the weekday / day of month
  bool enabled;

  Reminder({
    required this.id,
    required this.notifId,
    required this.title,
    this.body = '',
    this.category = ReminderCategory.other,
    this.frequency = ReminderFrequency.once,
    required this.start,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'notifId': notifId,
    'title': title,
    'body': body,
    'category': category.name,
    'frequency': frequency.name,
    'start': start.toIso8601String(),
    'enabled': enabled,
  };

  static Reminder? tryFromJson(String raw) {
    try {
      final m = jsonDecode(raw) as Map;
      return Reminder(
        id: m['id'] as String,
        notifId: m['notifId'] as int,
        title: m['title'] as String,
        body: (m['body'] as String?) ?? '',
        category: ReminderCategory.values.firstWhere(
          (c) => c.name == m['category'],
          orElse: () => ReminderCategory.other,
        ),
        frequency: ReminderFrequency.values.firstWhere(
          (f) => f.name == m['frequency'],
          orElse: () => ReminderFrequency.once,
        ),
        start: DateTime.parse(m['start'] as String),
        enabled: (m['enabled'] as bool?) ?? true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Next time this reminder fires after [from], or null if it never will.
  DateTime? nextOccurrence([DateTime? from]) {
    final now = from ?? DateTime.now();
    if (start.isAfter(now)) return start;

    switch (frequency) {
      case ReminderFrequency.once:
        return null;
      case ReminderFrequency.daily:
        for (var i = 0; i < 2; i++) {
          final d = now.add(Duration(days: i));
          final c = DateTime(d.year, d.month, d.day, start.hour, start.minute);
          if (c.isAfter(now)) return c;
        }
        return null;
      case ReminderFrequency.weekly:
        for (var i = 0; i < 8; i++) {
          final d = now.add(Duration(days: i));
          final c = DateTime(d.year, d.month, d.day, start.hour, start.minute);
          if (c.weekday == start.weekday && c.isAfter(now)) return c;
        }
        return null;
      case ReminderFrequency.monthly:
        // Months without that day (29th-31st) are skipped, which matches
        // how the notification plugin repeats them.
        for (var i = 0; i < 30; i++) {
          final m = DateTime(now.year, now.month + i, 1);
          if (start.day > DateUtils.getDaysInMonth(m.year, m.month)) continue;
          final c = DateTime(
            m.year,
            m.month,
            start.day,
            start.hour,
            start.minute,
          );
          if (c.isAfter(now)) return c;
        }
        return null;
    }
  }

  bool get isPassed =>
      frequency == ReminderFrequency.once && !start.isAfter(DateTime.now());

  String get summary => scheduleSummary(frequency, start);

  static String scheduleSummary(ReminderFrequency f, DateTime d) {
    switch (f) {
      case ReminderFrequency.once:
        return 'Once on ${_months[d.month - 1]} ${d.day}, ${d.year} at ${_hm(d)}';
      case ReminderFrequency.daily:
        return 'Every day at ${_hm(d)}';
      case ReminderFrequency.weekly:
        return 'Every ${_weekdays[d.weekday - 1]} at ${_hm(d)}';
      case ReminderFrequency.monthly:
        return 'Monthly on the ${_ordinal(d.day)} at ${_hm(d)}';
    }
  }
}

class ReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _storageKey = 'custom_reminders_v1';
  static const String _idCounterKey = 'custom_reminders_next_id';
  static const int _firstNotifId = 700000; // clear of your other alarm ids

  static Future<List<Reminder>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    return raw.map(Reminder.tryFromJson).whereType<Reminder>().toList();
  }

  static Future<void> save(List<Reminder> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      list.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  static Future<int> newNotifId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_idCounterKey) ?? _firstNotifId;
    await prefs.setInt(_idCounterKey, id + 1);
    return id;
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Registers the next occurrence only. After it fires, [reminderAlarmCallback]
  /// registers the one after that, so repeating reminders keep going.
  static Future<void> schedule(Reminder r) async {
    await AndroidAlarmManager.cancel(r.notifId);
    if (!r.enabled) return;
    final next = r.nextOccurrence();
    if (next == null) return;

    try {
      await AndroidAlarmManager.oneShotAt(
        next,
        r.notifId,
        reminderAlarmCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
      );
    } catch (e) {
      debugPrint('Failed to schedule reminder ${r.notifId}: $e');
    }
  }

  static Future<void> cancel(Reminder r) async {
    await AndroidAlarmManager.cancel(r.notifId);
    await _plugin.cancel(r.notifId);
  }

  /// Call at startup and after anything that could have dropped alarms.
  static Future<void> rescheduleAll() async {
    for (final r in await load()) {
      await schedule(r);
    }
  }
}

@pragma('vm:entry-point')
Future<void> reminderAlarmCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  final reminders = await ReminderService.load();
  final r = reminders.where((x) => x.notifId == id).firstOrNull;
  if (r == null || !r.enabled) return; // deleted or switched off meanwhile

  final notifications = FlutterLocalNotificationsPlugin();
  try {
    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );
    final body = r.body.trim();
    await notifications.show(
      id,
      r.title,
      body.isEmpty ? null : body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'custom_reminders',
          'Reminders',
          channelDescription: 'Your own scheduled reminders',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: body.isEmpty ? null : BigTextStyleInformation(body),
        ),
      ),
    );
  } catch (e) {
    debugPrint('Failed to show reminder $id: $e');
  }

  // Chain the next occurrence for repeating reminders.
  await ReminderService.schedule(r);
}
