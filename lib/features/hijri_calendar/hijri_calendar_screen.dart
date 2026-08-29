import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hijri/hijri_calendar.dart';

class HijriCalendarScreen extends StatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  State<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends State<HijriCalendarScreen> {
  late HijriCalendar _selectedHijri;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  @override
  void initState() {
    super.initState();

    _selectedHijri = HijriCalendar.fromDate(_focusedDay);
  }

  final List<Map<String, dynamic>> islamicHolidays = [
    {"month": 1, "day": 1, "name": "Islamic New Year"},
    {"month": 1, "day": 10, "name": "Day of Ashura"},
    {"month": 3, "day": 12, "name": "Mawlid al-Nabi"},
    {"month": 9, "day": 1, "name": "Start of Ramadan"},
    {"month": 9, "day": 27, "name": "Lailat al-Qadr"},
    {"month": 10, "day": 1, "name": "Eid al-Fitr"},
    {"month": 12, "day": 8, "name": "Start of Hajj"},
    {"month": 12, "day": 9, "name": "Day of Arafah"},
    {"month": 12, "day": 10, "name": "Eid al-Adha"},
  ];

  bool _isHoliday(DateTime day) {
    final hijri = HijriCalendar.fromDate(day);
    return islamicHolidays.any(
      (event) => event["day"] == hijri.hDay && event["month"] == hijri.hMonth,
    );
  }

  String? _holidayName(DateTime day) {
    final hijri = HijriCalendar.fromDate(day);
    final match = islamicHolidays.firstWhere(
      (event) => event["day"] == hijri.hDay && event["month"] == hijri.hMonth,
      orElse: () => {},
    );
    return match.isEmpty ? null : match["name"];
  }

  bool get _isViewingCurrentMonth {
    final now = DateTime.now();
    return _focusedDay.year == now.year && _focusedDay.month == now.month;
  }

  void _jumpToToday() {
    final today = DateTime.now();
    setState(() {
      _focusedDay = today;
      _selectedDay = today;
      _selectedHijri = HijriCalendar.fromDate(today);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, secondaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Hijri Calendar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _bigHeader(),
              _infoCard(),
              _calendarSection(),
              _legend(),
            ],
          ),
          if (!_isViewingCurrentMonth) _jumpToTodayChip(),
        ],
      ),
    );
  }

  // 🟢 BIG HEADER
  Widget _bigHeader() {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryGreen, secondaryGreen]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: const Column(
        // CHANGED: was a Row with the icon + this Column
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore Islamic dates',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tap any date to view its Hijri equivalent',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // 💜 Info Card
  Widget _infoCard() {
    final holiday = _selectedDay != null ? _holidayName(_selectedDay!) : null;
    // REMOVED: final isToday = ...

    return Container(
      transform: Matrix4.translationValues(0, -26, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: TweenAnimationBuilder<double>(
        key: ValueKey('${_selectedHijri.hDay}-${_selectedHijri.hMonth}'),
        tween: Tween(begin: 0.94, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6B4EE6), Color(0xFF8B6FF0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B4EE6).withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // REMOVED: the `if (isToday) Container(...'TODAY' badge...)` block
                Text(
                  "${_selectedHijri.hDay} ${_selectedHijri.longMonthName} ${_selectedHijri.hYear} AH",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (holiday != null && holiday.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          holiday,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 📅 Calendar
  Widget _calendarSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: TableCalendar(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.saturday,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedHijri = HijriCalendar.fromDate(selectedDay);
              });
            },

            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },

            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              weekendStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.deepPurple.shade300,
              ),
            ),

            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              leftChevronIcon: const Icon(Icons.chevron_left_rounded),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100, width: 1),
                ),
              ),
            ),

            calendarBuilders: CalendarBuilders(
              defaultBuilder: _dayTile,
              todayBuilder: _todayTile,
              selectedBuilder: _selectedTile,
            ),
          ),
        ),
      ),
    );
  }

  // 🟢 Floating "Jump to Today" chip
  Widget _jumpToTodayChip() {
    return Positioned(
      bottom: 90,
      right: 24,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Transform.scale(scale: t, child: child),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _jumpToToday,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryGreen, secondaryGreen],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: primaryGreen.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.today_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Today',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🟦 Legend
  Widget _legend() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendPill(Colors.lightBlue, "Selected"),
          _legendPill(Colors.lightGreen.shade400, "Holiday"),
          _legendPill(Colors.deepPurpleAccent, "Today"),
        ],
      ),
    );
  }

  Widget _legendPill(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color == Colors.lightGreen.shade400
                  ? Colors.green.shade700
                  : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayTile(context, day, _) {
    final hijri = HijriCalendar.fromDate(day);
    final holiday = _isHoliday(day);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: holiday
            ? Colors.lightGreen.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: holiday
            ? Border.all(color: Colors.lightGreen.shade300, width: 1.2)
            : null,
      ),
      child: _dayContent(day, hijri, showHolidayDot: holiday),
    );
  }

  Widget _todayTile(context, day, _) {
    final hijri = HijriCalendar.fromDate(day);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.deepPurpleAccent, Color(0xFF9575FF)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _dayContent(day, hijri, textColor: Colors.white),
    );
  }

  Widget _selectedTile(context, day, _) {
    final hijri = HijriCalendar.fromDate(day);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.lightBlue, Color(0xFF64C8FF)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.lightBlue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _dayContent(day, hijri, textColor: Colors.white),
    );
  }

  Widget _dayContent(
    DateTime day,
    HijriCalendar hijri, {
    Color textColor = Colors.black,
    bool showHolidayDot = false,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${day.day}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 14, // CHANGED: was 15
            ),
          ),
          Text(
            "${hijri.hDay}",
            style: TextStyle(
              fontSize: 10,
              color: textColor.withOpacity(0.75),
            ), // CHANGED: was 11, removed SizedBox(height: 2) before this
          ),
          if (showHolidayDot)
            Container(
              margin: const EdgeInsets.only(
                top: 1,
              ), // CHANGED: was a separate SizedBox(height: 2) + this container
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.lightGreen,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
