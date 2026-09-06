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

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  List<Widget> get pages => [
    PrayerTimesScreen(isActive: selected == 0),
    const HijriCalendarScreen(),
    QiblaScreen(isActive: selected == 2),
    const QuranScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == selected) return;
    HapticFeedback.selectionClick();
    setState(() => selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // CHANGED: was PageView + PageController.animateToPage, which visually
      // scrolls through every page in between. IndexedStack + AnimatedSwitcher
      // keeps all pages alive (preserving isActive/tab state) but only ever
      // cross-fades directly between the two pages actually being switched to.
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        layoutBuilder: (currentChild, previousChildren) {
          // Keeps the IndexedStack sized correctly during the cross-fade
          return Stack(
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: IndexedStack(
          key: ValueKey(
            selected,
          ), // triggers AnimatedSwitcher's fade on tab change
          index: selected,
          children: pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: StylishBottomBar(
          option: BubbleBarOptions(
            barStyle: BubbleBarStyle.horizontal,
            bubbleFillStyle: BubbleFillStyle.fill,
            opacity: isDark ? 0.25 : 0.15,
          ),
          backgroundColor: theme.cardColor,
          elevation: 0,
          items: [
            BottomBarItem(
              icon: const Icon(Icons.access_time_filled_rounded),
              title: const Text('Prayers'),
              backgroundColor: Colors.green,
            ),
            BottomBarItem(
              icon: const Icon(Icons.calendar_month_rounded),
              title: const Text('Hijri'),
              backgroundColor: Colors.lightBlue,
            ),
            BottomBarItem(
              icon: const Icon(Icons.explore_rounded),
              title: const Text('Qibla'),
              backgroundColor: Colors.greenAccent,
            ),
            BottomBarItem(
              icon: const Icon(Icons.menu_book_rounded),
              title: const Text('Quran'),
              backgroundColor: Colors.lightBlueAccent,
            ),
          ],
          currentIndex: selected,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}
