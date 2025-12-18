import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mushaf_page_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<String> bookmarks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bookmarks = prefs.getStringList('quran_bookmarks') ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: ListView.builder(
        itemCount: bookmarks.length,
        itemBuilder: (context, index) {
          final parts = bookmarks[index].split(':');
          final page = int.parse(parts[0]);

          return ListTile(
            title: Text('Page $page'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MushafPageScreen(initialPage: page),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
