import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'surah_read_screen.dart';

class QuranSearchScreen extends StatefulWidget {
  const QuranSearchScreen({super.key});

  @override
  State<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends State<QuranSearchScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final results = _searchResults();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search Quran...',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => query = v),
        ),
      ),
      body: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final r = results[index];
          return ListTile(
            title: Text(
              r['text'],
              textAlign: TextAlign.right,
              style: const TextStyle(fontFamily: 'Amiri'),
            ),
            subtitle: Text(
              '${quran.getSurahName(r['surah'])} • Ayah ${r['ayah']}',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SurahPagedScreen(initialSurah: 1),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _searchResults() {
    if (query.isEmpty) return [];

    final List<Map<String, dynamic>> results = [];

    for (int s = 1; s <= 114; s++) {
      final ayahCount = quran.getVerseCount(s);
      for (int a = 1; a <= ayahCount; a++) {
        final text = quran.getVerse(s, a, verseEndSymbol: false);
        if (text.contains(query)) {
          results.add({'surah': s, 'ayah': a, 'text': text});

          if (results.length >= 50) return results; // limit
        }
      }
    }
    return results;
  }
}
