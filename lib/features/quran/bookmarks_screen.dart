import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mushaf_page_screen.dart';

/// 🔹 Bookmark model
class BookmarkItem {
  final int page;
  final String surah;
  final String date;

  BookmarkItem({required this.page, required this.surah, required this.date});
}

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<BookmarkItem> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  /// 🔹 Load bookmarks safely
  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    final parsed = <BookmarkItem>[];

    for (final item in list) {
      final parts = item.split('|');

      // ✅ Safety check
      if (parts.length != 3) continue;

      final page = int.tryParse(parts[0]);
      if (page == null) continue;

      parsed.add(BookmarkItem(page: page, surah: parts[1], date: parts[2]));
    }

    parsed.sort((a, b) => a.page.compareTo(b.page));

    setState(() {
      _bookmarks = parsed;
    });
  }

  /// 🔹 Delete bookmark
  Future<void> _deleteBookmark(BookmarkItem b) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    list.removeWhere((e) => e.startsWith('${b.page}|'));
    await prefs.setStringList('mushaf_bookmarks', list);

    _loadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: Colors.green,
      ),
      body: _bookmarks.isEmpty
          ? const Center(
              child: Text('No bookmarks yet', style: TextStyle(fontSize: 16)),
            )
          : ListView.builder(
              itemCount: _bookmarks.length,
              itemBuilder: (context, index) {
                final b = _bookmarks[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.bookmark, color: Colors.green),
                    title: Text(
                      b.surah,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Page ${b.page} • ${b.date}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteBookmark(b),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MushafPageScreen(startPage: b.page),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
