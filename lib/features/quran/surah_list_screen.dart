import 'package:flutter/material.dart';
import 'package:quran/quran.dart';
import '../../data/surah_pages.dart';
import 'mushaf_page_screen.dart';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final surahs = List.generate(114, (i) => i + 1)
        .where(
          (s) =>
              getSurahName(s).toLowerCase().contains(_query.toLowerCase()) ||
              getSurahNameArabic(s).contains(_query),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surahs'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search surah...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                final surah = surahs[index];
                final page = surahStartPage[surah] ?? 1;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text(
                      surah.toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    getSurahNameArabic(surah),
                    textAlign: TextAlign.right,
                  ),
                  subtitle: Text(getSurahName(surah)),
                  trailing: Text('Page $page'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MushafPageScreen(startPage: page),
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
