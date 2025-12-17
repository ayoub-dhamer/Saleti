import 'package:flutter/material.dart';
import 'package:quran/quran.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'surah_read_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<String> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookmarks = prefs.getStringList('quran_bookmarks') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: Colors.green,
      ),
      body: _bookmarks.isEmpty
          ? const Center(child: Text('No bookmarks yet'))
          : ListView.builder(
              itemCount: _bookmarks.length,
              itemBuilder: (context, index) {
                final parts = _bookmarks[index].split(':');
                final surah = int.parse(parts[0]);
                final ayah = int.parse(parts[1]);

                return ListTile(
                  leading: const Icon(Icons.bookmark, color: Colors.green),
                  title: Text(
                    getSurahNameArabic(surah),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontFamily: 'Amiri', fontSize: 18),
                  ),
                  subtitle: Text('${getSurahName(surah)} • Ayah $ayah'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SurahReadScreen(
                          surahNumber: surah,
                          startAyah: ayah,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
