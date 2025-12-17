import 'package:flutter/material.dart';
import 'package:quran/quran.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SurahReadScreen extends StatefulWidget {
  final int surahNumber;
  final int startAyah;

  const SurahReadScreen({
    super.key,
    required this.surahNumber,
    this.startAyah = 1,
  });

  @override
  State<SurahReadScreen> createState() => _SurahReadScreenState();
}

class _SurahReadScreenState extends State<SurahReadScreen> {
  final ScrollController _scrollController = ScrollController();
  int? _lastAyah;

  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadLastRead();
    _loadTheme();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.startAyah > 1) {
        _scrollController.jumpTo((widget.startAyah - 1) * 80.0);
      }
    });
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    });
  }

  // 🔹 Load last ayah
  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastAyah = prefs.getInt('last_ayah');
    });
  }

  // 🔹 Save reading progress
  Future<void> _saveLastRead(int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah', widget.surahNumber);
    await prefs.setInt('last_ayah', ayah);
  }

  // 🔹 Bookmark ayah
  Future<void> addBookmark(int surah, int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('quran_bookmarks') ?? [];

    final key = '$surah:$ayah';
    if (!bookmarks.contains(key)) {
      bookmarks.add(key);
      await prefs.setStringList('quran_bookmarks', bookmarks);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surahNameArabic = getSurahNameArabic(widget.surahNumber);
    final surahNameEnglish = getSurahName(widget.surahNumber);
    final totalAyahs = getVerseCount(widget.surahNumber);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(surahNameArabic, style: const TextStyle(fontSize: 22)),
            Text(surahNameEnglish, style: const TextStyle(fontSize: 14)),
          ],
        ),
        centerTitle: true,
        backgroundColor: _isDarkMode ? Colors.black : Colors.white,
      ),
      body: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: totalAyahs,
        itemBuilder: (context, index) {
          final ayahNumber = index + 1;
          final ayahText = getVerse(widget.surahNumber, ayahNumber);

          final isLastRead = ayahNumber == _lastAyah;

          // Save progress
          _saveLastRead(ayahNumber);

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLastRead
                  ? Colors.green.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$ayahText ﴿$ayahNumber﴾',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 2.0,
                    fontFamily: 'Amiri',
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.bookmark_border),
                    onPressed: () {
                      addBookmark(widget.surahNumber, ayahNumber);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ayah bookmarked')),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
