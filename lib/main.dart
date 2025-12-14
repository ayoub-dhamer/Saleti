import 'package:flutter/material.dart';
import 'features/prayer_times/prayer_times_screen.dart';
import 'features/hijri_calendar/hijri_calendar_screen.dart';
import 'features/quran/quran_screen.dart';

Future<void> main() async {
  runApp(const SaletiApp());
}

class SaletiApp extends StatelessWidget {
  const SaletiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saleti',
      theme: ThemeData(
        primaryColor: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const PrayerTimesScreen(),
    const HijriCalendarScreen(),
    const Placeholder(), // Qibla screen placeholder
    const QuranScreen(), // Quran screen placeholder
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.lightBlue,
        unselectedItemColor: Colors.green,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Prayer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Hijri',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Qibla'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Quran'),
        ],
      ),
    );
  }
}
