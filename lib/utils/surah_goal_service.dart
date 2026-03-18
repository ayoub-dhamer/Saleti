import 'package:hive/hive.dart';
import 'package:saleti/features/quran/surah_goals_screen.dart';

class SurahGoalService {
  static const String _boxName = 'surah_goals';

  Future<Box<SurahGoal>> _box() async {
    return Hive.openBox<SurahGoal>(_boxName);
  }

  Future<List<SurahGoal>> getGoals() async {
    final box = await _box();
    return box.values.toList();
  }

  /// ✅ Allows same surah + same deadline if label differs
  Future<void> addGoal(
    int surahNumber,
    String surahName,
    int targetCount, {
    DateTime? deadline,
    required String label,
  }) async {
    final box = await _box();

    final goal = SurahGoal(
      surahNumber: surahNumber,
      surahName: surahName,
      targetCount: targetCount,
      deadline: deadline,
      label: label,
    );

    await box.add(goal); // ✅ ALWAYS adds a new goal
  }

  Future<void> incrementProgress(SurahGoal goal) async {
    if (goal.isCompleted || goal.isExpired) return;
    goal.completedCount++;
    await goal.save();
  }

  Future<void> deleteGoal(SurahGoal goal) async {
    await goal.delete();
  }

  Future<void> clearAll() async {
    final box = await _box();
    await box.clear();
  }
}

class DuplicateGoalException implements Exception {}
