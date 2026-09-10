/// Standard 604-page Madinah Mushaf juz boundaries — the page each juz
/// (1-30) begins on. These are fixed across all standard-layout prints,
/// unrelated to the specific text/translation edition.
const Map<int, int> juzStartPages = {
  1: 1,
  2: 22,
  3: 42,
  4: 62,
  5: 82,
  6: 102,
  7: 121,
  8: 142,
  9: 162,
  10: 182,
  11: 201,
  12: 222,
  13: 242,
  14: 262,
  15: 282,
  16: 302,
  17: 322,
  18: 342,
  19: 362,
  20: 382,
  21: 402,
  22: 422,
  23: 442,
  24: 462,
  25: 482,
  26: 502,
  27: 522,
  28: 542,
  29: 562,
  30: 582,
};

/// Returns which juz (1-30) a given mushaf page number falls within.
int juzForPage(int pageNumber) {
  int result = 1;
  juzStartPages.forEach((juz, startPage) {
    if (pageNumber >= startPage) result = juz;
  });
  return result;
}
