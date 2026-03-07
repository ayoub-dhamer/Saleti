import 'package:collection/collection.dart';
import 'package:hive/hive.dart';
import 'package:saleti/features/quran/surah_goals_screen.dart';

class SurahGoalService {
  static const String _boxName = 'surah_goals';

  /// Get all goals from Hive
  Future<List<SurahGoal>> getGoals() async {
    final box = await Hive.openBox<SurahGoal>(_boxName);
    return box.values.toList();
  }

  Future<void> registerSurahCompletion(int surahNumber) async {
    final box = Hive.box<SurahGoal>('surah_goals');

    final goal = box.values.firstWhereOrNull(
      (g) => g.surahNumber == surahNumber,
    );

    if (goal == null || goal.isCompleted || goal.isExpired) return;

    goal.completedCount++;

    await goal.save();
  }

  /// Add a new goal
  Future<void> addGoal(
    int surahNumber,
    String surahName,
    int targetCount, {
    DateTime? deadline,
  }) async {
    final box = Hive.box<SurahGoal>('surah_goals');

    final existing = box.values.firstWhereOrNull(
      (g) => g.surahNumber == surahNumber,
    );

    if (existing != null) {
      existing.targetCount = targetCount;
      existing.deadline = deadline;
      await existing.save();
      return;
    }

    final goal = SurahGoal(
      surahNumber: surahNumber,
      surahName: surahName,
      targetCount: targetCount,
      deadline: deadline,
    );

    await box.add(goal);
  }

  /// Increment progress of a goal by 1
  Future<void> incrementProgress(SurahGoal goal) async {
    final box = await Hive.openBox<SurahGoal>(_boxName);

    // If goal is completed or expired, do nothing
    if (goal.isCompleted || goal.isExpired) return;

    goal.completedCount += 1;
    await goal.save();
  }

  /// Delete a goal
  Future<void> deleteGoal(SurahGoal goal) async {
    await goal.delete();
  }

  /// Optional: find goal by surah name
  Future<SurahGoal?> getGoal(String surahName) async {
    final box = await Hive.openBox<SurahGoal>(_boxName);
    return box.values.firstWhereOrNull((g) => g.surahName == surahName);
  }

  /// Optional: clear all goals
  Future<void> clearAll() async {
    final box = await Hive.openBox<SurahGoal>(_boxName);
    await box.clear();
  }
}
