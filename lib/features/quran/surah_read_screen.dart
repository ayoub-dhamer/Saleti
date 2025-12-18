import 'package:flutter/material.dart';
import 'package:quran/quran.dart';

class SurahPagedScreen extends StatefulWidget {
  final int initialSurah;

  const SurahPagedScreen({super.key, this.initialSurah = 1});

  @override
  State<SurahPagedScreen> createState() => _SurahPagedScreenState();
}

class _SurahPagedScreenState extends State<SurahPagedScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialSurah - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        itemCount: 114,
        itemBuilder: (context, index) {
          final surahNumber = index + 1;
          return _surahPage(surahNumber);
        },
      ),
    );
  }

  Widget _surahPage(int surahNumber) {
    final totalAyahs = getVerseCount(surahNumber);
    final spans = <InlineSpan>[];

    for (int i = 1; i <= totalAyahs; i++) {
      spans.add(TextSpan(text: '${getVerse(surahNumber, i)} '));
      spans.add(
        WidgetSpan(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '﴿$i﴾',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              getSurahNameArabic(surahNumber),
              style: const TextStyle(
                fontSize: 28,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 26,
                      height: 1.8,
                      fontFamily: 'Amiri',
                      color: Colors.black,
                    ),
                    children: spans,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
