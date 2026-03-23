import 'package:flutter/material.dart';
import 'package:saleti/features/quran/dua_notes_screen.dart';
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/features/quran/surah_goals_screen.dart';
import 'package:saleti/features/quran/surah_list_screen.dart';
import 'package:saleti/features/quran/mushaf_page_screen.dart';
import 'package:saleti/features/quran/bookmarks_screen.dart';

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
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
          'Al-Qur’an',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _mainCard(
                  context,
                  icon: Icons.menu_book_rounded,
                  title: 'Surah List',
                  subtitle: 'Browse all 114 surahs',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SurahListScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _mainCard(
                  context,
                  icon: Icons.auto_stories_rounded,
                  title: 'Read Mushaf',
                  subtitle: '604 authentic pages',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MushafPageScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _mainCard(
                  context,
                  icon: Icons.bookmark_rounded,
                  title: 'Bookmarks',
                  subtitle: 'Saved Mushaf pages',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BookmarksScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _mainCard(
                  context,
                  icon: Icons.track_changes_rounded,
                  title: 'Qur’an Khatm',
                  subtitle: 'Yearly reading plan & progress',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const KhatmScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _mainCard(
                  context,
                  icon: Icons.flag_rounded,
                  title: 'Surah Goals',
                  subtitle: 'Track surah reading goals',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SurahGoalsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _mainCard(
                  context,
                  icon: Icons.note_alt_rounded,
                  title: 'Du\'a Notes',
                  subtitle: 'Save & read your personal du\'as',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DuaNotesScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🌿 Top Header
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
            'Read & Explore',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'The Holy Qur’an at your fingertips',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// 📘 Main Card Button
  Widget _mainCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 30, color: Colors.green),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 28,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
