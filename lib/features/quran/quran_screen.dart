import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';
import 'surah_screen.dart'; // <-- Add this line

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  int lastSurah = 1;
  int lastAyah = 1;

  @override
  void initState() {
    super.initState();
    _loadLastRead();
  }

  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lastSurah = prefs.getInt('last_surah') ?? 1;
      lastAyah = prefs.getInt('last_ayah') ?? 1;
    });
  }

  Future<void> _saveLastRead(int surah, int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah', surah);
    await prefs.setInt('last_ayah', ayah);
  }

  void _openSurah(int surahNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahScreen(
          surahNumber: surahNumber,
          lastAyah: (surahNumber == lastSurah) ? lastAyah : 1,
          onAyahRead: (ayah) => _saveLastRead(surahNumber, ayah),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quran"), backgroundColor: Colors.green),
      body: ListView.builder(
        itemCount: 114,
        itemBuilder: (context, index) {
          final surahNumber = index + 1;
          return ListTile(
            title: Text(quran.getSurahName(surahNumber)),
            onTap: () => _openSurah(surahNumber),
          );
        },
      ),
    );
  }
}
