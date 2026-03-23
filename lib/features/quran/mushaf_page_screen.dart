import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saleti/data/footer_list.dart';
import 'package:saleti/data/surah_page_map.dart';
import 'package:saleti/data/surahs_names.dart';
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/features/quran/surah_goals_screen.dart';
import 'package:saleti/utils/khatm_service.dart';
import 'package:saleti/utils/surah_goal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MushafPageScreen extends StatefulWidget {
  final int startPage;
  final int? endPage;
  final int? initialSurah;
  final ReadingMode readingMode;

  final SurahGoal? surahGoal;

  final int initialPage; // <-- ADD THIS

  final String? surahName;

  final String
  storageKey; // Add this: e.g., 'last_read_general' or 'last_read_khatm'

  const MushafPageScreen({
    super.key,
    this.startPage = 1,
    this.endPage,
    this.initialSurah,
    this.readingMode = ReadingMode.free,
    this.surahName, // default is free
    this.initialPage = 1,
    this.storageKey = 'last_read_general',
    this.surahGoal, // Default to general
  });

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  PageController? _pageController;
  int _currentPage = 1;
  Set<int> _bookmarkedPages = {};
  bool _isLectureMode = false;

  int _lastLoggedPage = 1; // Track last logged page for Khatm

  bool _isLastPage = false;

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  DateTime? _lastSnackTime;

  bool _isCorrectingPage = false;

  int get _firstPage {
    if (widget.readingMode == ReadingMode.free) {
      return 1;
    }
    // pointer and other modes start from startPage
    return widget.startPage;
  }

  int get _lastPage {
    if (widget.readingMode == ReadingMode.free ||
        widget.readingMode == ReadingMode.pointer) {
      return 604;
    }
    return widget.endPage ?? 604;
  }

  int get _pageCount => _lastPage - _firstPage + 1;

  int _sessionStartPage = 1;
  int _sessionEndPage = 1;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initPage();
    _loadBookmarks();

    _initPageController();
  }

  Future<void> _initPageController() async {
    if (widget.readingMode != ReadingMode.goal) {
      final int initialPage;

      if (widget.readingMode == ReadingMode.khatm) {
        initialPage = await _loadLastPage();
      } else {
        initialPage = widget.startPage;
      }

      final initialIndex = initialPage - 1;

      _pageController = PageController(initialPage: initialIndex);

      _currentPage = initialPage;
      _sessionStartPage = initialPage;
      _sessionEndPage = initialPage;

      _isLastPage =
          widget.readingMode == ReadingMode.khatm && _currentPage == 604;
    } else {
      final initialIndex = widget.readingMode == ReadingMode.free
          ? widget.startPage -
                1 // jump to surah start
          : 0;

      _pageController = PageController(initialPage: initialIndex);

      // ✅ Set current page correctly
      _currentPage = _firstPage + initialIndex;
    }

    setState(() {});
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _initPage() async {
    final initialPage = await _loadLastPage();

    _sessionStartPage = initialPage;
    _sessionEndPage = initialPage;

    setState(() {});
  }

  void _toggleLectureMode(bool enable) {
    setState(() => _isLectureMode = enable);
    if (enable) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];
    final pages = <int>{};
    for (final item in list) {
      final parts = item.split('|');
      if (parts.length == 3) {
        final page = int.tryParse(parts[0]);
        if (page != null) pages.add(page);
      }
    }
    setState(() => _bookmarkedPages = pages);
  }

  Future<void> _saveLastPage(int page) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(widget.storageKey, page);
  }

  Future<int> _loadLastPage({int? overridePage}) async {
    final prefs = await SharedPreferences.getInstance();

    if (overridePage != null) return overridePage;

    return prefs.getInt(widget.storageKey) ?? widget.startPage;
  }

  Future<void> _toggleBookmark(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    final existsIndex = list.indexWhere(
      (e) => e.split('|')[0] == page.toString(),
    );

    if (existsIndex >= 0) {
      list.removeAt(existsIndex);
    } else {
      final now = DateTime.now();

      final dateTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      // ✅ Replace this with real surah lookup later if you want
      final surahName = _getSurahNameFromPage(page);

      list.add('$page|$surahName|$dateTime');
    }

    await prefs.setStringList('mushaf_bookmarks', list);
    await _loadBookmarks();
  }

  String _getSurahNameFromPage(int page) {
    int closestPage = 1;

    for (final p in surahByPage.keys) {
      if (p <= page && p >= closestPage) {
        closestPage = p;
      }
    }

    return surahByPage[closestPage] ?? 'Unknown Surah';
  }

  Future<void> _goToFirstPage() async {
    if (widget.readingMode != ReadingMode.khatm) return;

    // 1️⃣ Commit pages read in this session
    final pagesRead = _calculatePagesRead(
      _sessionStartPage,
      _sessionEndPage + 1,
    );

    if (pagesRead > 0) {
      await KhatmService().logPagesRead(pagesRead);
    }

    // 2️⃣ HARD reset session
    _sessionStartPage = 1;
    _sessionEndPage = 1;
    _lastLoggedPage = 1;

    await _saveLastPage(1);

    // 3️⃣ Jump to first page
    _pageController?.jumpToPage(0);

    setState(() {
      _currentPage = 1;
      _isLastPage = false;
    });
  }

  int _calculatePagesRead(int start, int end) {
    if (end >= start) {
      return end - start;
    } else {
      // Cycle wrap
      return (604 - start) + end;
    }
  }

  Future<bool> _isLastKhatmCycle() async {
    final service = KhatmService();
    final active = await service.getActiveYear();

    if (active == null) return false;

    final totalPagesTarget = 604 * active.targetCompletions;
    final actualPages = (active.completedCycles * 604) + active.pagesReadTotal;

    // We are ABOUT to finish one more cycle
    return (actualPages + (604 - _lastLoggedPage + 1)) >= totalPagesTarget;
  }

  bool get _isLastSurahPage {
    if (widget.endPage == null) return false;
    return _currentPage == widget.endPage;
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      title: const Text(
        'Al-Qur’an',
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
    );
  }

  Widget _buildSecondHeader() {
    final isBookmarked = _bookmarkedPages.contains(_currentPage);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryGreen, secondaryGreen]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          /// 📖 Page Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                const Text(
                  'Swipe to continue reading',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          /// 🔍 Lecture Mode Toggle
          IconButton(
            onPressed: () => _toggleLectureMode(true),
            icon: const Icon(Icons.fullscreen, color: Colors.white, size: 28),
            tooltip: 'Full Screen',
          ),

          const SizedBox(width: 8),

          /// 📄 Page Badge (Restored)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              '$_currentPage / 604',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(width: 12),

          /// 🔖 Bookmark Button with "Save" text (Restored)
          GestureDetector(
            onTap: () => _toggleBookmark(_currentPage),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isBookmarked
                    ? Colors.amber.shade400
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                    size: 18,
                    color: isBookmarked ? Colors.black : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isBookmarked ? 'Saved' : 'Save',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isBookmarked ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pageController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return WillPopScope(
      onWillPop: () async {
        if (widget.readingMode == ReadingMode.khatm) {
          final pagesRead = _calculatePagesRead(
            _sessionStartPage,
            _sessionEndPage,
          );
          if (pagesRead > 0) {
            await KhatmService().logPagesRead(pagesRead);
          }
        }

        Navigator.pop(context, true); // signal Khatm screen to refresh
        return false; // prevent default pop
      },
      child: Stack(
        children: [
          // 🔹 Your main Scaffold
          Scaffold(
            backgroundColor: _isLectureMode ? Colors.black : Colors.white,
            appBar: _isLectureMode ? null : _buildAppBar(),
            body: Column(
              children: [
                if (!_isLectureMode) _buildSecondHeader(),
                Expanded(
                  child: Container(
                    color: Colors.white, // prevents background gap
                    child: _buildReadingArea(),
                  ),
                ),
              ],
            ),
          ),

          // 🔹 Exit button in lecture mode
          if (_isLectureMode)
            Positioned(
              top: 50,
              left: 20,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _toggleLectureMode(false),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

          // 🔹 Go to First Page Button (last page in Khatm mode)
          if (_isLastPage && widget.readingMode == ReadingMode.khatm)
            Positioned(
              bottom: 70,
              right: 10,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isLastPage ? 1 : 0,
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Finish Cycle?'),
                        content: const Text(
                          'You have reached the last page. Do you want to finish this cycle and go back to page 1?',
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
                      final isLastCycle = await _isLastKhatmCycle();

                      await _goToFirstPage();

                      if (!mounted) return;

                      if (isLastCycle) {
                        Navigator.pop(
                          context,
                          true,
                        ); // exit and refresh Khatm screen
                      }
                    }
                  },
                  label: const Text('Restart Cycle'),
                  icon: const Icon(Icons.restart_alt),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSnackOnce(String message) {
    final now = DateTime.now();

    if (_lastSnackTime != null &&
        now.difference(_lastSnackTime!) < const Duration(seconds: 2)) {
      return;
    }

    _lastSnackTime = now;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildReadingArea() {
    return Stack(
      children: [
        // Swipable pages
        PageView.builder(
          controller: _pageController,
          reverse: true,
          itemCount: _pageCount,
          onPageChanged: (index) {
            final page = _firstPage + index;

            if (widget.readingMode == ReadingMode.khatm &&
                page < _sessionStartPage) {
              if (_isCorrectingPage) return;

              _isCorrectingPage = true;
              final safeIndex = _sessionStartPage - _firstPage;

              HapticFeedback.lightImpact();
              _pageController!
                  .animateToPage(
                    safeIndex,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                  )
                  .whenComplete(() => _isCorrectingPage = false);

              _showSnackOnce('You cannot go before your Khatm starting page');
              return;
            }

            setState(() {
              _currentPage = page;
              _sessionEndPage = page;
              _isLastPage = page == 604;
            });

            _saveLastPage(page);
          },
          itemBuilder: (context, index) {
            final pageNumber = _firstPage + index;

            return Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 60), // footer space
                  child: Image.asset(
                    'assets/mushaf/$pageNumber.png',
                    fit: BoxFit.cover,
                  ),
                ),

                if (_isLastSurahPage && widget.surahGoal != null)
                  Positioned(
                    bottom: 70,
                    right: 10,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _isLastSurahPage ? 1 : 0,
                      child: FloatingActionButton.extended(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Mark Surah Completed?'),
                              content: Text(
                                'You reached the end of ${widget.surahGoal!.surahName}. '
                                'Do you want to count this recitation toward your goal?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
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
                            final service = SurahGoalService();
                            await service.incrementProgress(widget.surahGoal!);

                            if (!mounted) return;

                            Navigator.pop(
                              context,
                              true,
                            ); // ✅ return success to previous screen
                          }
                        },
                        label: const Text('Count Recitation'),
                        icon: const Icon(Icons.check),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        // Fixed footer
        Positioned(left: 0, right: 0, bottom: 0, child: _buildFooter()),
      ],
    );
  }

  Widget _buildFooter() {
    final footer = footerList[_currentPage];
    if (footer == null) return const SizedBox.shrink();

    final List<String> surahsInFooter = List<String>.from(
      footer['surahs'] ?? const [],
    );
    final String? nextSurah = footer['nextSurah'];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          /// ▶️ LEFT — Next surah
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: widget.readingMode == ReadingMode.goal || nextSurah == null
                  ? const SizedBox()
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.navigate_next_rounded,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            nextSurah,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          /// 🔢 CENTER — Page number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              '$_currentPage',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),

          /// ◀️ RIGHT — Progress Bar Logic
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: () {
                if (widget.readingMode == ReadingMode.goal &&
                    widget.surahGoal != null) {
                  final liveProgress = getSurahProgressFromPage(
                    _currentPage,
                    widget.surahGoal!.surahName,
                  );

                  // 1. Get the Arabic name
                  final surahEntry = surahs.firstWhere(
                    (s) => s['english'] == widget.surahGoal!.surahName,
                    orElse: () => {"arabic": widget.surahGoal!.surahName},
                  );
                  final String arabicName = surahEntry['arabic']!;

                  // 2. If we found page progress in the footerList, show IT (e.g., 1/2)
                  if (liveProgress != null) {
                    final current =
                        liveProgress['current']; // Current page of surah
                    final total = liveProgress['total']; // Total pages of surah

                    return surahRowFromString(
                      "$arabicName $current / $total",
                      dimmed: false,
                    );
                  } else {
                    // 3. If the surah isn't on this page, just show the name
                    // without the "X/Y" completion goal numbers.
                    return surahRowFromString(arabicName, dimmed: true);
                  }
                } else {
                  // Fallback for free/khatm mode
                  if (surahsInFooter.isEmpty) return const SizedBox();
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      surahRowFromString(surahsInFooter[0]),
                      if (surahsInFooter.length > 1)
                        surahRowFromString(surahsInFooter[1]),
                    ],
                  );
                }
              }(),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int>? getSurahProgressFromPage(int page, String englishName) {
    // 1. Get the Arabic name from your master names list
    final surahEntry = surahs.firstWhere(
      (s) => s['english'] == englishName,
      orElse: () => {},
    );
    if (surahEntry.isEmpty) return null;
    final String arabicGoalName = surahEntry['arabic']!;

    // 2. Access the footer data for the current page
    final pageData = footerList[page];
    if (pageData == null) return null;

    // 3. Cast the surahs on this page to a List of Strings
    final List<String> surahsOnPage = List<String>.from(
      pageData['surahs'] ?? [],
    );

    // 4. FIND THE MATCH:
    // We look specifically for the string that contains our Arabic Goal Name
    final String match = surahsOnPage.firstWhere(
      (s) => s.contains(arabicGoalName),
      orElse: () => "",
    );

    if (match.isEmpty) return null;

    // 5. EXTRACT the "x/y" from the matched string (e.g., "البينة 1/2")
    final regExp = RegExp(r'(\d+)\s*/\s*(\d+)');
    final helperMatch = regExp.firstMatch(match);

    if (helperMatch != null) {
      return {
        "current": int.parse(helperMatch.group(1)!),
        "total": int.parse(helperMatch.group(2)!),
      };
    }

    return null;
  }

  SurahProgress parseSurah(String input) {
    // Added \s* around the slash to handle varied spacing
    final regex = RegExp(r'(.+?)\s+(\d+)\s*/\s*(\d+)$');
    final match = regex.firstMatch(input.trim());

    if (match == null) {
      // If it's just a name without numbers (like in free mode)
      return SurahProgress(input, 0, 0);
    }

    return SurahProgress(
      match.group(1)!.trim(),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  Widget surahProgressBar({
    required int current,
    required int total,
    bool dimmed = false,
  }) {
    final progress = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);

    return SizedBox(
      width: 90,
      height: 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1
                    ? Colors.amber
                    : (dimmed ? Colors.white38 : Colors.white),
              ),
              minHeight: 12,
            ),
          ),
          Text(
            '$current / $total',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget surahRowFromString(String raw, {bool dimmed = false}) {
    final parsed = parseSurah(raw);

    return SizedBox(
      height: 18, // 🔑 hard cap per row
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              parsed.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: dimmed ? Colors.white70 : Colors.white,
                fontSize: 11, // 🔽 smaller
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _compactProgressBar(
            current: parsed.current,
            total: parsed.total,
            dimmed: dimmed,
          ),
        ],
      ),
    );
  }

  Widget _compactProgressBar({
    required int current,
    required int total,
    bool dimmed = false,
  }) {
    final progress = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);

    return SizedBox(
      width: 70,
      height: 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1
                    ? Colors.amber
                    : (dimmed ? Colors.white38 : Colors.white),
              ),
              minHeight: 10,
            ),
          ),
          Text(
            '$current/$total',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class SurahProgress {
  final String name;
  final int current;
  final int total;

  SurahProgress(this.name, this.current, this.total);
}

SurahProgress parseSurah(String input) {
  final regex = RegExp(r'(.+?)\s+(\d+)\s*/\s*(\d+)$');
  final match = regex.firstMatch(input);

  if (match == null) {
    return SurahProgress(input, 0, 1); // fallback
  }

  return SurahProgress(
    match.group(1)!.trim(), // surah name
    int.parse(match.group(2)!), // x
    int.parse(match.group(3)!), // y
  );
}
