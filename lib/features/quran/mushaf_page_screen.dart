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

class _MushafPageScreenState extends State<MushafPageScreen> {
  PageController? _pageController;
  int _currentPage = 1;
  Set<int> _bookmarkedPages = {};
  bool _isLectureMode = false;
  bool _isLoading = true;

  bool _isLastPage = false;
  bool _isPageSettled = true;

  KhatmYear? _khatmYear;

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  int get _firstPage {
    if (widget.readingMode == ReadingMode.free) return 1;
    if (widget.readingMode == ReadingMode.khatm) return _sessionStartPage;
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
    if (widget.readingMode == ReadingMode.khatm) {
      _loadKhatmYear();
    }
    MushafDataService().load().then((_) {
      if (mounted) setState(() {});
    });
    MushafDataService().addListener(_onMushafDataChanged); // ADD
  }

  void _onMushafDataChanged() {
    // ADD
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache frame images to prevent latency when opening or switching modes
    precacheImage(
      const AssetImage('assets/images/mushaf_frame_dark.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/mushaf_frame_light.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/surah_name_frame_dark.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/surah_name_frame_light.png'),
      context,
    );
  }

  Future<void> _loadInitialData() async {
    // 1. Load basic preferences first
    await _initPage();
    await _loadBookmarks();
    if (widget.readingMode == ReadingMode.khatm) {
      await _loadKhatmYear();
    }

    // 2. Yield to the event loop so Flutter paints the loader and starts animating
    await Future.delayed(Duration.zero);

    // 3. Load heavy text data and initialize controller
    await MushafDataService().load();
    await _initPageController();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
    final pagesReadThisSession = _calculatePagesRead(
      _sessionStartPage,
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

  int _calculatePagesRead(int start, int end) {
    if (end >= start) {
      return end - start;
    } else {
      return (604 - start) + end;
    }
  }

  bool get _isLastSurahPage {
    if (widget.endPage == null) return false;
    return _currentPage == widget.endPage;
  }

  void _precacheAdjacentPages(int currentPage) {
    // Determine next and previous page numbers within valid Mushaf bounds (1 to 604)
    final nextPage = currentPage + 1;
    final prevPage = currentPage - 1;

    // Touch/load page data asynchronously in the background
    if (nextPage <= _lastPage) {
      MushafDataService().getPage(nextPage);
    }
    if (prevPage >= _firstPage) {
      MushafDataService().getPage(prevPage);
    }
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 6),
                    Text(
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

  Widget _buildLoadingView(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _SpinningLoader(),
            SizedBox(height: 20),
            Text(
              'Loading Mushaf...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final lectureBgColor = theme.scaffoldBackgroundColor;
    final lectureTextColor = isDarkMode ? Colors.white : Colors.black;

    if (_isLoading || _pageController == null) {
      return _buildLoadingView(theme);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (widget.readingMode == ReadingMode.khatm) {
          final pagesRead = _calculatePagesRead(
            _sessionStartPage,
            _sessionEndPage,
          );
          if (pagesRead > 0) {
            await KhatmService().logPagesRead(pagesRead);
          }
        }
        if (context.mounted) Navigator.pop(context, true);
      },
      child: Stack(
        children: [
          Scaffold(
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
            // Pre-warm next and previous page data asynchronously
            _precacheAdjacentPages(page);
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

    final badgeDecoration = BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
    );

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
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
                            child: Text(
                              nextSurah,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 6),
          if (widget.readingMode == ReadingMode.khatm)
            Center(
              child: SizedBox(
                height: 24,
                child: Center(child: _buildKhatmPaceIndicator(badgeDecoration)),
              ),
            ),
          if (widget.readingMode == ReadingMode.khatm) const SizedBox(width: 6),
          Expanded(
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

                  final parsed = parseSurah(surahsInFooter[0]);
                  return _buildFooterSurahBox(
                    name: parsed.name,
                    current: parsed.current > 0 ? parsed.current : null,
                    total: parsed.total > 0 ? parsed.total : null,
                    badgeDecoration: badgeDecoration,
                  );
                }
              }(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKhatmPaceIndicator(BoxDecoration badgeDecoration) {
    final diff = _khatmPaceDiff;
    if (diff == null) return const SizedBox.shrink();

    final bool isAhead = diff > 0;
    final bool isBehind = diff < 0;

    final Color textColor = isBehind
        ? Colors.red.shade300
        : isAhead
        ? Colors.indigo.shade200
        : const Color(0xFFA3E635);

    final String label = isAhead
        ? '$diff ${diff == 1 ? 'page' : 'pages'} ahead'
        : isBehind
        ? '${diff.abs()} ${diff.abs() == 1 ? 'page' : 'pages'} behind'
        : 'On track';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: Container(
        key: ValueKey('$isAhead-$isBehind-$diff'),
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: badgeDecoration,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
              color: textColor,
              decoration: TextDecoration.none,
            ),
          ),
        ),
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
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
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
}

class _AnimatedActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final TextStyle? textStyle;
  final BorderRadius? borderRadius;

  const _AnimatedActionButton({
    required this.label,
    required this.onTap,
    this.textStyle,
    this.borderRadius,
  });

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(8);

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
                  style:
                      textStyle ??
                      const TextStyle(
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

class _SpinningLoader extends StatefulWidget {
  const _SpinningLoader();

  @override
  State<_SpinningLoader> createState() => _SpinningLoaderState();
}

class _SpinningLoaderState extends State<_SpinningLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(
        Icons.autorenew_rounded,
        size: 48,
        color: Color(0xFF1FA45B),
      ),
    );
  }
}
