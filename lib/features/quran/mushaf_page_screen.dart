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
  final ReadingMode readingMode;
  final SurahGoal? surahGoal;
  final String
  storageKey; // e.g. 'last_read_general', 'last_jumped_page', 'last_read_khatm'
  final bool
  useLastReadPosition; // only true screens should resume from saved position

  const MushafPageScreen({
    super.key,
    this.startPage = 1,
    this.endPage,
    this.readingMode = ReadingMode.free,
    this.storageKey = 'last_read_general',
    this.surahGoal,
    this.useLastReadPosition = false,
  });

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  PageController? _pageController;
  int _currentPage = 1;
  Set<int> _bookmarkedPages = {};
  bool _isLectureMode = false;

  bool _isLastPage = false;

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  DateTime? _lastSnackTime;

  bool _isCorrectingPage = false;

  int get _firstPage {
    if (widget.readingMode == ReadingMode.free) {
      return 1;
    }
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

      // Resume from saved position for Khatm mode, or when explicitly requested
      if (widget.readingMode == ReadingMode.khatm ||
          widget.useLastReadPosition) {
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
          ? widget.startPage - 1
          : 0;

      _pageController = PageController(initialPage: initialIndex);
      _currentPage = _firstPage + initialIndex;
    }

    setState(() {});
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    if (_isLectureMode) {
      // Restore system UI in case the user backs out while still in lecture mode
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
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
    HapticFeedback.lightImpact();
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

    final pagesRead = _calculatePagesRead(
      _sessionStartPage,
      _sessionEndPage + 1,
    );

    if (pagesRead > 0) {
      await KhatmService().logPagesRead(pagesRead);
    }

    _sessionStartPage = 1;
    _sessionEndPage = 1;

    await _saveLastPage(1);
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
      return (604 - start) + end;
    }
  }

  Future<bool> _isLastKhatmCycle() async {
    final service = KhatmService();
    final active = await service.getActiveYear();

    if (active == null) return false;

    final totalPagesTarget = 604 * active.targetCompletions;
    final actualPages = (active.completedCycles * 604) + active.pagesReadTotal;

    // Use the page this session actually started from, not a stale/dead field
    return (actualPages + (604 - _sessionStartPage + 1)) >= totalPagesTarget;
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
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryGreen, secondaryGreen]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
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

              /// 🔍 Lecture Mode Toggle (the ONLY trigger for lecture mode)
              IconButton(
                onPressed: () => _toggleLectureMode(true),
                icon: const Icon(
                  Icons.fullscreen,
                  color: Colors.white,
                  size: 28,
                ),
                tooltip: 'Full Screen',
              ),

              const SizedBox(width: 8),

              /// 📄 Page Badge — animated on change
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Container(
                  key: ValueKey(_currentPage),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
              ),

              const SizedBox(width: 12),

              /// 🔖 Bookmark Button — bounce + haptic on toggle
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _toggleBookmark(_currentPage);
                },
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(isBookmarked),
                  tween: Tween(begin: 0.7, end: 1.0),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isBookmarked
                          ? Colors.amber.shade400
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
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
              ),
            ],
          ),

          const SizedBox(height: 14),

          /// 📊 Whole-mushaf progress line
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _currentPage / 604),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
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
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.menu_book_rounded, size: 48, color: primaryGreen),
              SizedBox(height: 16),
              CircularProgressIndicator(color: primaryGreen),
            ],
          ),
        ),
      );
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

        Navigator.pop(context, true);
        return false;
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: _isLectureMode ? Colors.black : Colors.white,
            appBar: _isLectureMode ? null : _buildAppBar(),
            body: Column(
              children: [
                // Animated header show/hide
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _isLectureMode ? 0 : 1,
                    child: _isLectureMode
                        ? const SizedBox.shrink()
                        : _buildSecondHeader(),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: _isLectureMode ? Colors.black : Colors.white,
                    child: _buildReadingArea(),
                  ),
                ),
              ],
            ),
          ),

          // Exit button in lecture mode
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

          // Go to First Page button (last page in Khatm mode)
          if (_isLastPage && widget.readingMode == ReadingMode.khatm)
            Positioned(
              bottom: 70,
              right: 10,
              child: _AnimatedActionButton(
                icon: Icons.restart_alt,
                label: 'Restart Cycle',
                onTap: () async {
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
                      Navigator.pop(context, true);
                    }
                  }
                },
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
                  padding: EdgeInsets.fromLTRB(
                    _isLectureMode ? 0 : 10,
                    _isLectureMode ? 0 : 6,
                    _isLectureMode ? 0 : 10,
                    _isLectureMode ? 0 : 66,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        _isLectureMode ? 0 : 14,
                      ),
                      boxShadow: _isLectureMode
                          ? const []
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        _isLectureMode ? 0 : 14,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/mushaf/$pageNumber.png',
                            fit: BoxFit.cover,
                          ),
                          if (!_isLectureMode)
                            IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.03),
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.03),
                                    ],
                                    stops: const [0, 0.06, 0.94, 1],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_isLastSurahPage && widget.surahGoal != null)
                  Positioned(
                    bottom: 70,
                    right: 10,
                    child: _AnimatedActionButton(
                      icon: Icons.check,
                      label: 'Count Recitation',
                      onTap: () async {
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
                          final service = SurahGoalService();
                          await service.incrementProgress(widget.surahGoal!);

                          if (!mounted) return;
                          Navigator.pop(context, true);
                        }
                      },
                    ),
                  ),
              ],
            );
          },
        ),

        // Fixed footer — animated show/hide
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            offset: _isLectureMode ? const Offset(0, 1) : Offset.zero,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isLectureMode ? 0 : 1,
              child: _buildFooter(),
            ),
          ),
        ),
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

                  final surahEntry = surahs.firstWhere(
                    (s) => s['english'] == widget.surahGoal!.surahName,
                    orElse: () => {"arabic": widget.surahGoal!.surahName},
                  );
                  final String arabicName = surahEntry['arabic']!;

                  if (liveProgress != null) {
                    final current = liveProgress['current'];
                    final total = liveProgress['total'];

                    return surahRowFromString(
                      "$arabicName $current / $total",
                      dimmed: false,
                    );
                  } else {
                    return surahRowFromString(arabicName, dimmed: true);
                  }
                } else {
                  if (surahsInFooter.isEmpty) return const SizedBox();
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      surahRowFromString(surahsInFooter[0]),
                      if (surahsInFooter.length > 1)
                        surahRowFromString(surahsInFooter[1]),
                      if (surahsInFooter.length > 2)
                        surahRowFromString(surahsInFooter[2]),
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
    final surahEntry = surahs.firstWhere(
      (s) => s['english'] == englishName,
      orElse: () => {},
    );
    if (surahEntry.isEmpty) return null;
    final String arabicGoalName = surahEntry['arabic']!;

    final pageData = footerList[page];
    if (pageData == null) return null;

    final List<String> surahsOnPage = List<String>.from(
      pageData['surahs'] ?? [],
    );

    final String match = surahsOnPage.firstWhere(
      (s) => s.contains(arabicGoalName),
      orElse: () => "",
    );

    if (match.isEmpty) return null;

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
    final regex = RegExp(r'(.+?)\s+(\d+)\s*/\s*(\d+)$');
    final match = regex.firstMatch(input.trim());

    if (match == null) {
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
      height: 18,
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
                fontSize: 11,
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

/// Shared animated pill-button used for the "Restart Cycle" / "Count Recitation" actions.
/// Styled to match the app's green gradient identity, with a slide-up entrance.
class _AnimatedActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AnimatedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * 40),
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primaryGreen, secondaryGreen],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    return SurahProgress(input, 0, 1);
  }

  return SurahProgress(
    match.group(1)!.trim(),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}
