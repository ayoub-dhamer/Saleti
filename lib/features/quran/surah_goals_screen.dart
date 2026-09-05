import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/utils/surah_goal_service.dart';
import 'package:saleti/features/quran/mushaf_page_screen.dart';
import 'package:saleti/data/surah_pages.dart';
import 'package:saleti/utils/hold_to_delete_button.dart';
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
  String label;

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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Widget _goalCard(SurahGoal goal, int index) {
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

      if (remaining >= daysLeft) {
        final perDay = (remaining / daysLeft).ceil();
        return "$perDay time${perDay > 1 ? 's' : ''} per day";
      }

      final everyDays = (daysLeft / remaining).ceil();
      return "1 time every $everyDays day${everyDays > 1 ? 's' : ''}";
    }

    final deadlineIndicator = buildDeadlineIndicator(goal);

    return TweenAnimationBuilder<double>(
      key: ValueKey('goal_${goal.surahNumber}_${goal.label}'),
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
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal.surahName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (goal.isExpired)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_off_rounded,
                          color: Colors.red,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Expired',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                _TapScale(
                  onTap: () => _confirmDelete(goal),
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

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: _statChip('Target', '${goal.targetCount}×')),
                const SizedBox(width: 8),
                Expanded(child: _statChip('Done', '${goal.completedCount}×')),
                if (goal.deadline != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statChip(
                      'Deadline',
                      DateFormat('MMM d y').format(goal.deadline!),
                    ),
                  ),
                ],
              ],
            ),

            if (deadlineIndicator != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      deadlineIndicator,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            /// PROGRESS BAR
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
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
                        valueColor: AlwaysStoppedAnimation(
                          goal.isExpired
                              ? Colors.red
                              : goal.isCompleted
                              ? Colors.blueGrey
                              : primaryGreen,
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

            const SizedBox(height: 16),

            /// ACTIONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.menu_book, size: 18),
                    label: Text(goal.isCompleted ? 'Completed' : 'Read'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
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
                            if (result == true) _loadGoals();
                          },
                  ),
                ),
                const SizedBox(width: 10),
                _TapScale(
                  onTap: goal.isCompleted || goal.isExpired
                      ? () {}
                      : () async {
                          HapticFeedback.selectionClick();
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              title: const Text('Confirm Recitation'),
                              content: const Text(
                                'Did you finish reciting this surah?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryGreen,
                                  ),
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
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (goal.isCompleted || goal.isExpired)
                          ? Colors.grey.shade100
                          : primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add,
                      color: (goal.isCompleted || goal.isExpired)
                          ? Colors.grey.shade400
                          : primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

  Widget _goalsList(List<SurahGoal> goals, {required int tabIndex}) {
    if (goals.isEmpty) {
      return _emptyState(tabIndex);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: goals.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _goalCard(goals[i], i),
      ),
    );
  }

  Widget _emptyState(int tabIndex) {
    final config = switch (tabIndex) {
      0 => (
        Icons.flag_outlined,
        'No active goals',
        'Set a target and start tracking your recitation.',
      ),
      1 => (
        Icons.emoji_events_outlined,
        'No completed goals yet',
        'Finished goals will show up here.',
      ),
      _ => (
        Icons.timer_off_outlined,
        'No expired goals',
        'Goals that pass their deadline appear here.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                config.$1,
                size: 48,
                color: primaryGreen.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              config.$2,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              config.$3,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
            ),
          ],
        ),
      ),
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
          _Header(onAdd: _addGoal, goalCount: _goals.length),
          _tabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _goalsList(_activeGoals, tabIndex: 0),
                _goalsList(_completedGoals, tabIndex: 1),
                _goalsList(_expiredGoals, tabIndex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    final labels = ['Active', 'Completed', 'Expired'];
    final counts = [
      _activeGoals.length,
      _completedGoals.length,
      _expiredGoals.length,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _tabController.animation!,
        builder: (context, _) {
          final animValue = _tabController.animation!.value; // continuous 0..2
          return Row(
            children: List.generate(3, (i) {
              // how "selected" this tab is, smoothly, based on distance from animValue
              final selection = (1 - (animValue - i).abs()).clamp(0.0, 1.0);
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _tabController.animateTo(i);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        Colors.transparent,
                        primaryGreen,
                        selection,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${labels[i]} (${counts[i]})',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color.lerp(
                            Colors.grey.shade500,
                            Colors.white,
                            selection,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
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

class _Header extends StatelessWidget {
  final VoidCallback onAdd;
  final int goalCount;

  const _Header({required this.onAdd, required this.goalCount});

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Surah Goals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  goalCount == 0
                      ? 'Track your Surah recitation goals'
                      : '$goalCount ${goalCount == 1 ? 'goal' : 'goals'} tracked',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _TapScale(
            onTap: () {
              HapticFeedback.selectionClick();
              onAdd();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
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

  final List<Map<String, dynamic>> _surahs = [
    {"number": 1, "name": "Al-Fatiha"},
    {"number": 2, "name": "Al-Baqarah"},
    {"number": 3, "name": "Aal-E-Imran"},
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
    {"number": 23, "name": "Al-Mu'minun"},
    {"number": 24, "name": "An-Nur"},
    {"number": 25, "name": "Al-Furqan"},
    {"number": 26, "name": "Ash-Shu'ara"},
    {"number": 27, "name": "An-Naml"},
    {"number": 28, "name": "Al-Qasas"},
    {"number": 29, "name": "Al-Ankabut"},
    {"number": 30, "name": "Ar-Rum"},
    {"number": 31, "name": "Luqman"},
    {"number": 32, "name": "As-Sajda"},
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
    {"number": 45, "name": "Al-Jathiya"},
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
    {"number": 56, "name": "Al-Waqia"},
    {"number": 57, "name": "Al-Hadid"},
    {"number": 58, "name": "Al-Mujadila"},
    {"number": 59, "name": "Al-Hashr"},
    {"number": 60, "name": "Al-Mumtahina"},
    {"number": 61, "name": "As-Saff"},
    {"number": 62, "name": "Al-Jumu'a"},
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
    {"number": 75, "name": "Al-Qiyama"},
    {"number": 76, "name": "Al-Insan"},
    {"number": 77, "name": "Al-Mursalat"},
    {"number": 78, "name": "An-Naba"},
    {"number": 79, "name": "An-Naziat"},
    {"number": 80, "name": "Abasa"},
    {"number": 81, "name": "At-Takwir"},
    {"number": 82, "name": "Al-Infitar"},
    {"number": 83, "name": "Al-Mutaffifin"},
    {"number": 84, "name": "Al-Inshiqaq"},
    {"number": 85, "name": "Al-Buruj"},
    {"number": 86, "name": "At-Tariq"},
    {"number": 87, "name": "Al-Ala"},
    {"number": 88, "name": "Al-Ghashiya"},
    {"number": 89, "name": "Al-Fajr"},
    {"number": 90, "name": "Al-Balad"},
    {"number": 91, "name": "Ash-Shams"},
    {"number": 92, "name": "Al-Lail"},
    {"number": 93, "name": "Ad-Duha"},
    {"number": 94, "name": "Ash-Sharh"},
    {"number": 95, "name": "At-Tin"},
    {"number": 96, "name": "Al-Alaq"},
    {"number": 97, "name": "Al-Qadr"},
    {"number": 98, "name": "Al-Bayyina"},
    {"number": 99, "name": "Az-Zalzala"},
    {"number": 100, "name": "Al-Adiyat"},
    {"number": 101, "name": "Al-Qaria"},
    {"number": 102, "name": "At-Takathur"},
    {"number": 103, "name": "Al-Asr"},
    {"number": 104, "name": "Al-Humaza"},
    {"number": 105, "name": "Al-Fil"},
    {"number": 106, "name": "Quraish"},
    {"number": 107, "name": "Al-Ma'un"},
    {"number": 108, "name": "Al-Kawthar"},
    {"number": 109, "name": "Al-Kafiroon"},
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
    if (_deadline == null) return surah["name"];
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
    HapticFeedback.selectionClick();
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

  bool get _canSubmit =>
      _selectedSurah != null && _targetController.text.trim().isNotEmpty;

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
                      Icons.flag_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "New Surah Goal",
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TapScale(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _pickSurah();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedSurah != null
                              ? primaryGreen.withOpacity(0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            color: primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedSurah == null
                                  ? "Select Surah"
                                  : _surahs.firstWhere(
                                      (s) => s["number"] == _selectedSurah,
                                    )["name"],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _selectedSurah == null
                                    ? Colors.grey.shade500
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: "Target count",
                      hintText: "e.g. 3",
                      filled: true,
                      fillColor: const Color(0xFFF4F6F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.repeat_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TapScale(
                    onTap: _pickDeadline,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.grey.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _deadline == null
                                  ? "No deadline (optional)"
                                  : "${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                color: _deadline == null
                                    ? Colors.grey.shade500
                                    : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            "Pick date",
                            style: TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedSurah != null) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _labelController.text,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
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
                        "Cancel",
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
                        onPressed: _canSubmit ? _submit : null,
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
                          "Add Goal",
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Select Surah",
                      style: TextStyle(
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
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Search Surah...",
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        "No results found",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final surah = filtered[index];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${surah['number']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryGreen,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            surah['name'],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context, surah);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
