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
    _currentPage = widget.startPage;
    _pageController = PageController(initialPage: _currentPage - 1);
  }

  Future<void> _saveLastPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_mushaf_page', page);
  }

  Future<void> _addBookmark(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('mushaf_bookmarks') ?? [];

    final key = page.toString();
    if (!bookmarks.contains(key)) {
      bookmarks.add(key);
      await prefs.setStringList('mushaf_bookmarks', bookmarks);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Page $page bookmarked')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffdf8ef),
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('Page $_currentPage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            onPressed: () => _addBookmark(_currentPage),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        reverse: true, // Arabic direction
        itemCount: 604,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index + 1;
          });
          _saveLastPage(_currentPage);
        },
        itemBuilder: (context, index) {
          final pageNumber = index + 1;

          return InteractiveViewer(
            maxScale: 3,
            child: Image.asset(
              'assets/mushaf/$pageNumber.png',
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }
}
