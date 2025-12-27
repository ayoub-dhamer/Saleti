import 'package:flutter/material.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

import '../prayer_times/prayer_times_screen.dart';
import '../hijri_calendar/hijri_calendar_screen.dart';
import '../quran/quran_screen.dart';
import '../qibla/qibla_screen.dart';

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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          PrayerTimesScreen(),
          HijriCalendarScreen(),
          HijriCalendarScreen(),
          QuranScreen(),
        ],
      ),

      bottomNavigationBar: StylishBottomBar(
        option: BubbleBarOptions(
          barStyle: BubbleBarStyle.horizontal,
          bubbleFillStyle: BubbleFillStyle.fill,
          opacity: 0.25,
        ),
        items: [
          BottomBarItem(
            icon: Icon(Icons.access_time),
            title: Text('Prayers'),
            backgroundColor: Colors.green,
          ),
          BottomBarItem(
            icon: Icon(Icons.calendar_month),
            title: Text('Hijri'),
            backgroundColor: Colors.lightBlue,
          ),
          BottomBarItem(
            icon: Icon(Icons.explore),
            title: Text('Qibla'),
            backgroundColor: Colors.greenAccent,
          ),
          BottomBarItem(
            icon: Icon(Icons.menu_book),
            title: Text('Quran'),
            backgroundColor: Colors.lightBlueAccent,
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
