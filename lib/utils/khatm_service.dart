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
    // CHANGED: use the same end-date rule as KhatmYear.planEndDate
    final endDate = startFromYearStart
        ? DateTime(year, 12, 31)
        : () {
            final targetYear = startDate.year + 1;
            final daysInTargetMonth = DateTime(
              targetYear,
              startDate.month + 1,
              0,
            ).day;
            final day = startDate.day > daysInTargetMonth
                ? daysInTargetMonth
                : startDate.day;
            return DateTime(targetYear, startDate.month, day);
          }();

    int remainingDays = endDate.difference(startDate).inDays + 1;
    if (remainingDays <= 0) remainingDays = 1;

    final pagesPerDay = ((604 * targetCompletions) / remainingDays).ceil();

    KhatmYear? existing = box.values.firstWhereOrNull((y) => y.year == year);

    // FIXED (polish #4): this deactivation used to run only in the
    // brand-new-year path below — the reuse branch just under it
    // (restarting a year that already has a record, e.g. a previous
    // attempt at this same calendar year) activated that record without
    // first deactivating whatever else was currently active, leaving two
    // KhatmYear records simultaneously isActive at once. Moved above the
    // branch so both paths share it. Skipped when the active year is the
    // very record being reused — nothing else to deactivate there, and
    // deactivating-then-immediately-reactivating the same record would
    // just leave a narrow inconsistent window between the two saves.
    final active = await getActiveYear();
    if (active != null && active.year != year) {
      active.isActive = false;
      active.endDate = DateTime.now();
      await active.save();
    }

    if (existing != null) {
      existing
        ..targetCompletions = targetCompletions
        ..pagesPerDay = pagesPerDay
        ..startDate = startDate
        ..startFromYearStart = startFromYearStart
        ..isActive = true
        ..endDate = null
        // FIXED (polish #4): was left untouched, so restarting a year
        // kept whatever pagesReadTotal/completedCycles were recorded
        // under its previous (now-superseded) plan, instead of the same
        // fresh start a brand-new KhatmYear() gets below.
        ..pagesReadTotal = 0
        ..completedCycles = 0;
      await existing.save();
      _activeYearCached = existing;
      return;
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

    // CHANGED: was `now.year > active.year || actualPages >= totalPages`
    if (now.isAfter(active.planEndDate) || actualPages >= totalPages) {
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
