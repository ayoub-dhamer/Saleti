import 'package:flutter/material.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

import '../prayer_times/prayer_times_screen.dart';
import '../hijri_calendar/hijri_calendar_screen.dart';
import '../quran/quran_screen.dart';
import '../qibla/qibla_screen.dart';
import '../prayer_times/prayer_settings_screen.dart'; // <-- NEW

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selected = 0;
  late final PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  final List<Widget> pages = const [
    PrayerTimesScreen(),
    HijriCalendarScreen(),
    HijriCalendarScreen(),
    QuranScreen(),
    QuranScreen(), // <-- NEW PAGE
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: pages,
      ),
      bottomNavigationBar: StylishBottomBar(
        option: BubbleBarOptions(
          barStyle: BubbleBarStyle.horizontal,
          bubbleFillStyle: BubbleFillStyle.fill,
          opacity: 0.25,
        ),
        items: [
          BottomBarItem(
            icon: const Icon(Icons.access_time),
            title: const Text('Prayers'),
            backgroundColor: Colors.green,
          ),
          BottomBarItem(
            icon: const Icon(Icons.calendar_month),
            title: const Text('Hijri'),
            backgroundColor: Colors.lightBlue,
          ),
          BottomBarItem(
            icon: const Icon(Icons.explore),
            title: const Text('Qibla'),
            backgroundColor: Colors.greenAccent,
          ),
          BottomBarItem(
            icon: const Icon(Icons.menu_book),
            title: const Text('Quran'),
            backgroundColor: Colors.lightBlueAccent,
          ),
          BottomBarItem(
            icon: const Icon(Icons.settings),
            title: const Text('Settings'),
            backgroundColor: Colors.orangeAccent,
          ),
        ],
        currentIndex: selected,
        onTap: (index) {
          setState(() {
            selected = index;
            pageController.jumpToPage(index);
          });
        },
      ),
    );
  }
}
