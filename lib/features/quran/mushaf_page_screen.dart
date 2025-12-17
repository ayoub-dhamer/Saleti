import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';

class MushafPageScreen extends StatefulWidget {
  const MushafPageScreen({super.key});

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  late PageController _pageController;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadLastPage();
  }

  Future<void> _loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPage = prefs.getInt('last_page') ?? 1;

    _pageController = PageController(initialPage: lastPage - 1);

    setState(() {
      _currentPage = lastPage;
    });
  }

  Future<void> _saveLastPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_page', page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Page $_currentPage'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _searchDialog),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: 604,
        onPageChanged: (index) {
          final page = index + 1;
          setState(() => _currentPage = page);
          _saveLastPage(page);
        },
        itemBuilder: (context, index) {
          final pageNumber = index + 1;
          final verses = quran.getPageData(pageNumber);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: verses.map((v) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${v.text} ﴿${v.verseNumber}﴾',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 2.0,
                      fontFamily: 'Amiri',
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  // 🔍 SEARCH QURAN TEXT
  void _searchDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search Quran'),
        content: TextField(
          controller: controller,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(hintText: 'اكتب كلمة...'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _searchAndJump(controller.text.trim());
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _searchAndJump(String query) {
    if (query.isEmpty) return;

    for (int surah = 1; surah <= 114; surah++) {
      final verseCount = quran.getVerseCount(surah);

      for (int ayah = 1; ayah <= verseCount; ayah++) {
        final text = quran.getVerse(surah, ayah);

        if (text.contains(query)) {
          final page = quran.getPageNumber(surah, ayah);
          _pageController.jumpToPage(page - 1);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Found in ${quran.getSurahNameEnglish(surah)} – Ayah $ayah',
              ),
            ),
          );
          return;
        }
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No result found')));
  }
}
