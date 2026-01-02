class PrayerSettings {
  final bool reminderEnabled;
  final int reminderMinutes;
  final bool adhanEnabled;

  PrayerSettings({
    required this.reminderEnabled,
    required this.reminderMinutes,
    required this.adhanEnabled,
  });

  factory PrayerSettings.defaults() {
    return PrayerSettings(
      reminderEnabled: true,
      reminderMinutes: 10,
      adhanEnabled: true,
    );
  }

  Map<String, dynamic> toMap() => {
    'reminderEnabled': reminderEnabled,
    'reminderMinutes': reminderMinutes,
    'adhanEnabled': adhanEnabled,
  };

  factory PrayerSettings.fromMap(Map<String, dynamic> map) {
    return PrayerSettings(
      reminderEnabled: map['reminderEnabled'],
      reminderMinutes: map['reminderMinutes'],
      adhanEnabled: map['adhanEnabled'],
    );
  }
}
