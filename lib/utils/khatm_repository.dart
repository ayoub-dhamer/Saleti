import 'package:hive/hive.dart';
import '../features/quran/khatm_screen.dart';

class KhatmRepository {
  final _yearBox = Hive.box<KhatmYear>('khatm_years');
  final _logBox = Hive.box<DailyKhatmLog>('khatm_logs');

  KhatmYear? get activeYear {
    for (var y in _yearBox.values) {
      if (y.isActive) return y;
    }
    return null;
  }

  List<KhatmYear> get history =>
      _yearBox.values.where((y) => !y.isActive).toList();

  Future<void> saveYear(KhatmYear year) async => year.save();

  Future<void> addDailyLog(DailyKhatmLog log) async =>
      _logBox.put('${log.year}-${log.date}', log);

  DailyKhatmLog? getLog(int year, String date) => _logBox.get('$year-$date');

  Future<void> deactivateAll() async {
    for (final y in _yearBox.values) {
      if (y.isActive) {
        y.isActive = false;
        y.endDate = DateTime.now();
        await y.save();
      }
    }
  }
}
