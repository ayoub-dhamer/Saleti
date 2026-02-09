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
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Surahs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _searchBox(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: surahs.length,
              itemBuilder: (context, index) {
                final surah = surahs[index];
                final page = surahStartPage[surah] ?? 1;

                return _surahCard(surah: surah, page: page);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 🔍 Search Box
  Widget _searchBox() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Colors.black12,
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          hintText: 'Search Surah...',
          border: InputBorder.none,
          icon: Icon(Icons.search),
        ),
      ),
    );
  }

  /// 📖 Surah Card
  Widget _surahCard({required int surah, required int page}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MushafPageScreen(
              startPage: page,
              initialSurah: surah, // Pass the specific surah ID
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          border: Border.all(color: Colors.white), // Subtle "glass" feel
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 4),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Row(
          children: [
            _surahNumberBadge(surah),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        getSurahName(surah),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                      Text(
                        getSurahNameArabic(surah),
                        style: const TextStyle(
                          fontSize: 22,
                          fontFamily:
                              'QuranFont', // Use your custom Arabic font here
                          color: Color(0xFF1FA45B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        getPlaceOfRevelation(surah).toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.circle,
                          size: 4,
                          color: Colors.grey.shade300,
                        ),
                      ),
                      Text(
                        '${getVerseCount(surah)} VERSES',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _pageIndicator(page),
          ],
        ),
      ),
    );
  }

  Widget _pageIndicator(int page) {
    return Column(
      children: [
        const Text(
          'PAGE',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Colors.green,
          ),
        ),
        Text(
          page.toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3142),
          ),
        ),
      ],
    );
  }

  /// 🔢 Surah Number Badge
  Widget _surahNumberBadge(int number) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Islamic-style geometric shape
        Transform.rotate(
          angle: 0.8, // 45 degrees
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1FA45B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        Text(
          number.toString(),
          style: const TextStyle(
            color: Color(0xFF1FA45B),
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
