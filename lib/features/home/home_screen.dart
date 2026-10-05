import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saleti/widgets/fade_indexed_stack.dart';
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

  // FIXED (Battery/CPU #6): all four tabs' screens used to be built
  // immediately at startup, since IndexedStack needs every child present
  // to keep its state alive once visited. That meant Qibla's own location
  // fetch and compass subscription — and Prayer's own location
  // load/permission checks — all started the moment the app opened, even
  // for a tab the user might never visit this session. Tab 0 starts
  // "visited" since it's shown immediately regardless; the other three
  // are only actually built the first time their tab is tapped. Flutter's
  // widget reconciliation treats a position's widget type changing
  // (SizedBox -> the real screen) as a fresh element, so that first
  // build runs initState() as normal — but once visited, a tab's widget
  // type at that position never changes again, so every later switch
  // back to it is reconciled onto the same existing State and still
  // preserves it exactly as before.
  final Set<int> _visitedTabs = {0};

  List<Widget> get pages => [
    _visitedTabs.contains(0)
        ? PrayerTimesScreen(isActive: selected == 0)
        : const SizedBox.shrink(),
    _visitedTabs.contains(1)
        ? const HijriCalendarScreen()
        : const SizedBox.shrink(),
    _visitedTabs.contains(2)
        ? QiblaScreen(isActive: selected == 2)
        : const SizedBox.shrink(),
    _visitedTabs.contains(3) ? const QuranScreen() : const SizedBox.shrink(),
  ];

  void _onTabTapped(int index) {
    if (index == selected) return;
    HapticFeedback.selectionClick();
    setState(() {
      selected = index;
      _visitedTabs.add(index);
    });
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
      body: FadeIndexedStack(index: selected, children: pages),
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
          backgroundColor: theme.scaffoldBackgroundColor,
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
