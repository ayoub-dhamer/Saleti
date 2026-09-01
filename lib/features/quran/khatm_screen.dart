import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../utils/khatm_service.dart';
import 'mushaf_page_screen.dart';
import 'package:saleti/utils/hold_to_delete_button.dart';
part 'khatm_screen.g.dart';

/// =======================
/// ENUMS
/// =======================

enum KhatmStatus { ahead, onTrack, behind }

enum ReadingMode { free, khatm, pointer, goal }

/// =======================
/// MODELS
/// =======================

@HiveType(typeId: 20)
class KhatmYear extends HiveObject {
  @HiveField(0)
  int year;

  @HiveField(1)
  int targetCompletions;

  @HiveField(2)
  int pagesPerDay;

  @HiveField(3)
  int pagesReadTotal;

  @HiveField(4)
  int completedCycles;

  @HiveField(5)
  bool isActive;

  @HiveField(6)
  DateTime startDate;

  @HiveField(7)
  DateTime? endDate;

  @HiveField(8)
  bool startFromYearStart;

  KhatmYear({
    required this.year,
    required this.targetCompletions,
    required this.pagesPerDay,
    required this.startDate,
    this.pagesReadTotal = 0,
    this.completedCycles = 0,
    this.isActive = true,
    this.endDate,
    this.startFromYearStart = false,
  });

  DateTime get planEndDate => startFromYearStart
      ? DateTime(year, 12, 31)
      : DateTime(startDate.year + 1, startDate.month, startDate.day);
}

@HiveType(typeId: 21)
class DailyKhatmLog extends HiveObject {
  @HiveField(0)
  int year;

  @HiveField(1)
  String date;

  @HiveField(2)
  int pagesRead;

  DailyKhatmLog({
    required this.year,
    required this.date,
    required this.pagesRead,
  });
}

/// =======================
/// SCREEN
/// =======================

const Color primaryGreen = Color(0xFF1FA45B);
const Color secondaryGreen = Color(0xFF4FC3A1);

class KhatmScreen extends StatefulWidget {
  const KhatmScreen({super.key});

  @override
  State<KhatmScreen> createState() => _KhatmScreenState();
}

class _KhatmScreenState extends State<KhatmScreen> {
  final KhatmService _service = KhatmService();

  final Set<int> _expandedYears = {};

  KhatmYear? _activeYear;
  List<KhatmYear> _history = [];

  int cyclePages = 604;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _service.rolloverIfNeeded();
    final active = await _service.getActiveYear();
    final history = await _service.getHistory();
    setState(() {
      _activeYear = active;
      _history = history;
    });
  }

  Future<void> _confirmDeleteYear(int year) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: const Text('Delete Record'),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to delete the khatm record for $year?\n\n'
                'This will permanently delete the plan and all reading logs for that year.',
              ),
              const SizedBox(height: 8),
              const Text(
                "Hold to delete",
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],
          ),

          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            HoldToDeleteButton(onConfirmed: () => Navigator.pop(context, true)),
          ],
        );
      },
    );

    if (confirm == true) {
      await _service.deleteYear(year);
      await _load();
    }
  }

  Future<void> _confirmAddCycle() async {
    final active = _activeYear;
    if (active == null) return;

    final totalCycles = active.targetCompletions;
    final currentCycles = active.completedCycles;
    final isLastCycle = currentCycles + 1 >= totalCycles;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm Cycle Completion'),
        content: Text(
          isLastCycle
              ? 'This will finish the FINAL cycle and complete the year. Continue?'
              : 'This will move you to the next cycle while keeping your current page. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _addCycleToActiveYear();
  }

  Future<void> _addCycleToActiveYear() async {
    final active = _activeYear;
    if (active == null) return;

    final int currentCycle = active.completedCycles;
    final int totalCycles = active.targetCompletions;
    final bool isLastCycle = currentCycle + 1 >= totalCycles;

    if (!isLastCycle) {
      active.completedCycles += 1;
    } else {
      active.pagesReadTotal = 0;
      active.completedCycles = totalCycles;
      active.isActive = false;
      active.endDate = DateTime.now();
    }

    await active.save();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Qur\'an Khatm',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, secondaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _activeYear != null ? _activeYearCard() : _noPlanCard(),
                const SizedBox(height: 20),
                _historySection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeYearCard() {
    if (_activeYear == null) return const SizedBox();

    final totalTargetPages = _activeYear!.targetCompletions * cyclePages;
    final pagesReadInYear =
        (_activeYear!.completedCycles * cyclePages) +
        _activeYear!.pagesReadTotal;
    final pagesInCurrentCycle = _activeYear!.pagesReadTotal.toDouble();
    final remainingPages = totalTargetPages - pagesReadInYear;

    final now = DateTime.now();
    final endDate = _activeYear!.planEndDate;
    final daysRemaining = endDate.difference(now).inDays.clamp(1, 9999);
    final catchUpPagesPerDay = (remainingPages / daysRemaining).ceil();

    return FutureBuilder<int>(
      future: _service.pagesAheadOrBehind(),
      builder: (context, snapshot) {
        int diff = snapshot.data ?? 0;
        KhatmStatus status;
        if (diff == 0) {
          status = KhatmStatus.onTrack;
        } else if (diff > 0) {
          status = KhatmStatus.ahead;
        } else {
          status = KhatmStatus.behind;
        }

        Color statusColor;
        String statusLabel;
        switch (status) {
          case KhatmStatus.ahead:
            statusColor = primaryGreen;
            statusLabel = 'Ahead by $diff pages';

            break;
          case KhatmStatus.behind:
            statusColor = Colors.red.shade600;
            statusLabel = 'Behind by ${diff.abs()} pages';

            break;
          case KhatmStatus.onTrack:
            statusColor = Colors.indigo.shade600;
            statusLabel = 'On track';
        }

        final currentCycleProgress = (pagesInCurrentCycle / cyclePages).clamp(
          0.0,
          1.0,
        );
        final yearProgress = (pagesReadInYear / totalTargetPages).clamp(
          0.0,
          1.0,
        );
        final isFinished = pagesReadInYear >= totalTargetPages;

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [primaryGreen, secondaryGreen],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_activeYear!.year}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_activeYear!.targetCompletions}× target · ${_activeYear!.pagesPerDay} pages/day',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _TapScale(
                    onTap: () => _confirmDeleteYear(_activeYear!.year),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Status pill
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Container(
                  key: ValueKey(statusLabel),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (status == KhatmStatus.behind) ...[
                const SizedBox(height: 8),
                Text(
                  'Catch-up pace: $catchUpPagesPerDay pages/day',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _statChip(
                      'Cycles',
                      '${_activeYear!.completedCycles}/${_activeYear!.targetCompletions}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statChip(
                      'Started',
                      DateFormat(
                        'MMM d',
                      ).format(_activeYear!.startDate), // Output: "Jan 15"
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Cycle',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildProgressBar(
                          currentCycleProgress,
                          statusColor,
                          pagesInCurrentCycle.toInt(),
                          cyclePages,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Year Progress',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildProgressBar(
                          yearProgress,
                          statusColor,
                          pagesReadInYear,
                          totalTargetPages,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(
                        isFinished ? Icons.check_circle : Icons.menu_book,
                        size: 18,
                      ),
                      label: Text(
                        isFinished ? 'Year Complete' : 'Continue Reading',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isFinished ? null : _startReading,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _TapScale(
                    onTap: _confirmAddCycle,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.add, color: primaryGreen),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    double progress,
    Color color,
    int pages,
    int totalPages,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            final textColor = value < 0.3 ? Colors.black87 : Colors.white;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade200,
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 16,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text(
                  "${(value * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          '$pages / $totalPages pages',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _noPlanCard() {
    final now = DateTime.now().year;

    final hasCurrentYearPlan =
        (_activeYear != null && _activeYear!.year == now) ||
        _history.any((y) => y.year == now);

    bool currentYearFinished = false;
    if (_activeYear != null && _activeYear!.year == now) {
      final totalPagesInYear = _activeYear!.targetCompletions * cyclePages;
      final pagesReadInYear =
          (_activeYear!.completedCycles * cyclePages) +
          _activeYear!.pagesReadTotal;
      currentYearFinished = pagesReadInYear >= totalPagesInYear;
    }

    final canCreatePlan = !hasCurrentYearPlan || currentYearFinished;

    return _card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.track_changes_rounded,
              size: 44,
              color: primaryGreen.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No active Khatm plan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            canCreatePlan
                ? 'Create a yearly plan to track your Qur\'an reading.'
                : 'You already have a Khatm record for $now. Finish or delete it to start a new one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Tooltip(
              message: canCreatePlan
                  ? 'Create a new plan'
                  : 'Finish or delete the current year record first.',
              child: ElevatedButton.icon(
                onPressed: canCreatePlan ? _configurePlan : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historySection() {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(
                Icons.history_rounded,
                size: 36,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 8),
              Text(
                'No previous years yet',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ..._history.asMap().entries.map((entry) {
          final index = entry.key;
          final y = entry.value;
          final expanded = _expandedYears.contains(y.year);

          final pagesReadInYear =
              (y.completedCycles * cyclePages) + y.pagesReadTotal;
          final totalTargetPages = y.targetCompletions * cyclePages;
          final yearProgress = (pagesReadInYear / totalTargetPages)
              .clamp(0, 1)
              .toDouble();
          final completed = pagesReadInYear >= totalTargetPages;

          return TweenAnimationBuilder<double>(
            key: ValueKey('history_${y.year}'),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + (index.clamp(0, 6) * 40)),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 14),
                child: child,
              ),
            ),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  expanded
                      ? _expandedYears.remove(y.year)
                      : _expandedYears.add(y.year);
                });
              },
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: completed
                                    ? primaryGreen.withOpacity(0.1)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                completed
                                    ? Icons.emoji_events_rounded
                                    : Icons.menu_book_rounded,
                                size: 18,
                                color: completed
                                    ? primaryGreen
                                    : Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              y.year.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            AnimatedRotation(
                              turns: expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.expand_more,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _TapScale(
                              onTap: () => _confirmDeleteYear(y.year),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: expanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _row(
                                    'Target Khatms',
                                    y.targetCompletions.toString(),
                                  ),
                                  _row('Pages / Day', y.pagesPerDay.toString()),
                                  _row(
                                    'Completed Cycles',
                                    y.completedCycles.toString(),
                                  ),
                                  _row(
                                    'Pages Read',
                                    y.pagesReadTotal.toString(),
                                  ),
                                  _row(
                                    'Start Date',
                                    '${y.startDate.year}-${y.startDate.month}-${y.startDate.day}',
                                  ),
                                  if (y.endDate != null)
                                    _row(
                                      'End Date',
                                      '${y.endDate!.year}-${y.endDate!.month}-${y.endDate!.day}',
                                    ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Year Progress',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildProgressBar(
                                    yearProgress,
                                    Colors.indigo.shade600,
                                    pagesReadInYear,
                                    totalTargetPages,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _startReading() async {
    final refreshNeeded = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafPageScreen(
          storageKey: 'last_read_khatm',
          readingMode: ReadingMode.khatm,
        ),
      ),
    );

    if (refreshNeeded == true) {
      _load();
    }
  }

  Future<void> _configurePlan() async {
    final activeYear = _activeYear;

    if (activeYear != null) {
      final totalPages = activeYear.targetCompletions * 604;
      final pagesDone =
          (activeYear.completedCycles * 604) + activeYear.pagesReadTotal;

      if (pagesDone < totalPages) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text("Active Plan Exists"),
            content: Text(
              "You already have an active Khatm plan for ${activeYear.year}. You must complete this plan before starting a new one.",
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return;
      }
    }

    final result = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Khatm Plan',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Transform.scale(
          scale: 0.9 + (0.1 * curved.value.clamp(0.0, 1.0)),
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: _KhatmPlanDialog(
              initialCycles: activeYear?.targetCompletions.toString() ?? '',
            ),
          ),
        );
      },
    );

    if (result != null) {
      final cycles = result["cycles"];
      final startFromYearStart = result["startFromYearStart"];

      if (cycles != null && cycles > 0) {
        await _service.startYear(
          DateTime.now().year,
          cycles,
          startFromYearStart: startFromYearStart,
        );
        await _load();
      }
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Small reusable scale-on-tap wrapper.
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.9),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

/// Restyled Khatm plan creation/edit dialog.
class _KhatmPlanDialog extends StatefulWidget {
  final String initialCycles;

  const _KhatmPlanDialog({required this.initialCycles});

  @override
  State<_KhatmPlanDialog> createState() => _KhatmPlanDialogState();
}

class _KhatmPlanDialogState extends State<_KhatmPlanDialog> {
  late final TextEditingController _controller;
  bool _startFromYearStart = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCycles);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      int.tryParse(_controller.text.trim()) != null &&
      int.parse(_controller.text.trim()) > 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryGreen, secondaryGreen],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.track_changes_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Khatm Plan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Completions per year',
                      hintText: 'e.g. 1, 2, 3...',
                      filled: true,
                      fillColor: const Color(0xFFF4F6F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.repeat_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Start counting from',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _optionTile('January 1st', true)),
                      const SizedBox(width: 10),
                      Expanded(child: _optionTile('Today', false)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _canSubmit ? 1 : 0.5,
                      child: ElevatedButton(
                        onPressed: _canSubmit
                            ? () => Navigator.pop(context, {
                                "cycles": int.parse(_controller.text.trim()),
                                "startFromYearStart": _startFromYearStart,
                              })
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(String label, bool value) {
    final selected = _startFromYearStart == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _startFromYearStart = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? primaryGreen.withOpacity(0.1)
              : const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? primaryGreen : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: selected ? primaryGreen : Colors.grey.shade400,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? primaryGreen : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// SMALL UI WIDGETS
/// =======================

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryGreen, secondaryGreen]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Khatm Journey',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Track and complete the Qur\'an with a yearly plan',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
