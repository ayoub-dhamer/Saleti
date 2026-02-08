import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MushafPageScreen extends StatefulWidget {
  final int startPage;

  const MushafPageScreen({super.key, this.startPage = 1});

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  PageController? _pageController;
  int _currentPage = 1;
  Set<int> _bookmarkedPages = {};
  bool _isLectureMode = false;

  @override
  void initState() {
    super.initState();
    _initPage();
    _loadBookmarks();
  }

  Future<void> _initPage() async {
    final lastPage = await _loadLastPage();
    _pageController = PageController(initialPage: lastPage - 1);
    setState(() => _currentPage = lastPage);
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
    await prefs.setInt('last_mushaf_page', page);
  }

  Future<int> _loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_mushaf_page') ?? widget.startPage;
  }

  Future<void> _toggleBookmark(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final surahName = 'Surah';
    final key = '$page|$surahName|$date';

    final existsIndex = list.indexWhere(
      (e) => e.split('|')[0] == page.toString(),
    );
    if (existsIndex >= 0) {
      list.removeAt(existsIndex);
    } else {
      list.add(key);
    }

    await prefs.setStringList('mushaf_bookmarks', list);
    _loadBookmarks();
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
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
                Text(
                  'Page $_currentPage',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          setState(() => _currentPage = page);
          _saveLastPage(page);
        },
        itemBuilder: (context, index) {
          final pageNumber = index + 1;
          final highlighted = _bookmarkedPages.contains(pageNumber);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 💡 Full-screen image
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
