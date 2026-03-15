import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/khatm_service.dart';
import 'mushaf_page_screen.dart';

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
  bool startFromYearStart; // true = Jan 1, false = today

  KhatmYear({
    required this.year,
    required this.targetCompletions,
    required this.pagesPerDay,
    required this.startDate,
    this.pagesReadTotal = 0,
    this.completedCycles = 0,
    this.isActive = true,
    this.endDate,
    this.startFromYearStart = false, // default false
  });
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

  @override
  void initState() {
    super.initState();

    _initializeKhatm();

    _load();
  }

  Future<void> _initializeKhatm() async {
    // Generate historical years if they don't exist
    await addHistoricalYear(
      year: 2025,
      targetCompletions: 2,
      completedCycles: 1,
      pagesReadTotal: 100,
    );

    await addHistoricalYear(
      year: 2024,
      targetCompletions: 1,
      completedCycles: 1,
      pagesReadTotal: 604,
    );

    // Load curren
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

  Future<void> addHistoricalYear({
    required int year,
    required int targetCompletions,
    required int completedCycles,
    required int pagesReadTotal,
  }) async {
    final box = await Hive.openBox<KhatmYear>('khatm_years');

    // Prevent duplicate year
    if (box.values.any((y) => y.year == year)) return;

    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31);

    final historical = KhatmYear(
      year: year,
      targetCompletions: targetCompletions,
      pagesPerDay: ((604 * targetCompletions) / 365).ceil(),
      pagesReadTotal: pagesReadTotal,
      completedCycles: completedCycles,
      isActive: false, // historical record
      startDate: startDate,
      endDate: endDate,
      startFromYearStart: true,
    );

    await box.add(historical);
  }

  Future<void> _confirmDeleteYear(int year) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text(
          'Are you sure you want to delete the khatm record for $year?\n\n'
          'This will permanently delete the plan and all reading logs for that year.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteYear(year);
      await _load();
    }
  }

  Future<void> _confirmAddCycle() async {
    final active = _activeYear;
    if (active == null) return;

    const int cyclePages = 604;

    final totalCycles = active.targetCompletions;
    final currentCycles = active.completedCycles;

    final isLastCycle = currentCycles + 1 >= totalCycles;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Cycle Completion'),
        content: Text(
          isLastCycle
              ? 'This will finish the FINAL cycle and complete the year.\n\nContinue?'
              : 'This will move you to the next cycle while keeping your current page.\n\nContinue?',
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // ✅ Apply changes
    await _addCycleToActiveYear();
  }

  Future<void> _addCycleToActiveYear() async {
    final active = _activeYear;
    if (active == null) return;

    const int cyclePages = 604;

    final int currentPage = active.pagesReadTotal;
    final int currentCycle = active.completedCycles;
    final int totalCycles = active.targetCompletions;

    final bool isLastCycle = currentCycle + 1 >= totalCycles;

    if (!isLastCycle) {
      // 🔹 CASE 1: Not last cycle
      // Move to next cycle, keep page number
      active.completedCycles += 1;
      // pagesReadTotal stays EXACTLY the same
    } else {
      // 🔹 CASE 2: Last cycle
      // Add only remaining pages to finish the cycle
      final int remainingPages = cyclePages - currentPage;

      active.pagesReadTotal += remainingPages;

      // Finish year
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
          'Qur’an Khatm',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: const _GradientAppBar(),
      ),
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _activeYear != null ? _activeYearCard() : _noPlanCard(),
                const SizedBox(height: 16),
                _historySection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// =======================
  /// ACTIVE YEAR CARD
  /// =======================

  /// =======================
  /// ACTIVE YEAR CARD WITH 2 PROGRESS BARS
  /// =======================
  Widget _activeYearCard() {
    if (_activeYear == null) return const SizedBox();

    const int cyclePages = 604;
    final totalTargetPages = _activeYear!.targetCompletions * cyclePages;
    final pagesReadInYear =
        (_activeYear!.completedCycles * cyclePages) +
        _activeYear!.pagesReadTotal;
    final pagesInCurrentCycle = _activeYear!.pagesReadTotal.toDouble();

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
        switch (status) {
          case KhatmStatus.ahead:
            statusColor = Colors.green;
            break;
          case KhatmStatus.behind:
            statusColor = Colors.red;
            break;
          case KhatmStatus.onTrack:
            statusColor = Colors.blue;
        }

        // Calculate progress ratios
        final currentCycleProgress = (pagesInCurrentCycle / cyclePages).clamp(
          0.0,
          1.0,
        );
        final yearProgress = (pagesReadInYear / totalTargetPages).clamp(
          0.0,
          1.0,
        );

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Year: ${_activeYear!.year}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    tooltip: "Delete record",
                    onPressed: () => _confirmDeleteYear(_activeYear!.year),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _row('Target Khatms', _activeYear!.targetCompletions.toString()),
              _row('Pages / Day', _activeYear!.pagesPerDay.toString()),
              _row('Completed Cycles', _activeYear!.completedCycles.toString()),
              _row('Pages Read', _activeYear!.pagesReadTotal.toString()),
              _row(
                'Start Date',
                "${_activeYear!.startDate.year}-${_activeYear!.startDate.month}-${_activeYear!.startDate.day}",
              ),
              _row(
                'Status',
                diff == 0
                    ? 'On Track'
                    : diff > 0
                    ? 'Ahead by $diff pages'
                    : 'Behind by ${diff.abs()} pages',
              ),
              const SizedBox(height: 16),

              // ===================
              // Progress Bars
              // ===================
              Row(
                children: [
                  // Current Cycle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Cycle',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                  // Year Progress
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Year Progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
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
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.menu_book),
                      label: Text(
                        pagesReadInYear >= totalTargetPages
                            ? 'Year Complete'
                            : 'Start Reading',
                      ),
                      onPressed: pagesReadInYear >= totalTargetPages
                          ? null
                          : _startReading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip:
                        _activeYear!.completedCycles + 1 >=
                            _activeYear!.targetCompletions
                        ? "Finish Final Cycle"
                        : "Add Cycle",
                    onPressed: _confirmAddCycle,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Helper for progress bars
  Widget _buildProgressBar(
    double progress,
    Color color,
    int pages,
    int totalPages,
  ) {
    final textColor = progress < 0.3 ? Colors.black : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade300,
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 16,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Text(
              "${(progress * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$pages / $totalPages pages',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _noPlanCard() {
    final now = DateTime.now().year;

    // Check if there's an active year OR a completed/current year plan
    final hasCurrentYearPlan =
        (_activeYear != null && _activeYear!.year == now) ||
        _history.any((y) => y.year == now);

    // Check if current year is finished
    bool currentYearFinished = false;
    if (_activeYear != null && _activeYear!.year == now) {
      const int cyclePages = 604;
      final totalPagesInYear = _activeYear!.targetCompletions * cyclePages;
      final pagesReadInYear =
          (_activeYear!.completedCycles * cyclePages) +
          _activeYear!.pagesReadTotal;
      currentYearFinished = pagesReadInYear >= totalPagesInYear;
    }

    final canCreatePlan = !hasCurrentYearPlan || currentYearFinished;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No active Khatm plan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            canCreatePlan
                ? 'Create a yearly plan to track your Qur’an reading.'
                : 'You already have a Khatm record for this year ($now). You cannot create another one until next year or by deleting this record.',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Tooltip(
            message: canCreatePlan
                ? 'Create a new plan'
                : 'Finish or delete the current year record before creating a new one.',
            child: ElevatedButton(
              onPressed: canCreatePlan ? _configurePlan : null,
              child: const Text('Create Plan'),
            ),
          ),
        ],
      ),
    );
  }

  /// =======================
  /// HISTORY
  /// =======================

  Widget _historySection() {
    if (_history.isEmpty) {
      return const Text(
        'No previous years yet',
        style: TextStyle(color: Colors.black54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._history.map((y) {
          final expanded = _expandedYears.contains(y.year);

          const int cyclePages = 604;
          final pagesReadInYear =
              (y.completedCycles * cyclePages) + y.pagesReadTotal;
          final totalTargetPages = y.targetCompletions * cyclePages;
          final yearProgress = (pagesReadInYear / totalTargetPages)
              .clamp(0, 1)
              .toDouble();
          ;

          return GestureDetector(
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedYears.remove(y.year);
                } else {
                  _expandedYears.add(y.year);
                }
              });
            },
            child: _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// HEADER ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        y.year.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            onPressed: () => _confirmDeleteYear(y.year),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (expanded) ...[
                    const SizedBox(height: 12),
                    _row('Target Khatms', y.targetCompletions.toString()),
                    _row('Pages / Day', y.pagesPerDay.toString()),
                    _row('Completed Cycles', y.completedCycles.toString()),
                    _row('Pages Read', y.pagesReadTotal.toString()),
                    _row(
                      'Start Date',
                      '${y.startDate.year}-${y.startDate.month}-${y.startDate.day}',
                    ),
                    if (y.endDate != null)
                      _row(
                        'End Date',
                        '${y.endDate!.year}-${y.endDate!.month}-${y.endDate!.day}',
                      ),

                    const SizedBox(height: 16),

                    /// YEAR PROGRESS BAR
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Year Progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: yearProgress),
                          duration: const Duration(seconds: 1),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            final textColor = value < 0.3
                                ? Colors.black
                                : Colors.white;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    minHeight: 16,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.blue,
                                    ),
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
                          '$pagesReadInYear / $totalTargetPages pages',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// =======================
  /// ACTIONS
  /// =======================

  Future<void> _startReading() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Fetch the saved page specifically for the Khatm mode
    // If it's the first time, it defaults to page 1
    final int lastKhatmPage =
        prefs.getInt('last_read_khatm')?.clamp(1, 604) ?? 1;

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
      _load(); // Refresh your Khatm stats immediately
    }
  }

  Future<void> _configurePlan() async {
    final activeYear = _activeYear;

    // 🔹 If there's an active year that is not finished
    if (activeYear != null) {
      final totalPages = activeYear.targetCompletions * 604;
      final pagesDone =
          (activeYear.completedCycles * 604) + activeYear.pagesReadTotal;

      if (pagesDone < totalPages) {
        // Show a warning and prevent creating new plan
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Active Plan Exists"),
            content: Text(
              "You already have an active Khatm plan for ${activeYear.year}.\n\n"
              "You must complete this plan before starting a new one.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return; // Exit early, prevent new plan creation
      }
    }

    // 🔹 Continue with creating/editing plan
    final controller = TextEditingController(
      text: activeYear?.targetCompletions.toString() ?? '',
    );

    bool startFromYearStart = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Khatm Plan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Completions per year',
                      hintText: 'e.g. 1, 2, 3...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Start counting from:",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<bool>(
                    title: const Text("January 1st"),
                    value: true,
                    groupValue: startFromYearStart,
                    onChanged: (value) {
                      setState(() {
                        startFromYearStart = value!;
                      });
                    },
                  ),
                  RadioListTile<bool>(
                    title: const Text("Today"),
                    value: false,
                    groupValue: startFromYearStart,
                    onChanged: (value) {
                      setState(() {
                        startFromYearStart = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final cycles = int.tryParse(controller.text);
                    Navigator.pop(context, {
                      "cycles": cycles,
                      "startFromYearStart": startFromYearStart,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
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

  /// =======================
  /// UI HELPERS
  /// =======================

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Colors.black12,
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
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
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
            'Track and complete the Qur’an with a yearly plan',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _GradientAppBar extends StatelessWidget {
  const _GradientAppBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
