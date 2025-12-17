import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';

import 'surah_read_screen.dart';
import 'mushaf_page_screen.dart';
import 'bookmarks_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  List<int> _surahNumbers = List.generate(114, (i) => i + 1);
  List<int> _filteredSurahs = [];
  int? _lastSurah;
  int? _lastAyah;

  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _filteredSurahs = _surahNumbers;
    _loadTheme();
    _loadLastRead();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  // 🔹 Load last read Surah & Ayah
  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSurah = prefs.getInt('last_surah');
      _lastAyah = prefs.getInt('last_ayah');
    });
  }

  // 🔍 Search Surah
  void _searchSurah(String query) {
    setState(() {
      _filteredSurahs = _surahNumbers.where((s) {
        final arabic = quran.getSurahNameArabic(s);
        final english = quran.getSurahNameEnglish(s);
        return arabic.contains(query) ||
            english.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : Colors.white,

      // 🔹 AppBar
      appBar: AppBar(
        title: const Text('Quran'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookmarksScreen()),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // 🔍 Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Surah...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _searchSurah,
            ),
          ),

          // 🔁 Continue reading
          if (_lastSurah != null && _lastAyah != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SurahReadScreen(
                        surahNumber: _lastSurah!,
                        startAyah: _lastAyah!,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.green),
                      const SizedBox(width: 10),
                      Text(
                        'Continue: ${quran.getSurahNameEnglish(_lastSurah!)} '
                        '(Ayah $_lastAyah)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // 📜 Surah list
          Expanded(
            child: ListView.builder(
              itemCount: _filteredSurahs.length,
              itemBuilder: (context, index) {
                final surahNumber = _filteredSurahs[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.15),
                    child: Text(
                      surahNumber.toString(),
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                  title: Text(
                    quran.getSurahNameArabic(surahNumber),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 20, fontFamily: 'Amiri'),
                  ),
                  subtitle: Text(quran.getSurahNameEnglish(surahNumber)),
                  trailing: Text(
                    '${quran.getVerseCount(surahNumber)} Ayahs',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SurahReadScreen(surahNumber: surahNumber),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
