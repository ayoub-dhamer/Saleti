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

  @override
  void initState() {
    super.initState();
    _currentPage = widget.startPage.clamp(1, 604);
    _pageController = PageController(initialPage: _currentPage - 1);
  }

  // 🔹 Save last opened page
  Future<void> _saveLastPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_mushaf_page', page);
  }

  // 🔖 Bookmark page
  Future<void> _addBookmark(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('mushaf_bookmarks') ?? [];

    final key = page.toString();
    if (!bookmarks.contains(key)) {
      bookmarks.add(key);
      await prefs.setStringList('mushaf_bookmarks', bookmarks);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Page $page bookmarked')));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffdf8ef),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('Page $_currentPage'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.list),
          tooltip: 'Surah list',
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            tooltip: 'Bookmark page',
            onPressed: () => _addBookmark(_currentPage),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        reverse: true, // RTL page direction (Arabic Mushaf)
        itemCount: 604,
        onPageChanged: (index) {
          final page = index + 1;
          setState(() => _currentPage = page);
          _saveLastPage(page);
        },
        itemBuilder: (context, index) {
          final pageNumber = index + 1;

          return Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 3,
              child: Image.asset(
                'assets/mushaf/$pageNumber.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    'Page image not found',
                    style: TextStyle(color: Colors.red),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
