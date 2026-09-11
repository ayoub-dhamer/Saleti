import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const List<_QuranItem> _items = [
    _QuranItem(
      icon: Icons.menu_book_rounded,
      title: 'Surah List',
      subtitle: 'Browse all 114 surahs',
      routeBuilder: SurahListScreen.new,
    ),
    _QuranItem(
      icon: Icons.auto_stories_rounded,
      title: 'Read Mushaf',
      subtitle: '604 authentic pages',
      isReadMushaf: true,
    ),
    _QuranItem(
      icon: Icons.bookmark_rounded,
      title: 'Bookmarks',
      subtitle: 'Saved Mushaf pages',
      routeBuilder: BookmarksScreen.new,
    ),
    _QuranItem(
      icon: Icons.track_changes_rounded,
      title: 'Qur\'an Khatm',
      subtitle: 'Yearly reading plan & progress',
      routeBuilder: KhatmScreen.new,
    ),
    _QuranItem(
      icon: Icons.flag_rounded,
      title: 'Surah Goals',
      subtitle: 'Track surah reading goals',
      routeBuilder: SurahGoalsScreen.new,
    ),
    _QuranItem(
      icon: Icons.note_alt_rounded,
      title: 'Du\'a Notes',
      subtitle: 'Save & read your personal du\'as',
      routeBuilder: DuaNotesScreen.new,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
          'Al-Qur\'an',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _AnimatedMainCard(
                    index: index,
                    icon: item.icon,
                    title: item.title,
                    subtitle: item.subtitle,
                    theme: theme,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => item.isReadMushaf
                              ? const MushafPageScreen(
                                  storageKey: 'last_read_general',
                                  useLastReadPosition: true,
                                )
                              : item.routeBuilder!(),
                        ),
                      );
                    },
                  ),
                );
              },
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
            'The Holy Qur\'an at your fingertips',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _QuranItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function()? routeBuilder;
  final bool isReadMushaf;

  const _QuranItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.routeBuilder,
    this.isReadMushaf = false,
  });
}

/// Animated entrance card wrapper + the actual card visual, theme-aware.
class _AnimatedMainCard extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeData theme;
  final VoidCallback onTap;

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  const _AnimatedMainCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index.clamp(0, 6) * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryGreen.withOpacity(0.15),
                      secondaryGreen.withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 28, color: primaryGreen),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.6,
                        ),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 26,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
