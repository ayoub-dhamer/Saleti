import 'package:hive/hive.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/quran/khatm_screen.dart';

class KhatmService {
  static const String _yearsBox = 'khatm_years';
  static const String _dailyLogBox = 'khatm_logs';

  KhatmYear? _activeYearCached;

  /// ====================
  /// Internal Box Helpers
  /// ====================
  Future<Box<KhatmYear>> get _yearBox async =>
      await Hive.openBox<KhatmYear>(_yearsBox);
  Future<Box<DailyKhatmLog>> get _logBox async =>
      await Hive.openBox<DailyKhatmLog>(_dailyLogBox);

  /// ====================
  /// Repository Methods
  /// ====================

  /// Get current active year
  Future<KhatmYear?> getActiveYear() async {
    if (_activeYearCached != null) return _activeYearCached;

    final box = await _yearBox;
    final active = box.values.firstWhereOrNull((y) => y.isActive);
    _activeYearCached = active;
    return active;
  }

  /// Get history (all non-active years)
  Future<List<KhatmYear>> getHistory() async {
    final box = await _yearBox;
    final history = box.values.where((y) => !y.isActive).toList();
    history.sort((a, b) => b.year.compareTo(a.year));
    return history;
  }

  /// Save or update a year
  Future<void> saveYear(KhatmYear year) async => await year.save();

  /// Add daily log
  Future<void> addDailyLog(DailyKhatmLog log) async {
    final box = await _logBox;
    await box.put('${log.year}-${log.date}', log);
  }

  /// Get daily log for a specific date
  Future<DailyKhatmLog?> getLog(int year, String date) async {
    final box = await _logBox;
    return box.get('$year-$date');
  }

  /// Deactivate all active years
  Future<void> deactivateAll() async {
    final box = await _yearBox;
    for (final y in box.values) {
      if (y.isActive) {
        y.isActive = false;
        y.endDate = DateTime.now();
        await y.save();
      }
    }
    _activeYearCached = null;
  }

  /// ====================
  /// Service Methods
  /// ====================

  /// Start or update a khatm year
  Future<void> startYear(
    int year,
    int targetCompletions, {
    bool startFromYearStart = false,
  }) async {
    final box = await _yearBox;

    final startDate = startFromYearStart
        ? DateTime(year, 1, 1)
        : DateTime.now();
    final endOfYear = DateTime(year, 12, 31);

    int remainingDays = startFromYearStart
        ? endOfYear.difference(DateTime(year, 1, 1)).inDays + 1
        : endOfYear.difference(startDate).inDays + 1;

    if (remainingDays <= 0) remainingDays = 1;

    final pagesPerDay = ((604 * targetCompletions) / remainingDays).ceil();

    KhatmYear? existing = box.values.firstWhereOrNull((y) => y.year == year);

    if (existing != null) {
      existing
        ..targetCompletions = targetCompletions
        ..pagesPerDay = pagesPerDay
        ..startDate = startDate
        ..startFromYearStart = startFromYearStart
        ..isActive = true
        ..endDate = null;
      await existing.save();
      _activeYearCached = existing;
      return;
    }

    final active = await getActiveYear();
    if (active != null) {
      active.isActive = false;
      active.endDate = DateTime.now();
      await active.save();
    }

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
    await prefs.remove('last_read_khatm');
  }

  /// Log pages read
  Future<void> logPagesRead(int pagesRead) async {
    final active = await getActiveYear();
    if (active == null) return;

    const int cyclePages = 604;

    active.pagesReadTotal += pagesRead;

    // Handle cycle completion
    while (active.pagesReadTotal >= cyclePages) {
      active.pagesReadTotal -= cyclePages;
      active.completedCycles += 1;
    }

    // If all cycles are done, mark year as completed
    final totalPagesInYear = active.targetCompletions * cyclePages;
    final pagesSoFar =
        (active.completedCycles * cyclePages) + active.pagesReadTotal;

    if (pagesSoFar >= totalPagesInYear) {
      active.pagesReadTotal = 0; // ✅ IMPORTANT
      active.completedCycles = active.targetCompletions; // safety clamp
      active.isActive = false;
      active.endDate = DateTime.now();
    }

    await active.save();
    _activeYearCached = active;

    // Save daily log
    final logBox = await _logBox;
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
    final daysElapsed = today.isBefore(active.startDate)
        ? 0
        : today.difference(active.startDate).inDays + 1;

    final expectedPages = daysElapsed * active.pagesPerDay;
    final actualPages = (active.completedCycles * 604) + active.pagesReadTotal;

    return actualPages - expectedPages.clamp(0, 604 * active.targetCompletions);
  }

  /// Auto close year if needed
  Future<void> rolloverIfNeeded() async {
    final active = await getActiveYear();
    if (active == null) return;

    final now = DateTime.now();
    final totalPages = 604 * active.targetCompletions;
    final actualPages = (active.completedCycles * 604) + active.pagesReadTotal;

    if (now.year > active.year || actualPages >= totalPages) {
      active.isActive = false;
      active.endDate = now;
      await active.save();
      _activeYearCached = null;
    }
  }

  /// Delete a year and its logs
  Future<void> deleteYear(int year) async {
    final yearsBox = await _yearBox;
    final logsBox = await _logBox;

    final yearEntry = yearsBox.values.firstWhereOrNull((y) => y.year == year);
    if (yearEntry == null) return;

    final wasActive = yearEntry.isActive;

    await yearEntry.delete();

    final logsToDelete = logsBox.values.where((l) => l.year == year).toList();
    for (final log in logsToDelete) {
      await log.delete();
    }

    if (wasActive) {
      _activeYearCached = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_read_khatm');
    }
  }
}
