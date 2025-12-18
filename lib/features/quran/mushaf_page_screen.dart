import 'package:flutter/material.dart';
import 'package:quran/quran.dart';
import 'mushaf_page_data.dart';

class MushafPageScreen extends StatefulWidget {
  final int initialPage;

  const MushafPageScreen({super.key, this.initialPage = 1});

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  late PageController _controller;

  // 🔹 Currently selected ayah
  String? selectedAyahKey;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffdfaf3),
      body: PageView.builder(
        controller: _controller,
        itemCount: 604,
        onPageChanged: (_) {
          // Clear selection when page changes
          setState(() => selectedAyahKey = null);
        },
        itemBuilder: (context, index) {
          final pageNumber = index + 1;
          final pageAyahs = MushafPageData.pages[pageNumber] ?? [];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.center,
                textDirection: TextDirection.rtl,
                children: pageAyahs.map((v) {
                  final surah = v['surah']!;
                  final ayah = v['ayah']!;
                  final key = '$surah:$ayah';
                  final text = getVerse(surah, ayah);

                  final isSelected = key == selectedAyahKey;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedAyahKey = key;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.green.withOpacity(0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$text ﴿$ayah﴾',
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: 26,
                          height: 1.8,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
