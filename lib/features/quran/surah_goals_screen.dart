import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:quran/quran.dart' as quran;
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/utils/surah_goal_service.dart';
import 'package:saleti/features/quran/mushaf_page_screen.dart';
import 'package:saleti/data/surah_pages.dart';
import 'package:saleti/utils/hold_to_delete_button.dart';
import 'package:saleti/widgets/tap_scale.dart';
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
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardColor, // CHANGED
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Delete Goal?",
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          ), // CHANGED
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Are you sure you want to delete the goal for ${goal.surahName}?",
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ), // CHANGED
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

  Widget _goalCard(SurahGoal goal, int index, ThemeData theme, bool isDark) {
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
        theme: theme,
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal.surahName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ), // CHANGED
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
                TapScale(
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
                Expanded(
                  child: _statChip('Target', '${goal.targetCount}×', isDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statChip('Done', '${goal.completedCount}×', isDark),
                ),
                if (goal.deadline != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statChip(
                      'Deadline',
                      DateFormat('MMM d y').format(goal.deadline!),
                      isDark,
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
                  color: Colors.blueGrey.withOpacity(
                    isDark ? 0.18 : 0.08,
                  ), // CHANGED
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: isDark
                          ? Colors.blueGrey.shade200
                          : Colors.blueGrey,
                    ), // CHANGED
                    const SizedBox(width: 6),
                    Text(
                      deadlineIndicator,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.blueGrey.shade200
                            : Colors.blueGrey,
                      ), // CHANGED
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final textColor = value < 0.3
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.white; // CHANGED
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.grey.shade200, // CHANGED
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

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.menu_book, size: 18),
                    label: Text(goal.isCompleted ? 'Completed' : 'Read'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isDark
                          ? Colors.white12
                          : Colors.grey.shade200, // CHANGED
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
                TapScale(
                  onTap: goal.isCompleted || goal.isExpired
                      ? () {}
                      : () async {
                          HapticFeedback.selectionClick();
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: theme.cardColor, // CHANGED
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              title: Text(
                                'Confirm Recitation',
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ), // CHANGED
                              content: Text(
                                'Did you finish reciting this surah?',
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.7),
                                ), // CHANGED
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
                                  child: const Text(
                                    'Yes',
                                    style: TextStyle(color: Colors.white),
                                  ),
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
                          ? (isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.grey.shade100) // CHANGED
                          : primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add,
                      color: (goal.isCompleted || goal.isExpired)
                          ? (isDark ? Colors.white38 : Colors.grey.shade400)
                          : primaryGreen, // CHANGED
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

  Widget _statChip(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : const Color(0xFFF4F6F8), // CHANGED
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ), // CHANGED
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ), // CHANGED
        ],
      ),
    );
  }

  Widget _goalsList(
    List<SurahGoal> goals, {
    required int tabIndex,
    required ThemeData theme,
    required bool isDark,
  }) {
    if (goals.isEmpty) {
      return _emptyState(tabIndex, theme);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: goals.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _goalCard(goals[i], i, theme, isDark),
      ),
    );
  }

  Widget _emptyState(int tabIndex, ThemeData theme) {
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ), // CHANGED
            const SizedBox(height: 6),
            Text(
              config.$3,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                fontSize: 12.5,
              ), // CHANGED
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // CHANGED
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Surah Goals',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
          _tabBar(theme, isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _goalsList(
                  _activeGoals,
                  tabIndex: 0,
                  theme: theme,
                  isDark: isDark,
                ),
                _goalsList(
                  _completedGoals,
                  tabIndex: 1,
                  theme: theme,
                  isDark: isDark,
                ),
                _goalsList(
                  _expiredGoals,
                  tabIndex: 2,
                  theme: theme,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar(ThemeData theme, bool isDark) {
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
        color: theme.cardColor, // CHANGED
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ), // CHANGED
        ],
      ),
      child: AnimatedBuilder(
        animation: _tabController.animation!,
        builder: (context, _) {
          final animValue = _tabController.animation!.value;
          return Row(
            children: List.generate(3, (i) {
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
                            isDark
                                ? Colors.white54
                                : Colors.grey.shade500, // CHANGED
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

  Widget _card({
    required Widget child,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor, // CHANGED
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ), // CHANGED
        ],
      ),
      child: child,
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
          TapScale(
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

  final List<Map<String, dynamic>> _surahs = List.generate(
    114,
    (i) => {"number": i + 1, "name": quran.getSurahName(i + 1)},
  );

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: theme.cardColor, // CHANGED
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ), // CHANGED
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
                  TapScale(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _pickSurah();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : const Color(0xFFF4F6F8), // CHANGED
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
                                    ? (isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500) // CHANGED
                                    : theme
                                          .textTheme
                                          .bodyLarge
                                          ?.color, // CHANGED
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade400,
                          ), // CHANGED
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                    ), // ADD
                    decoration: InputDecoration(
                      labelText: "Target count",
                      hintText: "e.g. 3",
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : const Color(0xFFF4F6F8), // CHANGED
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.repeat_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TapScale(
                    onTap: _pickDeadline,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : const Color(0xFFF4F6F8), // CHANGED
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: isDark
                                ? Colors.white60
                                : Colors.grey.shade600,
                            size: 18,
                          ), // CHANGED
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _deadline == null
                                  ? "No deadline (optional)"
                                  : "${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                color: _deadline == null
                                    ? (isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500) // CHANGED
                                    : theme
                                          .textTheme
                                          .bodyLarge
                                          ?.color, // CHANGED
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
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.5,
                          ),
                          fontStyle: FontStyle.italic,
                        ), // CHANGED
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
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ), // CHANGED
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.7,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ), // CHANGED
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
                          disabledBackgroundColor: isDark
                              ? Colors.white12
                              : Colors.grey.shade300, // CHANGED
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Add Goal",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = widget.surahs
        .where((s) => s["name"].toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: theme.cardColor, // CHANGED
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ), // CHANGED
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Select Surah",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ), // CHANGED
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ), // CHANGED
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.6,
                        ),
                      ), // CHANGED
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFF4F6F8), // CHANGED
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  autofocus: true,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                  ), // ADD
                  decoration: InputDecoration(
                    hintText: "Search Surah...",
                    hintStyle: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.4,
                      ),
                    ), // ADD
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.4,
                      ),
                    ), // CHANGED
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
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.5,
                          ),
                        ),
                      ), // CHANGED
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.grey.shade100,
                      ), // CHANGED
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
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ), // CHANGED
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade400,
                          ), // CHANGED
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
