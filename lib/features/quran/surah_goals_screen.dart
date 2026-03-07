import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/features/quran/mushaf_page_screen.dart';
import 'package:saleti/utils/surah_goal_service.dart'; // import your service
import 'package:saleti/data/surah_pages.dart';

part 'surah_goals_screen.g.dart'; // Hive type generation

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
  DateTime? deadline; // null = no time limit

  SurahGoal({
    required this.surahNumber,
    required this.surahName,
    required this.targetCount,
    this.completedCount = 0,
    this.deadline,
  });

  bool get isExpired => deadline != null && DateTime.now().isAfter(deadline!);

  double get progress => targetCount == 0 ? 0 : completedCount / targetCount;

  bool get isCompleted => completedCount >= targetCount;

  bool get isInProgress => !isCompleted;
}

class SurahGoalsScreen extends StatefulWidget {
  const SurahGoalsScreen({super.key});

  @override
  State<SurahGoalsScreen> createState() => _SurahGoalsScreenState();
}

class _SurahGoalsScreenState extends State<SurahGoalsScreen> {
  final SurahGoalService _service = SurahGoalService();
  List<SurahGoal> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final goals = await _service.getGoals();

    // Sort: in-progress first, then completed
    goals.sort((a, b) {
      if (a.isCompleted == b.isCompleted) return 0;
      if (a.isCompleted) return 1; // completed at bottom
      return -1; // in-progress at top
    });

    setState(() => _goals = goals);
  }

  Future<void> _addGoal() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddSurahGoalDialog(),
    );

    if (result != null) {
      await _service.addGoal(
        result['surahNumber'],
        result['surahName'],
        result['targetCount'],
        deadline: result['deadline'],
      );

      await _loadGoals();
    }
  }

  Widget _goalCard(SurahGoal goal) {
    final progress = goal.progress;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: goal.isExpired ? Colors.red.shade50 : null,
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(goal.surahName)),
            if (goal.isExpired)
              const Icon(Icons.timer_off, color: Colors.red, size: 18),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
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
                              : value < 1.0
                              ? Colors.green
                              : Colors.blueGrey,
                        ),
                      ),
                    ),
                    Text(
                      "${(value * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: value < 0.3 ? Colors.black : Colors.white,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            Text('${goal.completedCount} / ${goal.targetCount} times'),
            if (goal.deadline != null)
              Text(
                'Deadline: ${goal.deadline!.year}-${goal.deadline!.month}-${goal.deadline!.day}',
                style: TextStyle(
                  fontSize: 12,
                  color: goal.isExpired ? Colors.red : Colors.black54,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: goal.isCompleted || goal.isExpired
                  ? null
                  : () async {
                      await _service.incrementProgress(goal);
                      await _loadGoals();
                    },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: () async {
                await _service.deleteGoal(goal);
                await _loadGoals();
              },
            ),
            IconButton(
              icon: const Icon(Icons.menu_book),
              onPressed: () {
                final int goalStartPage =
                    surahStartPages[goal.surahNumber] ?? 1;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MushafPageScreen(
                      startPage: goalStartPage,
                      storageKey: 'last_read_goals', // THIRD KEY
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Surah Goals Tracker'),
        backgroundColor: const Color(0xFF1FA45B),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGoal,
        child: const Icon(Icons.add),
      ),
      body: _goals.isEmpty
          ? const Center(child: Text('No goals yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _goals.length,
              itemBuilder: (_, index) => _goalCard(_goals[index]),
            ),
    );
  }
}

class _AddSurahGoalDialog extends StatefulWidget {
  const _AddSurahGoalDialog();

  @override
  State<_AddSurahGoalDialog> createState() => _AddSurahGoalDialogState();
}

class SurahItem {
  final int number;
  final String name;

  const SurahItem(this.number, this.name);
}

class _AddSurahGoalDialogState extends State<_AddSurahGoalDialog> {
  final List<SurahItem> surahs = List.generate(
    114,
    (i) => SurahItem(i + 1, _surahNames[i]),
  );

  static const List<String> _surahNames = [
    "Al-Fatihah",
    "Al-Baqarah",
    "Aal-E-Imran",
    "An-Nisa",
    "Al-Ma'idah",
    "Al-An'am",
    "Al-A'raf",
    "Al-Anfal",
    "At-Tawbah",
    "Yunus",
    "Hud",
    "Yusuf",
    "Ar-Ra'd",
    "Ibrahim",
    "Al-Hijr",
    "An-Nahl",
    "Al-Isra",
    "Al-Kahf",
    "Maryam",
    "Ta-Ha",
    "Al-Anbiya",
    "Al-Hajj",
    "Al-Mu'minun",
    "An-Nur",
    "Al-Furqan",
    "Ash-Shu'ara",
    "An-Naml",
    "Al-Qasas",
    "Al-Ankabut",
    "Ar-Rum",
    "Luqman",
    "As-Sajdah",
    "Al-Ahzab",
    "Saba",
    "Fatir",
    "Ya-Sin",
    "As-Saffat",
    "Sad",
    "Az-Zumar",
    "Ghafir",
    "Fussilat",
    "Ash-Shura",
    "Az-Zukhruf",
    "Ad-Dukhan",
    "Al-Jathiyah",
    "Al-Ahqaf",
    "Muhammad",
    "Al-Fath",
    "Al-Hujurat",
    "Qaf",
    "Adh-Dhariyat",
    "At-Tur",
    "An-Najm",
    "Al-Qamar",
    "Ar-Rahman",
    "Al-Waqi'ah",
    "Al-Hadid",
    "Al-Mujadila",
    "Al-Hashr",
    "Al-Mumtahanah",
    "As-Saff",
    "Al-Jumu'ah",
    "Al-Munafiqun",
    "At-Taghabun",
    "At-Talaq",
    "At-Tahrim",
    "Al-Mulk",
    "Al-Qalam",
    "Al-Haqqah",
    "Al-Ma'arij",
    "Nuh",
    "Al-Jinn",
    "Al-Muzzammil",
    "Al-Muddaththir",
    "Al-Qiyamah",
    "Al-Insan",
    "Al-Mursalat",
    "An-Naba",
    "An-Nazi'at",
    "Abasa",
    "At-Takwir",
    "Al-Infitar",
    "Al-Mutaffifin",
    "Al-Inshiqaq",
    "Al-Buruj",
    "At-Tariq",
    "Al-A'la",
    "Al-Ghashiyah",
    "Al-Fajr",
    "Al-Balad",
    "Ash-Shams",
    "Al-Layl",
    "Ad-Duha",
    "Ash-Sharh",
    "At-Tin",
    "Al-Alaq",
    "Al-Qadr",
    "Al-Bayyinah",
    "Az-Zalzalah",
    "Al-Adiyat",
    "Al-Qari'ah",
    "At-Takathur",
    "Al-Asr",
    "Al-Humazah",
    "Al-Fil",
    "Quraysh",
    "Al-Ma'un",
    "Al-Kawthar",
    "Al-Kafirun",
    "An-Nasr",
    "Al-Masad",
    "Al-Ikhlas",
    "Al-Falaq",
    "An-Nas",
  ];

  String search = "";
  String? selectedSurah;
  int target = 1;
  bool useDeadline = false;
  DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final filtered = surahs
        .where((s) => s.name.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text("New Surah Goal"),
      content: SizedBox(
        width: 400,
        height: 420,
        child: Column(
          children: [
            /// Search
            TextField(
              decoration: const InputDecoration(
                hintText: "Search Surah...",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => search = v),
            ),

            const SizedBox(height: 10),

            /// Surah List
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final surah = filtered[i];

                  return ListTile(
                    title: Text("${surah.number}. ${surah.name}"),
                    trailing: selectedSurah == surah.name
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        selectedSurah = surah.name;
                      });
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            /// Target count
            TextField(
              decoration: const InputDecoration(labelText: "Target Count"),
              keyboardType: TextInputType.number,
              onChanged: (v) => target = int.tryParse(v) ?? 1,
            ),

            const SizedBox(height: 10),

            /// Deadline toggle
            Row(
              children: [
                Checkbox(
                  value: useDeadline,
                  onChanged: (v) => setState(() => useDeadline = v!),
                ),
                const Text("Use Deadline"),
              ],
            ),

            if (useDeadline)
              TextButton(
                child: Text(
                  deadline == null
                      ? "Pick deadline"
                      : "${deadline!.year}-${deadline!.month}-${deadline!.day}",
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );

                  if (picked != null) {
                    setState(() => deadline = picked);
                  }
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),

        ElevatedButton(
          onPressed: selectedSurah == null
              ? null
              : () {
                  final surah = surahs.firstWhere(
                    (s) => s.name == selectedSurah,
                  );

                  Navigator.pop(context, {
                    "surahNumber": surah.number,
                    "surahName": surah.name,
                    "targetCount": target,
                    "deadline": useDeadline ? deadline : null,
                  });
                },
          child: const Text("Add"),
        ),
      ],
    );
  }
}
