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

    setState(() {
      _currentPage = lastPage;
    });
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

  /// 🔹 Add bookmark
  Future<void> _toggleBookmark(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final surahName = 'Surah'; // TODO: replace later
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

      body: Column(
        children: [
          /// 🌿 BEAUTIFUL TOP HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff1fa463), Color(0xff157347)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
            ),
            child: Row(
              children: [
                /// 📖 Surah Name
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Al-Qur’an',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Page $_currentPage',
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                /// 📄 Page Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
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
                      horizontal: 14,
                      vertical: 8,
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
                            color: isBookmarked ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// 📖 READING AREA (FULLSCREEN)
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

                    /// 🎀 Corner Ribbon Bookmark (Elegant)
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
