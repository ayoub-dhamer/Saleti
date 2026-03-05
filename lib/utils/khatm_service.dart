import 'package:hive/hive.dart';
import '../features/quran/khatm_screen.dart';

class KhatmService {
  static const String _yearsBox = 'khatm_years';
  static const String _dailyLogBox = 'khatm_daily_logs';

  KhatmYear? _activeYearCached;

  /// Returns the current active KhatmYear, or null if none
  Future<KhatmYear?> getActiveYear() async {
    final box = await Hive.openBox<KhatmYear>(_yearsBox);
    for (var y in box.values) {
      if (y.isActive) {
        _activeYearCached = y; // cache for ahead/behind
        return y;
      }
    }
    return null; // safe null
  }

  /// Returns history of all years except active
  Future<List<KhatmYear>> getHistory() async {
    final box = await Hive.openBox<KhatmYear>(_yearsBox);
    final history = box.values.where((y) => !y.isActive).toList();
    history.sort((a, b) => b.year.compareTo(a.year));
    return history;
  }

  /// Start a new year or update active
  Future<void> startYear(int year, int targetCompletions) async {
    final box = await Hive.openBox<KhatmYear>(_yearsBox);

    // deactivate previous active
    final active = await getActiveYear();
    if (active != null) {
      active.isActive = false;
      active.endDate = DateTime.now();
      await active.save();
    }

    // calculate pagesPerDay
    const totalPages = 604; // Qur’an pages
    final pagesPerDay = (totalPages * targetCompletions / 365).ceil();

    final newYear = KhatmYear(
      year: year,
      targetCompletions: targetCompletions,
      pagesPerDay: pagesPerDay,
      startDate: DateTime.now(),
    );

    await box.add(newYear);
    _activeYearCached = newYear;
  }

  /// Log pages read for the active year
  Future<void> logPagesRead(int pagesRead) async {
    final active = await getActiveYear();
    if (active == null) return;

    active.pagesReadTotal += pagesRead;

    // calculate if a cycle is completed
    const totalPages = 604;
    while (active.pagesReadTotal >= totalPages) {
      active.pagesReadTotal -= totalPages;
      active.completedCycles += 1;
    }

    await active.save();

    // log daily progress
    final logBox = await Hive.openBox<DailyKhatmLog>(_dailyLogBox);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    DailyKhatmLog? existingLog;
    for (var l in logBox.values) {
      if (l.year == active.year && l.date == todayStr) {
        existingLog = l;
        break;
      }
    }

    if (existingLog != null) {
      existingLog.pagesRead += pagesRead;
      await existingLog.save();
    } else {
      await logBox.add(
        DailyKhatmLog(year: active.year, date: todayStr, pagesRead: pagesRead),
      );
    }
  }

  /// Returns number of pages ahead (positive) or behind (negative)
  int pagesAheadOrBehind() {
    final today = DateTime.now();
    final start = _activeYearCached?.startDate;
    if (start == null || _activeYearCached == null) return 0;

    final daysElapsed = today.difference(start).inDays + 1;
    final expected = daysElapsed * _activeYearCached!.pagesPerDay;
    final actual =
        _activeYearCached!.pagesReadTotal +
        _activeYearCached!.completedCycles * 604;

    return actual - expected;
  }

  /// Check if a new year started and rollover if needed
  Future<void> rolloverIfNeeded() async {
    final active = await getActiveYear();
    if (active == null) return;

    final now = DateTime.now();
    if (now.year != active.year) {
      active.isActive = false;
      active.endDate = now;
      await active.save();
    }

    _activeYearCached = active;
  }
}
