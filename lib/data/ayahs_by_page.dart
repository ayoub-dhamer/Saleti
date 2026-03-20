/// Mapping of Mushaf page → List of ayahs on that page
/// Each ayah contains surah number and ayah number
/// Example: page 1 has surah 1, ayahs 1-7
final Map<int, List<Map<String, int>>> ayahsByPage = {
  1: [
    {'surah': 1, 'ayah': 1},
    {'surah': 1, 'ayah': 2},
    {'surah': 1, 'ayah': 3},
    {'surah': 1, 'ayah': 4},
    {'surah': 1, 'ayah': 5},
    {'surah': 1, 'ayah': 6},
    {'surah': 1, 'ayah': 7},
  ],
  2: [
    {'surah': 2, 'ayah': 1},
    {'surah': 2, 'ayah': 2},
    {'surah': 2, 'ayah': 3},
    {'surah': 2, 'ayah': 4},
    {'surah': 2, 'ayah': 5},
    {'surah': 2, 'ayah': 6},
    {'surah': 2, 'ayah': 7},
    {'surah': 2, 'ayah': 8},
    {'surah': 2, 'ayah': 9},
    {'surah': 2, 'ayah': 10},
    // continue sequentially until page 2 ends
  ],
  // ...
  604: [
    {'surah': 114, 'ayah': 1},
    {'surah': 114, 'ayah': 2},
    {'surah': 114, 'ayah': 3},
    {'surah': 114, 'ayah': 4},
    {'surah': 114, 'ayah': 5},
    {'surah': 114, 'ayah': 6},
  ],
};
