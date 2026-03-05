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

  KhatmYear({
    required this.year,
    required this.targetCompletions,
    required this.pagesPerDay,
    required this.startDate,
    this.pagesReadTotal = 0,
    this.completedCycles = 0,
    this.isActive = true,
    this.endDate,
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

  KhatmYear? _activeYear;
  List<KhatmYear> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _service.rolloverIfNeeded();

    final active = await _service.getActiveYear();
    final history = await _service.getHistory();

    setState(() {
      _activeYear = active;
      _history = history;
    });
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
          _header(),
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
  /// HEADER
  /// =======================

  Widget _header() {
    return const _Header();
  }

  /// =======================
  /// ACTIVE YEAR CARD
  /// =======================

  Widget _activeYearCard() {
    final diff = _service.pagesAheadOrBehind();
    final status = diff == 0
        ? KhatmStatus.onTrack
        : diff > 0
        ? KhatmStatus.ahead
        : KhatmStatus.behind;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Year: ${_activeYear!.year}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _row('Target Khatms', _activeYear!.targetCompletions.toString()),
          _row('Pages / Day', _activeYear!.pagesPerDay.toString()),
          _row('Completed Cycles', _activeYear!.completedCycles.toString()),
          _row(
            'Status',
            status == KhatmStatus.onTrack
                ? 'On track'
                : status == KhatmStatus.ahead
                ? 'Ahead by $diff pages'
                : 'Behind by ${diff.abs()} pages',
          ),
          const SizedBox(height: 16),
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
                onPressed: _configurePlan,
              ),
            ],
          ),
        ],
      ),
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
        ..._history.map(
          (y) => _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  y.year.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _row('Completed Khatms', y.completedCycles.toString()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// =======================
  /// ACTIONS
  /// =======================

  void _startReading() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafPageScreen(readingMode: ReadingMode.khatm),
      ),
    );
  }

  Future<void> _configurePlan() async {
    final controller = TextEditingController(
      text: _activeYear?.targetCompletions.toString() ?? '',
    );

    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Khatm Plan'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Completions per year',
            hintText: 'e.g. 1, 2, 3...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await _service.startYear(DateTime.now().year, result);
      await _load();
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
