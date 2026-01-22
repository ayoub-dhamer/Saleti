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

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
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
      body: Column(
        children: [_bigHeader(), _purpleCard(), _calendarSection(), _legend()],
      ),
    );
  }

  // 🟢 BIG HEADER (same feel as Bookmarks)
  Widget _bigHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Explore Islamic dates',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Tap any date below to instantly view its Hijri equivalent and special occasions',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  bool get _hasHoliday =>
      _holidayName(_selectedDay!) != null &&
      _holidayName(_selectedDay!)!.isNotEmpty;

  // 💜 Purple Info Card
  Widget _purpleCard() {
    final holiday = _holidayName(_selectedDay!);

    return Container(
      transform: Matrix4.translationValues(0, -26, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurpleAccent.withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 👈 important for shrink/expand
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "${_selectedHijri.hDay} ${_selectedHijri.longMonthName} ${_selectedHijri.hYear} AH",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              /// 🌟 Holiday text appears only when available
              if (holiday != null && holiday.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  holiday,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 📅 Calendar takes full remaining space
  Widget _calendarSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
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

          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
            weekendStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),

          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          calendarBuilders: CalendarBuilders(
            defaultBuilder: _dayTile,
            todayBuilder: _todayTile,
            selectedBuilder: _selectedTile,
          ),
        ),
      ),
    );
  }

  // 🟦 Legend pinned bottom
  Widget _legend() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendItem(Colors.lightBlue, "Selected"),
          _legendItem(Colors.lightGreen, "Holiday"),
          _legendItem(Colors.deepPurpleAccent, "Today"),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }

  Widget _dayTile(context, day, _) {
    final hijri = HijriCalendar.fromDate(day);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _isHoliday(day)
            ? Colors.lightGreen.withOpacity(0.6)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isHoliday(day) ? Colors.green : Colors.grey.shade400,
        ),
      ),
      child: _dayContent(day, hijri),
    );
  }

  Widget _todayTile(context, day, _) {
    final hijri = HijriCalendar.fromDate(day);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: _dayContent(day, hijri, textColor: Colors.white),
    );
  }

  Widget _selectedTile(context, day, _) {
    final hijri = HijriCalendar.fromDate(day);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.lightBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: _dayContent(day, hijri, textColor: Colors.white),
    );
  }

  Widget _dayContent(
    DateTime day,
    HijriCalendar hijri, {
    Color textColor = Colors.black,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${day.day}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "${hijri.hDay}",
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}
