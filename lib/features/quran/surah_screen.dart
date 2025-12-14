import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

class SurahScreen extends StatefulWidget {
  final int surahNumber;
  final int lastAyah;
  final Function(int) onAyahRead;

  const SurahScreen({
    super.key,
    required this.surahNumber,
    required this.lastAyah,
    required this.onAyahRead,
  });

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo((widget.lastAyah - 1) * 60.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ayahCount = quran.getVerseCount(widget.surahNumber);

    return Scaffold(
      appBar: AppBar(
        title: Text(quran.getSurahName(widget.surahNumber)),
        backgroundColor: Colors.green,
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: ayahCount,
        itemBuilder: (context, index) {
          final ayahNumber = index + 1;
          final ayahText = quran.getVerse(widget.surahNumber, ayahNumber);

          widget.onAyahRead(ayahNumber);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '$ayahText ﴿$ayahNumber﴾',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 22,
                height: 1.8,
                fontFamily: 'Amiri',
              ),
            ),
          );
        },
      ),
    );
  }
}
