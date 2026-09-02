import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

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

  List<Widget> get pages => [
    PrayerTimesScreen(isActive: selected == 0),
    const HijriCalendarScreen(),
    QiblaScreen(isActive: selected == 2),
    const QuranScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == selected) return; // avoid re-animating into the same page
    HapticFeedback.selectionClick();
    setState(() => selected = index);
    pageController.animateToPage(
      // CHANGED: was jumpToPage — now a smooth transition
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(
          () => selected = index,
        ), // ADD: keeps state in sync if page changes programmatically
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: StylishBottomBar(
          option: BubbleBarOptions(
            barStyle: BubbleBarStyle.horizontal,
            bubbleFillStyle: BubbleFillStyle.fill,
            opacity:
                0.15, // CHANGED: was 0.25 — slightly more subtle bubble background
          ),
          backgroundColor: Colors
              .white, // ADD: explicit, matches the rest of the app's card surfaces
          elevation:
              0, // ADD: shadow now comes from the Container wrapper for a cleaner single shadow
          items: [
            BottomBarItem(
              icon: const Icon(
                Icons.access_time_filled_rounded,
              ), // CHANGED: filled variant, more consistent weight with the others
              title: const Text('Prayers'),
              backgroundColor: primaryGreen, // CHANGED: unified palette
            ),
            BottomBarItem(
              icon: const Icon(Icons.calendar_month_rounded),
              title: const Text('Hijri'),
              backgroundColor: secondaryGreen, // CHANGED: was lightBlue
            ),
            BottomBarItem(
              icon: const Icon(Icons.explore_rounded),
              title: const Text('Qibla'),
              backgroundColor: primaryGreen, // CHANGED: was greenAccent
            ),
            BottomBarItem(
              icon: const Icon(Icons.menu_book_rounded),
              title: const Text('Quran'),
              backgroundColor: secondaryGreen, // CHANGED: was lightBlueAccent
            ),
          ],
          currentIndex: selected,
          onTap: _onTabTapped, // CHANGED: was inline setState + jumpToPage
        ),
      ),
    );
  }
}
