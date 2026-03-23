import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:saleti/features/quran/dua_notes_screen.dart';
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/utils/surah_goal_service.dart';
import 'package:saleti/features/quran/mushaf_page_screen.dart';
import 'package:saleti/data/surah_pages.dart';

part 'surah_goals_screen.g.dart';

@HiveType(typeId: 30)
class SurahGoal extends HiveObject {
  @HiveField(0)
  int surahNumber;

  @HiveField(1)
  String surahName;

  @HiveField(2)
  int targetCount;

  @HiveField(3)
  int completedCount;

  @HiveField(4)
  DateTime? deadline;

  @HiveField(5)
  String label; // ✅ NEW

  SurahGoal({
    required this.surahNumber,
    required this.surahName,
    required this.targetCount,
    this.completedCount = 0,
    this.deadline,
    required this.label,
  });

  bool get isExpired =>
      !isCompleted && deadline != null && DateTime.now().isAfter(deadline!);

  bool get isCompleted => completedCount >= targetCount;

  double get progress => targetCount == 0 ? 0 : completedCount / targetCount;
}

const Color primaryGreen = Color(0xFF1FA45B);
const Color secondaryGreen = Color(0xFF4FC3A1);

class SurahGoalsScreen extends StatefulWidget {
  const SurahGoalsScreen({super.key});

  @override
  State<SurahGoalsScreen> createState() => _SurahGoalsScreenState();
}

class _SurahGoalsScreenState extends State<SurahGoalsScreen>
    with SingleTickerProviderStateMixin {
  final SurahGoalService _service = SurahGoalService();

  List<SurahGoal> _goals = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final goals = await _service.getGoals();

    setState(() {
      _goals = goals;
    });
  }

  Future<void> _confirmDelete(SurahGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: const Text("Delete Goal?"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Are you sure you want to delete the goal for ${goal.surahName}?",
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
              child: const Text("Cancel"),
            ),
            const SizedBox(width: 8),
            HoldToDeleteButton(onConfirmed: () => Navigator.pop(context, true)),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _service.deleteGoal(goal);
      await _loadGoals();
    }
  }

  List<SurahGoal> get _activeGoals =>
      _goals.where((g) => !g.isCompleted && !g.isExpired).toList();

  List<SurahGoal> get _completedGoals =>
      _goals.where((g) => g.isCompleted).toList();

  List<SurahGoal> get _expiredGoals =>
      _goals.where((g) => g.isExpired && !g.isCompleted).toList();

  Future<void> _addGoal() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddSurahGoalDialog(),
    );

    if (result == null) return;

    await _service.addGoal(
      result['surahNumber'],
      result['surahName'],
      result['targetCount'],
      deadline: result['deadline'],
      label: result['label'],
    );

    await _loadGoals();
  }

  Widget _goalCard(SurahGoal goal) {
    final progress = goal.progress;

    String? buildDeadlineIndicator(SurahGoal goal) {
      if (goal.deadline == null || goal.isCompleted) return null;

      final now = DateTime.now();
      final daysLeft =
          goal.deadline!
              .difference(DateTime(now.year, now.month, now.day))
              .inDays +
          1;

      if (daysLeft <= 0) return "Deadline passed";

      final remaining = goal.targetCount - goal.completedCount;

      if (remaining <= 0) return null;

      // Case 1: multiple per day
      if (remaining >= daysLeft) {
        final perDay = (remaining / daysLeft).ceil();
        return "$perDay time${perDay > 1 ? 's' : ''} per day";
      }

      // Case 2: once every X days
      final everyDays = (daysLeft / remaining).ceil();
      return "1 time every $everyDays day${everyDays > 1 ? 's' : ''}";
    }

    // ✅ Declare indicator before return
    final deadlineIndicator = buildDeadlineIndicator(goal);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.surahName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (goal.isExpired)
                    const Icon(Icons.timer_off, color: Colors.red, size: 18),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed: () => _confirmDelete(goal),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          _row("Target", "${goal.targetCount} times"),
          _row("Completed", goal.completedCount.toString()),

          if (goal.deadline != null)
            _row(
              "Deadline",
              "${goal.deadline!.year}-${goal.deadline!.month}-${goal.deadline!.day}",
            ),

          // ✅ Use the indicator here
          if (deadlineIndicator != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 6),
                Text(
                  deadlineIndicator,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          /// PROGRESS BAR
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final textColor = value < 0.3 ? Colors.black : Colors.white;

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
                        goal.isExpired
                            ? Colors.red
                            : goal.isCompleted
                            ? Colors.blueGrey
                            : Colors.green,
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

          const SizedBox(height: 6),

          Text(
            "${goal.completedCount} / ${goal.targetCount}",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 14),

          /// ACTIONS
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.menu_book),
                  label: const Text("Read"),
                  onPressed: goal.isCompleted
                      ? null
                      : () async {
                          final int startPage =
                              surahStartPages[goal.surahNumber] ?? 1;
                          final int endPage =
                              surahEndPages[goal.surahNumber] ?? 604;

                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MushafPageScreen(
                                startPage: startPage,
                                endPage: endPage,
                                readingMode: ReadingMode.goal,
                                storageKey: 'last_read_goals',
                                surahGoal: goal,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadGoals();
                          }
                        },
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: "Increment",
                onPressed: goal.isCompleted || goal.isExpired
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Confirm Recitation'),
                            content: const Text(
                              'Did you finish reciting this surah?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Yes'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await _service.incrementProgress(goal);
                          await _loadGoals();
                        }
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _goalsList(List<SurahGoal> goals) {
    if (goals.isEmpty) {
      return const Center(
        child: Text(
          "No goals here yet",
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: goals.length,
      itemBuilder: (_, i) => _goalCard(goals[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Surah Goals',
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
          _Header(onAdd: _addGoal),

          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF1FA45B),
            labelColor: Colors.black,
            tabs: const [
              Tab(text: "Active"),
              Tab(text: "Completed"),
              Tab(text: "Expired"),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _goalsList(_activeGoals),
                _goalsList(_completedGoals),
                _goalsList(_expiredGoals),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

class _Header extends StatelessWidget {
  final VoidCallback onAdd;

  const _Header({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryGreen, secondaryGreen]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Surah Goals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Track your Surah recitation goals',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          /// ADD BUTTON
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: "Add Goal",
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSurahGoalDialog extends StatefulWidget {
  const _AddSurahGoalDialog();

  @override
  State<_AddSurahGoalDialog> createState() => _AddSurahGoalDialogState();
}

class _AddSurahGoalDialogState extends State<_AddSurahGoalDialog> {
  int? _selectedSurah;
  final TextEditingController _targetController = TextEditingController();
  DateTime? _deadline;

  final TextEditingController _labelController = TextEditingController();

  /// Simple Surah list
  final List<Map<String, dynamic>> _surahs = [
    {"number": 1, "name": "Al-Fatiha"},
    {"number": 2, "name": "Al-Baqarah"},
    {"number": 3, "name": "Aal-Imran"},
    {"number": 4, "name": "An-Nisa"},
    {"number": 5, "name": "Al-Ma'idah"},
    {"number": 6, "name": "Al-An'am"},
    {"number": 7, "name": "Al-A'raf"},
    {"number": 8, "name": "Al-Anfal"},
    {"number": 9, "name": "At-Tawbah"},
    {"number": 10, "name": "Yunus"},
    {"number": 11, "name": "Hud"},
    {"number": 12, "name": "Yusuf"},
    {"number": 13, "name": "Ar-Ra'd"},
    {"number": 14, "name": "Ibrahim"},
    {"number": 15, "name": "Al-Hijr"},
    {"number": 16, "name": "An-Nahl"},
    {"number": 17, "name": "Al-Isra"},
    {"number": 18, "name": "Al-Kahf"},
    {"number": 19, "name": "Maryam"},
    {"number": 20, "name": "Ta-Ha"},
    {"number": 21, "name": "Al-Anbiya"},
    {"number": 22, "name": "Al-Hajj"},
    {"number": 23, "name": "Al-Mu’minun"},
    {"number": 24, "name": "An-Nur"},
    {"number": 25, "name": "Al-Furqan"},
    {"number": 26, "name": "Ash-Shu'ara"},
    {"number": 27, "name": "An-Naml"},
    {"number": 28, "name": "Al-Qasas"},
    {"number": 29, "name": "Al-Ankabut"},
    {"number": 30, "name": "Ar-Rum"},
    {"number": 31, "name": "Luqman"},
    {"number": 32, "name": "As-Sajdah"},
    {"number": 33, "name": "Al-Ahzab"},
    {"number": 34, "name": "Saba"},
    {"number": 35, "name": "Fatir"},
    {"number": 36, "name": "Ya-Sin"},
    {"number": 37, "name": "As-Saffat"},
    {"number": 38, "name": "Sad"},
    {"number": 39, "name": "Az-Zumar"},
    {"number": 40, "name": "Ghafir"},
    {"number": 41, "name": "Fussilat"},
    {"number": 42, "name": "Ash-Shura"},
    {"number": 43, "name": "Az-Zukhruf"},
    {"number": 44, "name": "Ad-Dukhan"},
    {"number": 45, "name": "Al-Jathiyah"},
    {"number": 46, "name": "Al-Ahqaf"},
    {"number": 47, "name": "Muhammad"},
    {"number": 48, "name": "Al-Fath"},
    {"number": 49, "name": "Al-Hujurat"},
    {"number": 50, "name": "Qaf"},
    {"number": 51, "name": "Adh-Dhariyat"},
    {"number": 52, "name": "At-Tur"},
    {"number": 53, "name": "An-Najm"},
    {"number": 54, "name": "Al-Qamar"},
    {"number": 55, "name": "Ar-Rahman"},
    {"number": 56, "name": "Al-Waqi'ah"},
    {"number": 57, "name": "Al-Hadid"},
    {"number": 58, "name": "Al-Mujadila"},
    {"number": 59, "name": "Al-Hashr"},
    {"number": 60, "name": "Al-Mumtahanah"},
    {"number": 61, "name": "As-Saff"},
    {"number": 62, "name": "Al-Jumu'ah"},
    {"number": 63, "name": "Al-Munafiqun"},
    {"number": 64, "name": "At-Taghabun"},
    {"number": 65, "name": "At-Talaq"},
    {"number": 66, "name": "At-Tahrim"},
    {"number": 67, "name": "Al-Mulk"},
    {"number": 68, "name": "Al-Qalam"},
    {"number": 69, "name": "Al-Haqqah"},
    {"number": 70, "name": "Al-Ma'arij"},
    {"number": 71, "name": "Nuh"},
    {"number": 72, "name": "Al-Jinn"},
    {"number": 73, "name": "Al-Muzzammil"},
    {"number": 74, "name": "Al-Muddathir"},
    {"number": 75, "name": "Al-Qiyamah"},
    {"number": 76, "name": "Al-Insan"},
    {"number": 77, "name": "Al-Mursalat"},
    {"number": 78, "name": "An-Naba"},
    {"number": 79, "name": "An-Nazi'at"},
    {"number": 80, "name": "Abasa"},
    {"number": 81, "name": "At-Takwir"},
    {"number": 82, "name": "Al-Infitar"},
    {"number": 83, "name": "Al-Mutaffifin"},
    {"number": 84, "name": "Al-Inshiqaq"},
    {"number": 85, "name": "Al-Buruj"},
    {"number": 86, "name": "At-Tariq"},
    {"number": 87, "name": "Al-A'la"},
    {"number": 88, "name": "Al-Ghashiyah"},
    {"number": 89, "name": "Al-Fajr"},
    {"number": 90, "name": "Al-Balad"},
    {"number": 91, "name": "Ash-Shams"},
    {"number": 92, "name": "Al-Layl"},
    {"number": 93, "name": "Ad-Duha"},
    {"number": 94, "name": "Ash-Sharh"},
    {"number": 95, "name": "At-Tin"},
    {"number": 96, "name": "Al-Alaq"},
    {"number": 97, "name": "Al-Qadr"},
    {"number": 98, "name": "Al-Bayyinah"},
    {"number": 99, "name": "Az-Zalzalah"},
    {"number": 100, "name": "Al-Adiyat"},
    {"number": 101, "name": "Al-Qari'ah"},
    {"number": 102, "name": "At-Takathur"},
    {"number": 103, "name": "Al-Asr"},
    {"number": 104, "name": "Al-Humazah"},
    {"number": 105, "name": "Al-Fil"},
    {"number": 106, "name": "Quraysh"},
    {"number": 107, "name": "Al-Ma'un"},
    {"number": 108, "name": "Al-Kawthar"},
    {"number": 109, "name": "Al-Kafirun"},
    {"number": 110, "name": "An-Nasr"},
    {"number": 111, "name": "Al-Masad"},
    {"number": 112, "name": "Al-Ikhlas"},
    {"number": 113, "name": "Al-Falaq"},
    {"number": 114, "name": "An-Nas"},
  ];

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now().add(const Duration(days: 7)),
    );

    if (picked != null) {
      setState(() {
        _deadline = picked;
        _labelController.text = _buildLabel();
      });
    }
  }

  String _buildLabel() {
    if (_selectedSurah == null) return "";

    final surah = _surahs.firstWhere((s) => s["number"] == _selectedSurah);

    if (_deadline == null) {
      return surah["name"];
    }

    final d = _deadline!;
    final date =
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    return "${surah["name"]} · $date";
  }

  void _submit() {
    if (_selectedSurah == null ||
        _targetController.text.isEmpty ||
        _labelController.text.trim().isEmpty) {
      return;
    }

    final surah = _surahs.firstWhere((s) => s["number"] == _selectedSurah);

    Navigator.pop(context, {
      "surahNumber": surah["number"],
      "surahName": surah["name"],
      "targetCount": int.parse(_targetController.text),
      "deadline": _deadline,
      "label": _labelController.text.trim(),
    });
  }

  Future<void> _pickSurah() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SurahSearchDialog(surahs: _surahs),
    );

    if (result != null) {
      setState(() {
        _selectedSurah = result["number"];
        _labelController.text = _buildLabel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Surah Goal"),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: SingleChildScrollView(
        child: Column(
          children: [
            /// SURAH DROPDOWN
            InkWell(
              onTap: _pickSurah,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: "Surah",
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedSurah == null
                      ? "Select Surah"
                      : _surahs.firstWhere(
                          (s) => s["number"] == _selectedSurah,
                        )["name"],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// TARGET COUNT
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Target count",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            /// DEADLINE
            Row(
              children: [
                Expanded(
                  child: Text(
                    _deadline == null
                        ? "No deadline"
                        : "${_deadline!.year}-${_deadline!.month}-${_deadline!.day}",
                  ),
                ),
                TextButton(
                  onPressed: _pickDeadline,
                  child: const Text("Pick date"),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Cancel"),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(onPressed: _submit, child: const Text("Add Goal")),
      ],
    );
  }
}

class _SurahSearchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> surahs;

  const _SurahSearchDialog({required this.surahs});

  @override
  State<_SurahSearchDialog> createState() => _SurahSearchDialogState();
}

class _SurahSearchDialogState extends State<_SurahSearchDialog> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final filtered = widget.surahs
        .where((s) => s["name"].toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text("Select Surah"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Search surah...",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final surah = filtered[i];
                return ListTile(
                  title: Text(surah["name"]),
                  trailing: Text("${surah["number"]}"),
                  onTap: () => Navigator.pop(context, surah),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
