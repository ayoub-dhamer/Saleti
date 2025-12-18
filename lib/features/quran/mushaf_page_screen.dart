import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MushafPageScreen extends StatefulWidget {
  final int startPage;

  const MushafPageScreen({super.key, this.startPage = 1});

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  Set<int> _bookmarkedPages = {};

  @override
  void initState() {
    super.initState();
    _currentPage = widget.startPage;
    _pageController = PageController(initialPage: _currentPage - 1);
    _loadBookmarks();
  }

  /// 🔹 Load bookmarked pages
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    final pages = <int>{};

    for (final item in list) {
      final parts = item.split('|');

      // ✅ STRICT validation
      if (parts.length != 3) continue;

      final page = int.tryParse(parts[0]);
      if (page == null || page < 1 || page > 604) continue;

      pages.add(page);
    }

    setState(() {
      _bookmarkedPages = pages;
    });
  }

  /// 🔹 Save last page
  Future<void> _saveLastPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_mushaf_page', page);
  }

  /// 🔹 Add bookmark
  Future<void> _addBookmark(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final surahName = 'Surah'; // placeholder
    final key = '$page|$surahName|$date';

    // ✅ Only compare full page number safely
    final exists = list.any((e) {
      final parts = e.split('|');
      return parts.length == 3 && parts[0] == page.toString();
    });

    if (!exists) {
      list.add(key);
      await prefs.setStringList('mushaf_bookmarks', list);
      _loadBookmarks();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Page $page bookmarked')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBookmarked = _bookmarkedPages.contains(_currentPage);

    return Scaffold(
      backgroundColor: isBookmarked
          ? const Color(0xffeaf6ee)
          : const Color(0xfffdf8ef),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('Page $_currentPage'),
        actions: [
          IconButton(
            icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_add),
            onPressed: () => _addBookmark(_currentPage),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            reverse: true,
            itemCount: 604,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index + 1;
              });
              _saveLastPage(_currentPage);
            },
            itemBuilder: (context, index) {
              final pageNumber = index + 1;
              final highlighted = _bookmarkedPages.contains(pageNumber);

              return Container(
                color: highlighted
                    ? const Color(0xffeaf6ee)
                    : const Color(0xfffdf8ef),
                child: InteractiveViewer(
                  maxScale: 3,
                  child: Image.asset(
                    'assets/mushaf/$pageNumber.png',
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              );
            },
          ),

          // 🔖 Bookmark indicator
          if (isBookmarked)
            Positioned(
              top: 16,
              right: 16,
              child: Icon(
                Icons.bookmark,
                color: Colors.green.shade700,
                size: 32,
              ),
            ),
        ],
      ),
    );
  }
}
