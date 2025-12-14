import 'package:flutter/material.dart';
import 'features/prayer_times/prayer_times_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prayer Time App',
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Time App')),
      body: Center(
        child: ElevatedButton(
          child: const Text('View Prayer Times'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrayerTimesScreen()),
            );
          },
        ),
      ),
    );
  }
}
