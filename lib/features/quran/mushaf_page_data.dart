import 'package:quran/quran.dart';

class MushafPageData {
  static final Map<int, List<Map<String, int>>> pages = _buildPages();

  static Map<int, List<Map<String, int>>> _buildPages() {
    final Map<int, List<Map<String, int>>> result = {};

    for (int surah = 1; surah <= 114; surah++) {
      final verses = getVerseCount(surah);
      for (int ayah = 1; ayah <= verses; ayah++) {
        final page = getPageNumber(surah, ayah);
        result.putIfAbsent(page, () => []);
        result[page]!.add({'surah': surah, 'ayah': ayah});
      }
    }
    return result;
  }
}
