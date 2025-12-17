import 'package:flutter/material.dart';
import 'package:quran/quran.dart';
import 'surah_read_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'surah_read_screen.dart';

class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key});

  Future<Map<String, int>> _getLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'surah': prefs.getInt('last_surah') ?? 1,
      'ayah': prefs.getInt('last_ayah') ?? 1,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getLastRead(),
      builder: (context, snapshot) {
        final lastSurah = snapshot.data?['surah'] ?? 1;
        final lastAyah = snapshot.data?['ayah'] ?? 1;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Quran'),
            backgroundColor: Colors.green,
            actions: [
              if (snapshot.hasData)
                IconButton(
                  icon: const Icon(Icons.bookmark),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SurahReadScreen(
                          surahNumber: lastSurah,
                          startAyah: lastAyah,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: ListView.builder(
            itemCount: totalSurahCount,
            itemBuilder: (context, index) {
              final surahNumber = index + 1;

              return ListTile(
                title: Text(getSurahNameArabic(surahNumber)),
                subtitle: Text(getSurahName(surahNumber)),
                trailing: Text('$surahNumber'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SurahReadScreen(surahNumber: surahNumber),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
