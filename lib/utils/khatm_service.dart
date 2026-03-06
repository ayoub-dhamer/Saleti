import 'package:hive/hive.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/quran/khatm_screen.dart';

class KhatmService {
  static const String _yearsBox = 'khatm_years';
  static const String _dailyLogBox = 'khatm_logs';

  KhatmYear? _activeYearCached;

  /// Get current active year
  Future<KhatmYear?> getActiveYear() async {
    final box = await Hive.openBox<KhatmYear>(_yearsBox);

    final active = box.values.firstWhereOrNull((y) => y.isActive);

    _activeYearCached = active;
    return active;
  }

  /// Get history
  Future<List<KhatmYear>> getHistory() async {
    final box = await Hive.openBox<KhatmYear>(_yearsBox);

    final history = box.values.where((y) => !y.isActive).toList();

    history.sort((a, b) => b.year.compareTo(a.year));

    return history;
  }

  /// Start or update a khatm year
  Future<void> startYear(
    int year,
    int targetCompletions, {
    bool startFromYearStart = false,
  }) async {
    final box = await Hive.openBox<KhatmYear>(_yearsBox);

    /// Determine start date
    final startDate = startFromYearStart
        ? DateTime(year, 1, 1)
        : DateTime.now();

    /// Calculate remaining days
    final endOfYear = DateTime(year, 12, 31);

    int remainingDays;

    if (startFromYearStart) {
      final firstDay = DateTime(year, 1, 1);
      remainingDays = endOfYear.difference(firstDay).inDays + 1;
    } else {
      remainingDays = endOfYear.difference(startDate).inDays + 1;
    }

    if (remainingDays <= 0) remainingDays = 1;

    /// Calculate pages per day
    final pagesPerDay = ((604 * targetCompletions) / remainingDays).ceil();

    /// Check if plan already exists
    KhatmYear? existing;

    final matches = box.values.where((y) => y.year == year);

    if (matches.isNotEmpty) {
      existing = matches.first;
    }

    if (existing != null) {
      existing.targetCompletions = targetCompletions;
      existing.pagesPerDay = pagesPerDay;
      existing.startDate = startDate;
      existing.startFromYearStart = startFromYearStart;
      existing.isActive = true;
      existing.endDate = null;

      await existing.save();
      _activeYearCached = existing;
      return;
    }

    /// Deactivate previous active
    final active = await getActiveYear();
    if (active != null) {
      active.isActive = false;
      active.endDate = DateTime.now();
      await active.save();
    }

    /// Create new plan
    final newYear = KhatmYear(
      year: year,
      targetCompletions: targetCompletions,
      pagesPerDay: pagesPerDay,
      startDate: startDate,
      startFromYearStart: startFromYearStart,
    );

    await box.add(newYear);
    _activeYearCached = newYear;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_mushaf_page_khatm', 1);
  }

  /// Log pages read
  Future<void> logPagesRead(int pagesRead) async {
    final active = await getActiveYear();

    if (active == null) return;

    active.pagesReadTotal += pagesRead;

    const totalPages = 604;

    /// completed cycles
    while (active.pagesReadTotal >= totalPages) {
      active.pagesReadTotal -= totalPages;
      active.completedCycles += 1;
    }

    await active.save();

    _activeYearCached = active;

    /// log daily
    final logBox = await Hive.openBox<DailyKhatmLog>(_dailyLogBox);

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    final existingLog = logBox.values.firstWhereOrNull(
      (l) => l.year == active.year && l.date == todayStr,
    );

    if (existingLog != null) {
      existingLog.pagesRead += pagesRead;
      await existingLog.save();
    } else {
      await logBox.add(
        DailyKhatmLog(year: active.year, date: todayStr, pagesRead: pagesRead),
      );
    }
  }

  /// Pages ahead or behind
  Future<int> pagesAheadOrBehind() async {
    final active = await getActiveYear();

    if (active == null) return 0;

    final today = DateTime.now();
    final start = active.startDate;

    final daysElapsed = today.isBefore(start)
        ? 0
        : today.difference(start).inDays + 1;

    final expectedPages = daysElapsed * active.pagesPerDay;

    final actualPages = (active.completedCycles * 604) + active.pagesReadTotal;

    return actualPages - expectedPages.clamp(0, 604 * active.targetCompletions);
  }

  /// Auto close year if needed
  Future<void> rolloverIfNeeded() async {
    final active = await getActiveYear();

    if (active == null) return;

    final now = DateTime.now();

    if (now.year != active.year && !active.startFromYearStart) {
      active.isActive = false;
      active.endDate = now;
      await active.save();
    }
  }

  Future<void> deleteYear(int year) async {
    final yearsBox = await Hive.openBox<KhatmYear>(_yearsBox);
    final logsBox = await Hive.openBox<DailyKhatmLog>(_dailyLogBox);

    final yearEntry = yearsBox.values.firstWhereOrNull((y) => y.year == year);

    if (yearEntry == null) return;

    final wasActive = yearEntry.isActive;

    // Delete the year entry
    await yearEntry.delete();

    // Delete all logs related to that year
    final logsToDelete = logsBox.values
        .where((log) => log.year == year)
        .toList();

    for (final log in logsToDelete) {
      await log.delete();
    }

    // Clear cache if needed
    if (wasActive) {
      _activeYearCached = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_mushaf_page_khatm', 1);
    }
  }
}
