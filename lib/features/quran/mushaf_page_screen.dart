import 'package:flutter/material.dart';
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

  /// 🔹 Load bookmarked pages
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    final pages = <int>{};
    for (final item in list) {
      final parts = item.split('|');
      if (parts.length != 3) continue;
      final page = int.tryParse(parts[0]);
      if (page == null || page < 1 || page > 604) continue;
      pages.add(page);
    }

    setState(() => _bookmarkedPages = pages);
  }

  /// 🔹 Save last page
  Future<void> _saveLastPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_mushaf_page', page);
  }

  Future<int> _loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_mushaf_page') ?? widget.startPage;
  }

  /// 🔹 Toggle bookmark
  Future<void> _toggleBookmark(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final surahName = 'Surah'; // TODO replace later
    final key = '$page|$surahName|$date';

    final existsIndex = list.indexWhere((e) {
      final parts = e.split('|');
      return parts.length == 3 && parts[0] == page.toString();
    });

    if (existsIndex >= 0) {
      list.removeAt(existsIndex);
    } else {
      list.add(key);
    }

    await prefs.setStringList('mushaf_bookmarks', list);
    _loadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    if (_pageController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isBookmarked = _bookmarkedPages.contains(_currentPage);

    return Scaffold(
      backgroundColor: const Color(0xfff7f3ea),

      /// 🌿 TOP APP BAR (CENTERED TITLE)
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
      ),

      body: Column(
        children: [
          /// 🌿 SECOND HEADER (CONTROLS)
          Container(
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

                /// 📄 Page Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
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
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                /// 🔖 Bookmark Button
                GestureDetector(
                  onTap: () => _toggleBookmark(_currentPage),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isBookmarked
                          ? Colors.amber.shade400
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: isBookmarked
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          size: 20,
                          color: isBookmarked ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isBookmarked ? 'Saved' : 'Save',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isBookmarked ? Colors.black : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// 📖 READING AREA
          Expanded(
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
                    InteractiveViewer(
                      maxScale: 3,
                      child: Image.asset(
                        'assets/mushaf/$pageNumber.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    /// 🎀 Bookmark Ribbon
                    if (highlighted)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: CustomPaint(
                          painter: _BookmarkRibbonPainter(),
                          size: const Size(70, 70),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎀 Ribbon Painter
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
