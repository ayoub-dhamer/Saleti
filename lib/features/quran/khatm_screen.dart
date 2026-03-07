import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../utils/khatm_service.dart';
import 'mushaf_page_screen.dart';

part 'khatm_screen.g.dart';

/// =======================
/// ENUMS
/// =======================

enum KhatmStatus { ahead, onTrack, behind }

enum ReadingMode { free, khatm }

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

    final totalTargetPages = _activeYear!.targetCompletions * 604;
    final pagesReadInCycle =
        (_activeYear!.completedCycles * 604) + _activeYear!.pagesReadTotal;
    final pagesInCurrentCycle = _activeYear!.pagesReadTotal.toDouble();
    final cyclePages = 604;

    return FutureBuilder<int>(
      future: _service.pagesAheadOrBehind(),
      builder: (context, snapshot) {
        int diff = 0;
        if (snapshot.hasData) diff = snapshot.data!;
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
          default:
            statusColor = Colors.blue;
        }

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER ROW
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

              /// INFO ROWS
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

              /// ===============================
              /// PROGRESS BARS
              /// ===============================
              Row(
                children: [
                  /// Current Cycle Progress
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
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: pagesInCurrentCycle / cyclePages,
                          ),
                          duration: const Duration(seconds: 1),
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
                                      statusColor,
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
                          '$pagesInCurrentCycle / $cyclePages pages',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  /// Year Progress
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
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: pagesReadInCycle / totalTargetPages,
                          ),
                          duration: const Duration(seconds: 1),
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
                                      statusColor,
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
                          '$pagesReadInCycle / $totalTargetPages pages',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              /// ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Start Reading'),
                      onPressed: _startReading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: "Edit Plan",
                    onPressed: _configurePlan,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _noPlanCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No active Khatm plan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a yearly plan to track your Qur’an reading.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _configurePlan,
            child: const Text('Create Plan'),
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

          final totalTargetPages = y.targetCompletions * 604;
          final pagesReadInYear = (y.completedCycles * 604) + y.pagesReadTotal;
          final yearProgress = pagesReadInYear / totalTargetPages;

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

                  /// EXPANDED CONTENT
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

                    /// ===============================
                    /// YEAR PROGRESS BAR (Animated)
                    /// ===============================
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafPageScreen(readingMode: ReadingMode.khatm),
      ),
    );

    // Refresh active year after coming back
    await _load();
  }

  Future<void> _configurePlan() async {
    final controller = TextEditingController(
      text: _activeYear?.targetCompletions.toString() ?? '',
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

                  /// START DATE OPTION
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
