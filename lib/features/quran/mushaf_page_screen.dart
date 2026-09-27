import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart' as quran;
import 'package:saleti/data/footer_list.dart';
import 'package:saleti/data/surah_pages.dart';
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/features/quran/surah_goals_screen.dart';
import 'package:saleti/utils/khatm_service.dart';
import 'package:saleti/utils/surah_goal_service.dart';
import 'package:saleti/widgets/icon_action.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:saleti/utils/mushaf_data_service.dart';
import 'package:saleti/features/quran/mushaf_text_page.dart';

class MushafPageScreen extends StatefulWidget {
  final int startPage;
  final int? endPage;
  final ReadingMode readingMode;
  final SurahGoal? surahGoal;
  final String storageKey;
  final bool useLastReadPosition;

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

class _MushafPageScreenState extends State<MushafPageScreen>
    with WidgetsBindingObserver {
  PageController? _pageController;
  int _currentPage = 1;
  Set<int> _bookmarkedPages = {};
  bool _isLectureMode = false;

  bool _isLastPage = false;
  bool _isPageSettled = true;

  KhatmYear? _khatmYear;

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  int get _firstPage {
    if (widget.readingMode == ReadingMode.free) {
      return 1;
    }
    if (widget.readingMode == ReadingMode.khatm) {
      return _sessionStartPage;
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

  // FIXED (bug #7): tracks how far Khatm progress has actually been
  // persisted into KhatmService so far *this session*, separately from
  // _sessionStartPage (which must stay fixed — it anchors _firstPage and
  // the PageView's index mapping for the whole life of this screen).
  // Advances every time _checkpointKhatmProgress succeeds, so a periodic
  // checkpoint, a pause, and the final pop-time flush never re-count the
  // same pages twice.
  int _lastCheckpointedPage = 1;
  bool _isCheckpointing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _initPage();
    _loadBookmarks();
    _initPageController();
    if (widget.readingMode == ReadingMode.khatm) {
      _loadKhatmYear();
    }
    MushafDataService().load().then((_) {
      if (mounted) setState(() {});
    });
    MushafDataService().addListener(_onMushafDataChanged); // ADD
  }

  // FIXED (bug #7): previously, Khatm progress for the whole session was
  // only ever written to KhatmService from the back-button's PopScope
  // handler — a process kill, a swipe-away from recents, or a crash while
  // reading discarded the entire session's progress even though
  // _saveLastPage had already correctly remembered which page to resume
  // from. AppLifecycleState.paused fires reliably before Android is free
  // to kill the process (unlike a plain dispose(), which isn't guaranteed
  // to run at all), so flushing here — in addition to the periodic
  // checkpoint in onPageChanged below — shrinks the at-risk window from
  // "the whole session" to "at most a few pages".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _checkpointKhatmProgress();
    }
  }

  void _onMushafDataChanged() {
    // ADD
    if (mounted) setState(() {});
  }

  Future<void> _loadKhatmYear() async {
    final year = await KhatmService().getActiveYear();
    if (mounted) setState(() => _khatmYear = year);
  }

  int? get _khatmPaceDiff {
    final year = _khatmYear;
    if (year == null) return null;

    final today = DateTime.now();
    final daysElapsed = today.isBefore(year.startDate)
        ? 0
        : today.difference(year.startDate).inDays + 1;

    final expectedPages = (daysElapsed * year.pagesPerDay).clamp(
      0,
      604 * year.targetCompletions,
    );
    // FIXED (bug #7): was _calculatePagesRead(_sessionStartPage, _currentPage).
    // Now that progress checkpoints periodically into year.pagesReadTotal
    // (read live below, since KhatmService mutates the same cached Hive
    // object this screen already holds), counting from _sessionStartPage
    // again here would double-count whatever's already been checkpointed.
    // _lastCheckpointedPage tracks exactly what's left to add on top.
    final pagesReadThisSession = _calculatePagesRead(
      _lastCheckpointedPage,
      _currentPage,
    );
    final liveActualPages =
        (year.completedCycles * 604) +
        year.pagesReadTotal +
        pagesReadThisSession;

    return liveActualPages - expectedPages;
  }

  Future<void> _initPageController() async {
    if (widget.readingMode != ReadingMode.goal) {
      final int initialPage;

      if (widget.readingMode == ReadingMode.khatm ||
          widget.useLastReadPosition) {
        initialPage = await _loadLastPage();
      } else {
        initialPage = widget.startPage;
      }

      _currentPage = initialPage;
      _sessionStartPage = initialPage;
      _sessionEndPage = initialPage;
      _lastCheckpointedPage = initialPage;

      final initialIndex = initialPage - _firstPage;

      _pageController = PageController(initialPage: initialIndex);

      _isLastPage =
          widget.readingMode == ReadingMode.khatm && _currentPage == 604;
    } else {
      final initialIndex = widget.readingMode == ReadingMode.free
          ? widget.startPage - 1
          : 0;

      _pageController = PageController(initialPage: initialIndex);
      _currentPage = _firstPage + initialIndex;
    }

    _pageController!.addListener(_handleScrollSettleCheck);

    setState(() {});
  }

  void _handleScrollSettleCheck() {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;

    final rawPage = controller.page;
    if (rawPage == null) return;

    final settled = (rawPage - rawPage.roundToDouble()).abs() < 0.001;

    if (settled != _isPageSettled) {
      setState(() => _isPageSettled = settled);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MushafDataService().removeListener(_onMushafDataChanged); // ADD

    WakelockPlus.disable();
    if (_isLectureMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _pageController?.removeListener(_handleScrollSettleCheck);
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _initPage() async {
    final initialPage = await _loadLastPage();
    _sessionStartPage = initialPage;
    _sessionEndPage = initialPage;
    _lastCheckpointedPage = initialPage;
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
    for (int i = 114; i >= 1; i--) {
      final start = surahStartPages[i] ?? 1;
      if (page >= start) return quran.getSurahName(i);
    }
    return 'Unknown Surah';
  }

  Future<void> _goToFirstPage() async {
    if (widget.readingMode != ReadingMode.khatm) return;

    // FIXED (bug #7): was _calculatePagesRead(_sessionStartPage,
    // _sessionEndPage + 1) — logging the whole session from its start
    // again here, ignoring anything periodic/pause checkpoints had
    // already flushed via _lastCheckpointedPage, would double-count them.
    await _checkpointKhatmProgress(upToPage: _sessionEndPage + 1);

    _sessionStartPage = 1;
    _sessionEndPage = 1;
    _lastCheckpointedPage = 1;

    await _saveLastPage(1);
    _pageController?.jumpToPage(0);

    setState(() {
      _currentPage = 1;
      _isLastPage = false;
    });
  }

  /// FIXED (bug #7): single place that persists Khatm progress, used by
  /// the periodic per-page checkpoint, the app-pause checkpoint, the
  /// pop-time flush, and _goToFirstPage — instead of each of those
  /// re-deriving "pages read" from _sessionStartPage independently (which
  /// is what let a process kill discard everything, since only the pop
  /// handler ever actually saved it). Guarded against re-entrancy and
  /// against no-op (already caught up) calls.
  Future<void> _checkpointKhatmProgress({int? upToPage}) async {
    if (widget.readingMode != ReadingMode.khatm || _isCheckpointing) return;

    final target = upToPage ?? _currentPage;
    final pagesRead = _calculatePagesRead(_lastCheckpointedPage, target);
    if (pagesRead <= 0) return;

    _isCheckpointing = true;
    try {
      await KhatmService().logPagesRead(pagesRead);
      _lastCheckpointedPage = target;
    } catch (e) {
      debugPrint('Failed to save khatm progress: $e');
    } finally {
      _isCheckpointing = false;
    }
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

    // FIXED (bug #7): was `604 - _sessionStartPage + 1`. active.pagesReadTotal
    // above is read live off the same Hive object KhatmService mutates, so
    // it already reflects anything this session's periodic/pause
    // checkpoints have flushed. Counting the full span from
    // _sessionStartPage again would double-count that portion —
    // _lastCheckpointedPage is the actual not-yet-recorded remainder.
    return (actualPages + (604 - _lastCheckpointedPage + 1)) >=
        totalPagesTarget;
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
        'Al-Qur\'an',
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'Swipe to flip pages',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
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
        ],
      ),
    );
  }

  // In mushaf_page_screen.dart - Replace the Stack children overlay in build():

  // In mushaf_page_screen.dart

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Resolve background and text colors dynamically for lecture mode
    final lectureBgColor = theme.scaffoldBackgroundColor;
    final lectureTextColor = isDarkMode ? Colors.white : Colors.black;

    if (_pageController == null || !MushafDataService().isLoaded) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
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

    return PopScope(
      // FIXED (bug #7): was unconditionally `false`, which also disables
      // Android 13+'s predictive-back preview in every reading mode, even
      // the ones (free/pointer/goal) that have no async work to do before
      // popping. Only Khatm mode still needs to intercept the pop to
      // flush progress first.
      canPop: widget.readingMode != ReadingMode.khatm,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // FIXED (bug #7): wrapped in try/finally so a failure in the
        // checkpoint (e.g. a Hive write error) can never leave this
        // screen stuck refusing to pop — the whole point of canPop:false
        // here is to delay the pop briefly, not to block it. Most of a
        // session's progress is normally already saved by the periodic
        // and pause checkpoints above by the time this runs, so this is
        // now a small top-up flush rather than the only save point.
        try {
          await _checkpointKhatmProgress();
        } finally {
          if (context.mounted) Navigator.pop(context, true);
        }
      },
      child: Stack(
        children: [
          Scaffold(
            // Use theme scaffold background color instead of hardcoded black
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: _isLectureMode ? null : _buildAppBar(),
            body: Column(
              children: [
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
                    color: theme.scaffoldBackgroundColor,
                    child: _buildReadingArea(lectureTextColor, lectureBgColor),
                  ),
                ),
              ],
            ),
          ),

          // TOP BAR OVERLAY FOR LECTURE MODE
          if (_isLectureMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconAction(
                    label: 'Exit full screen',
                    onTap: () => _toggleLectureMode(false),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.black54 : Colors.white70,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode ? Colors.white24 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.close,
                        color: isDarkMode ? Colors.white : Colors.black,
                        size: 22,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (widget.readingMode == ReadingMode.khatm) ...[
                    _buildKhatmPaceIndicator(
                      BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.18)
                            : Colors.black.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDarkMode ? Colors.white24 : Colors.black12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.black54 : Colors.white70,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    child: Text(
                      '$_currentPage / 604',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_isLastPage &&
              _isPageSettled &&
              widget.readingMode == ReadingMode.khatm)
            Positioned(
              bottom: _isLectureMode ? 10 : 67,
              left: 10,
              child: SizedBox(
                height: 35,
                child: _AnimatedActionButton(
                  label: 'Restart Cycle',
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: theme.cardColor, // CHANGED
                        title: Text(
                          'Finish Cycle?',
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ), // CHANGED
                        content: Text(
                          'You have reached the last page. Do you want to finish this cycle and go back to page 1?',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7),
                          ), // CHANGED
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
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
                      final isLastCycle = await _isLastKhatmCycle();
                      await _goToFirstPage();
                      if (!context.mounted) return;
                      if (isLastCycle) {
                        Navigator.pop(context, true);
                      }
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReadingArea(Color lectureTextColor, Color lectureBgColor) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          reverse: true,
          itemCount: _pageCount,
          onPageChanged: (index) {
            final page = _firstPage + index;

            setState(() {
              _currentPage = page;
              _sessionEndPage = page;
              _isLastPage = page == 604;
            });

            _saveLastPage(page);

            // FIXED (bug #7): periodic checkpoint every ~5 pages, so a
            // process kill mid-session loses at most a handful of pages
            // instead of the whole session. Fire-and-forget, same as
            // _saveLastPage above — this callback isn't async.
            if (widget.readingMode == ReadingMode.khatm &&
                _calculatePagesRead(_lastCheckpointedPage, page) >= 5) {
              _checkpointKhatmProgress();
            }
          },
          itemBuilder: (context, index) {
            final pageNumber = _firstPage + index;

            return Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    0,
                    0,
                    _isLectureMode ? 0 : 64,
                  ),
                  child: Container(
                    // FIX: Use lectureBgColor instead of hardcoded Colors.black
                    color: _isLectureMode
                        ? lectureBgColor
                        : Theme.of(context).scaffoldBackgroundColor,
                    child: MushafTextPage(
                      pageNumber: pageNumber,
                      isLectureMode: _isLectureMode,
                      textColor: _isLectureMode
                          ? lectureTextColor
                          : (Theme.of(context).textTheme.bodyLarge?.color ??
                                Colors.black),
                      accentColor: primaryGreen,
                    ),
                  ),
                ),

                if (_isLastSurahPage &&
                    _isPageSettled &&
                    widget.surahGoal != null)
                  Positioned(
                    bottom: _isLectureMode ? 10 : 67,
                    left: 10,
                    child: SizedBox(
                      height: 35,
                      child: _AnimatedActionButton(
                        label: 'Count Recitation',
                        onTap: () async {
                          final theme = Theme.of(context);
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: theme.cardColor,
                              title: Text(
                                'Mark Surah Completed?',
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              content: Text(
                                'You reached the end of ${widget.surahGoal!.surahName}. '
                                'Do you want to count this recitation toward your goal?',
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.7),
                                ),
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
                            final service = SurahGoalService();
                            await service.incrementProgress(widget.surahGoal!);

                            if (!context.mounted) return;
                            Navigator.pop(context, true);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

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
    final bool isKhatm = widget.readingMode == ReadingMode.khatm;

    final badgeDecoration = BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
    );

    final Widget infoRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: widget.readingMode == ReadingMode.goal || nextSurah == null
                ? const SizedBox.shrink()
                : Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: badgeDecoration,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Next',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              nextSurah,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: surahsInFooter.length > 1 ? 2 : 1,
          child: Align(
            alignment: Alignment.centerRight,
            child: () {
              if (widget.readingMode == ReadingMode.goal &&
                  widget.surahGoal != null) {
                final liveProgress = getSurahProgressFromPage(
                  _currentPage,
                  widget.surahGoal!.surahNumber,
                );

                final String arabicName = quran.getSurahNameArabic(
                  widget.surahGoal!.surahNumber,
                );

                if (liveProgress != null) {
                  final current = liveProgress['current'];
                  final total = liveProgress['total'];

                  return _buildFooterSurahBox(
                    name: arabicName,
                    current: current,
                    total: total,
                    badgeDecoration: badgeDecoration,
                  );
                } else {
                  return _buildFooterSurahBox(
                    name: arabicName,
                    badgeDecoration: badgeDecoration,
                  );
                }
              } else {
                if (surahsInFooter.isEmpty) return const SizedBox.shrink();

                final boxes = <Widget>[];
                for (int i = 0; i < surahsInFooter.length; i++) {
                  if (i > 0) boxes.add(const SizedBox(width: 4));

                  final parsed = parseSurah(surahsInFooter[i]);
                  boxes.add(
                    Flexible(
                      child: _buildFooterSurahBox(
                        name: parsed.name,
                        current: parsed.current > 0 ? parsed.current : null,
                        total: parsed.total > 0 ? parsed.total : null,
                        badgeDecoration: badgeDecoration,
                      ),
                    ),
                  );
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: boxes,
                );
              }
            }(),
          ),
        ),
      ],
    );

    // CHANGED: Khatm mode stacks a small plain-text pace label above the
    // existing info row — no box, no full-width stretch, footer height untouched.
    final Widget content = isKhatm
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildKhatmPaceText(),
              const SizedBox(height: 2),
              SizedBox(height: 24, child: infoRow),
            ],
          )
        : SizedBox(height: 24, child: infoRow);

    return Container(
      height:
          64, // CHANGED: reverted — footer size no longer changes for Khatm mode
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
      ), // CHANGED: reverted — no vertical padding, matches original
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: content,
    );
  }

  // Updated Khatm Pace Indicator matching height & background decoration
  Widget _buildKhatmPaceIndicator(BoxDecoration badgeDecoration) {
    final data = _khatmPaceLabelAndColor();
    if (data == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: Container(
        key: ValueKey(data.label),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: badgeDecoration,
        child: Center(
          child: Text(
            data.label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
              color: data.color,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  ({String label, Color color})? _khatmPaceLabelAndColor() {
    final diff = _khatmPaceDiff;
    if (diff == null) return null;

    final bool isAhead = diff > 0;
    final bool isBehind = diff < 0;

    // CHANGED: these now color a small icon only, not the label text itself,
    // so they can stay vivid without needing to double as body-text contrast.
    final Color color = isBehind
        ? const Color(0xFFFF8A80) // bright coral — reads clearly on green/teal
        : isAhead
        ? const Color(0xFFFFD54F) // gold — reads clearly on green/teal
        : Colors
              .white; // CHANGED: was a lime-green that nearly matched the background

    final String label = isAhead
        ? '$diff ${diff == 1 ? 'page' : 'pages'} ahead'
        : isBehind
        ? '${diff.abs()} ${diff.abs() == 1 ? 'page' : 'pages'} behind'
        : 'On track';

    return (label: label, color: color);
  }

  Widget _buildKhatmPaceText() {
    final data = _khatmPaceLabelAndColor();
    if (data == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Row(
        key: ValueKey(data.label),
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 4),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              color: Colors
                  .white, // CHANGED: always solid white now, not color-coded — guarantees readability against the gradient regardless of status
              decoration: TextDecoration.none,
              shadows: [
                Shadow(
                  color: Colors.black38,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ), // ADD: lifts the text off the brightest part of the gradient
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSurahBox({
    required String name,
    int? current,
    int? total,
    required BoxDecoration badgeDecoration,
  }) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: badgeDecoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            // CHANGED: was maxLines:1 + overflow:ellipsis, which cut names off.
            // FittedBox shrinks the whole name to fit instead, so it's always
            // fully readable — just smaller on tighter badges.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                name,
                maxLines: 1,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (current != null && total != null) ...[
            const SizedBox(width: 4),
            _compactProgressBar(current: current, total: total, dimmed: false),
          ],
        ],
      ),
    );
  }

  // Progress bar scaled for 24px container height
  Widget _compactProgressBar({
    required int current,
    required int total,
    bool dimmed = false,
  }) {
    final progress = total == 0 ? 0.0 : (current / total).clamp(0.0, 1.0);

    return SizedBox(
      width: 42,
      height: 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1
                    ? Colors.amber
                    : (dimmed ? Colors.white38 : Colors.white),
              ),
              minHeight: 8,
            ),
          ),
          Text(
            '$current/$total',
            style: const TextStyle(
              fontSize: 6.5,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // CHANGED: was `getSurahProgressFromPage(int page, String englishName)`,
  // looking up the Arabic name via the `surahs` list. Now takes the surah
  // number directly (SurahGoal already stores it) and gets the Arabic name
  // from the quran package — no local surahs table needed.
  Map<String, int>? getSurahProgressFromPage(int page, int surahNumber) {
    final String arabicGoalName = quran.getSurahNameArabic(surahNumber);

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
}

class _AnimatedActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AnimatedActionButton({required this.label, required this.onTap});

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = BorderRadius.circular(8);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * 12),
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primaryGreen, secondaryGreen],
          ),
          borderRadius: effectiveRadius,
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: effectiveRadius,
          child: InkWell(
            borderRadius: effectiveRadius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Center(
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
