import 'package:flutter/material.dart';
import 'package:saleti/features/quran/dua_notes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mushaf_page_screen.dart';

/// 🔹 Bookmark model
class BookmarkItem {
  final int page;
  final String surah;
  final String date; // now includes time

  BookmarkItem({required this.page, required this.surah, required this.date});
}

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<BookmarkItem> _bookmarks = [];

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

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
      if (parts.length != 3) continue;

      final page = int.tryParse(parts[0]);
      if (page == null) continue;

      parsed.add(BookmarkItem(page: page, surah: parts[1], date: parts[2]));
    }

    parsed.sort((a, b) => a.page.compareTo(b.page));

    setState(() => _bookmarks = parsed);
  }

  /// 🔹 Delete bookmark
  Future<void> _deleteBookmark(BookmarkItem b) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    list.removeWhere((e) => e.startsWith('${b.page}|'));
    await prefs.setStringList('mushaf_bookmarks', list);

    _loadBookmarks();
  }

  /// ⚠️ Confirm delete dialog
  Future<void> _confirmDelete(BookmarkItem b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    size: 36,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(height: 16),

                /// Title
                const Text(
                  'Delete Bookmark?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                /// Message
                Text(
                  'Remove page ${b.page} from your bookmarks?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),

                const SizedBox(height: 8),
                const Text(
                  "Hold to delete",
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),

                const SizedBox(height: 24),

                /// Buttons (aligned to right, closer together)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8), // smaller gap
                    HoldToDeleteButton(
                      onConfirmed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await _deleteBookmark(b);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, secondaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Bookmarks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: _bookmarks.isEmpty ? _emptyState() : _bookmarksList(),
          ),
        ],
      ),
    );
  }

  /// 🌿 Header
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryGreen, secondaryGreen]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Your Saved Pages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Quick access to your favorite places in the Qur’an',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// 📭 Empty State
  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.bookmark_outline, size: 90, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No bookmarks yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Start reading and save pages for quick access later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  /// 📚 Bookmark List
  Widget _bookmarksList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final b = _bookmarks[index];

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MushafPageScreen(startPage: b.page),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 10,
                  offset: Offset(0, 4),
                  color: Colors.black12,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.bookmark_rounded,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                /// Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.surah,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Page ${b.page} • ${b.date}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                /// Delete
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(b),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
