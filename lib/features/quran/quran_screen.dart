import 'package:flutter/material.dart';
import 'package:saleti/features/quran/surah_list_screen.dart';
import 'mushaf_page_screen.dart';
import 'bookmarks_screen.dart';

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Al-Qur’an'),
        centerTitle: true,
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _mainButton(
              context,
              icon: Icons.menu_book,
              title: 'Surah List',
              subtitle: 'Browse all surahs',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SurahListScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            _mainButton(
              context,
              icon: Icons.auto_stories,
              title: 'Read Mushaf',
              subtitle: '604 authentic pages',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MushafPageScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            _mainButton(
              context,
              icon: Icons.bookmark,
              title: 'Bookmarks',
              subtitle: 'Saved Mushaf pages',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.green),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
