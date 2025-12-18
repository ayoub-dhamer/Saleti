import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mushaf_page_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<int> _bookmarkedPages = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    setState(() {
      _bookmarkedPages =
          list.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList()
            ..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: Colors.green,
      ),
      body: _bookmarkedPages.isEmpty
          ? const Center(child: Text('No bookmarks yet'))
          : ListView.builder(
              itemCount: _bookmarkedPages.length,
              itemBuilder: (context, index) {
                final page = _bookmarkedPages[index];

                return ListTile(
                  leading: const Icon(Icons.bookmark, color: Colors.green),
                  title: Text('Page $page'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MushafPageScreen(startPage: page),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
