import 'package:flutter/material.dart';
import 'mushaf_page_screen.dart';
import 'bookmarks_screen.dart';

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quran'), backgroundColor: Colors.green),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _item(
            context,
            'Read Mushaf',
            Icons.menu_book,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MushafPageScreen()),
            ),
          ),
          _item(
            context,
            'Bookmarks',
            Icons.bookmark,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookmarksScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title),
        onTap: onTap,
      ),
    );
  }
}
