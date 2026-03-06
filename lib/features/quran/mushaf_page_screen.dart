import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saleti/data/surah_page_map.dart';
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/utils/khatm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class MushafPageScreen extends StatefulWidget {
  final int startPage;
  final int? initialSurah;
  final ReadingMode readingMode; // <-- ADD THIS

  const MushafPageScreen({
    super.key,
    this.startPage = 1,
    this.initialSurah,
    this.readingMode = ReadingMode.free, // default is free
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
  int _pendingPages = 0;

  bool _isLastPage = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initPage();
    _loadBookmarks();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pageController?.dispose();

    _commitPendingPages();

    super.dispose();
  }

  Future<void> _commitPendingPages() async {
    if (_pendingPages > 0 && widget.readingMode == ReadingMode.khatm) {
      await KhatmService().logPagesRead(_pendingPages);
      _pendingPages = 0;
    }
  }

  Future<void> _initPage() async {
    final initialPage = await _loadLastPage();

    _currentPage = initialPage;
    _lastLoggedPage = initialPage; // For Khatm logging
    _pageController = PageController(initialPage: initialPage - 1);

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

    if (widget.readingMode == ReadingMode.khatm) {
      await prefs.setInt('last_mushaf_page_khatm', page);
    } else {
      await prefs.setInt('last_mushaf_page_free', page);
    }
  }

  Future<int> _loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.readingMode == ReadingMode.khatm) {
      // Start Khatm from page 1 if no saved value
      return prefs.getInt('last_mushaf_page_khatm') ?? 1;
    } else {
      return prefs.getInt('last_mushaf_page_free') ?? widget.startPage;
    }
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

  void _confirmGoToFirstPage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Finish Cycle?"),
        content: const Text(
          "You have reached the last page. Completing this cycle will increment your completed cycles and return to page 1.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _goToFirstPage();
  }

  Future<void> _goToFirstPage() async {
    if (widget.readingMode == ReadingMode.khatm) {
      // Commit any pending pages before restarting
      await _commitPendingPages();

      // Log completion of a full cycle (604 pages)
      await KhatmService().logPagesRead(604 - _lastLoggedPage + 1);

      // Reset last logged page
      _lastLoggedPage = 1;
      _pendingPages = 0;

      // Reset page controller to page 1
      _pageController?.jumpToPage(0);

      setState(() {
        _currentPage = 1;
        _isLastPage = false; // hide the button
      });

      // Save last page
      await _saveLastPage(1);

      // ✅ Show snackbar notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cycle finished! Completed cycles +1.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // For free mode, just go to page 1
      _pageController?.jumpToPage(0);
      setState(() => _currentPage = 1);
    }
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
            colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
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
        gradient: LinearGradient(
          colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
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

    return Stack(
      children: [
        // 🔹 Go to First Page button
        Scaffold(
          // 💡 In lecture mode, we use black to blend with phone notches
          backgroundColor: _isLectureMode
              ? Colors.black
              : const Color(0xfff7f3ea),
          appBar: _isLectureMode ? null : _buildAppBar(),
          body: Column(
            children: [
              if (!_isLectureMode) _buildSecondHeader(),
              _buildReadingArea(),
            ],
          ),
        ),

        // 🔹 Exit Button with a semi-transparent background for visibility
        if (_isLectureMode)
          Positioned(
            top: 50, // 💡 Positioned specifically to stay clear of the top text
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
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        // 🔹 Go to First Page Button (only on last page in Khatm mode)
        if (_isLastPage && widget.readingMode == ReadingMode.khatm)
          Positioned(
            bottom: 40,
            right: 20,
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
                    await _goToFirstPage(); // ✅ Smoothly go to first page
                  }
                },
                label: const Text('Restart Cycle'),
                icon: const Icon(Icons.restart_alt),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReadingArea() {
    return Expanded(
      child: PageView.builder(
        controller: _pageController,
        reverse: true,
        itemCount: 604,
        onPageChanged: (index) {
          final page = index + 1;

          // Only count pages in Khatm mode
          if (widget.readingMode == ReadingMode.khatm) {
            if (page > _lastLoggedPage) {
              _pendingPages += page - _lastLoggedPage;
            }
            _lastLoggedPage = page;
          }

          // Update current page
          setState(() {
            _currentPage = page;
            _isLastPage = page == 604; // ✅ Detect last page
          });

          // Save last viewed page
          _saveLastPage(page);

          // Commit pending pages every 5 pages
          if (_pendingPages >= 5) {
            _commitPendingPages();
          }
        },
        itemBuilder: (context, index) {
          final pageNumber = index + 1;
          final highlighted = _bookmarkedPages.contains(pageNumber);

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/mushaf/$pageNumber.png',
                fit: _isLectureMode ? BoxFit.fill : BoxFit.contain,
              ),
              if (highlighted)
                Positioned(
                  top: 0,
                  right: 0,
                  child: CustomPaint(
                    painter: _BookmarkRibbonPainter(),
                    size: const Size(60, 60),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BookmarkRibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amber.shade400
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
