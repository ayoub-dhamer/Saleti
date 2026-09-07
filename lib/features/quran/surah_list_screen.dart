import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart';
import 'package:saleti/widgets/icon_action.dart';
import '../../data/surah_pages.dart';
import 'mushaf_page_screen.dart';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surahs = List.generate(114, (i) => i + 1)
        .where(
          (s) =>
              getSurahName(s).toLowerCase().contains(_query.toLowerCase()) ||
              getSurahNameArabic(s).contains(_query),
        )
        .toList();

    return Scaffold(
      backgroundColor: theme
          .scaffoldBackgroundColor, // CHANGED: was hardcoded Color(0xFFF4F6F8)
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
          'Surahs',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          _header(surahs.length),
          _searchBox(theme, isDark),
          Expanded(
            child: surahs.isEmpty
                ? _emptyState(theme)
                : _surahListView(surahs, theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _header(int resultCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryGreen, secondaryGreen]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Browse the Qur\'an',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _query.isEmpty
                ? 'All 114 surahs, tap to jump right to the page'
                : '$resultCount ${resultCount == 1 ? 'result' : 'results'}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _searchBox(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.cardColor, // CHANGED: was hardcoded Colors.white
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ), // CHANGED
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
          ), // CHANGED
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
              ), // ADD: input text color
              decoration: InputDecoration(
                hintText: 'Search Surah...',
                hintStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                ), // ADD
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            IconAction(
              label: 'Clear search',
              onTap: () {
                HapticFeedback.selectionClick();
                _searchController.clear();
                setState(() => _query = '');
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(
                    0.6,
                  ), // also bumped
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 44,
                color: primaryGreen.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No matching surahs',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ), // CHANGED
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different name or spelling.',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                fontSize: 12.5,
              ), // CHANGED
            ),
          ],
        ),
      ),
    );
  }

  Widget _surahListView(List<int> surahs, ThemeData theme, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      itemCount: surahs.length,
      itemBuilder: (context, index) {
        final surah = surahs[index];

        final startPage = surahStartPages[surah] ?? 1;
        final endPage = surah == 114
            ? 604
            : (surahStartPages[surah + 1] ?? 604) - 1;
        final pagesCount = endPage - startPage + 1;
        final ayahCount = getVerseCount(surah);

        return TweenAnimationBuilder<double>(
          key: ValueKey('surah_$surah'),
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 220 + (index.clamp(0, 10) * 25)),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 10),
              child: child,
            ),
          ),
          child: _surahCard(
            surah: surah,
            startPage: startPage,
            pages: pagesCount,
            ayat: ayahCount,
            theme: theme,
            isDark: isDark,
          ),
        );
      },
    );
  }

  Widget _surahCard({
    required int surah,
    required int startPage,
    required int pages,
    required int ayat,
    required ThemeData theme,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.selectionClick();
        final int actualStartPage = surahStartPages[surah] ?? 1;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MushafPageScreen(
              startPage: actualStartPage,
              storageKey: 'last_jumped_page',
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.cardColor, // CHANGED: was hardcoded Colors.white
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ), // CHANGED
          ],
        ),
        child: Row(
          children: [
            _surahNumberBadge(surah),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getSurahNameArabic(surah),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ), // CHANGED
                  ),
                  const SizedBox(height: 4),
                  Text(
                    getSurahName(surah),
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.55,
                      ), // CHANGED
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _miniBadge('$ayat Ayat', isDark),
                      const SizedBox(width: 6),
                      _miniBadge(
                        '$pages ${pages == 1 ? 'Page' : 'Pages'}',
                        isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    size: 18,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'page $startPage',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : const Color(0xFFF4F6F8), // CHANGED
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          color: isDark ? Colors.white70 : Colors.grey.shade600, // CHANGED
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _surahNumberBadge(int number) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        // ADD: pin this small numeral to 1.0x scale so the fixed 48x48 circle
        // never clips when the user has increased system font size.
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: Text(
            number.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
