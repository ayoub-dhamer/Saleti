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

  // Islamic Events (Hijri dates)
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Hijri Calendar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurpleAccent,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🌙 SELECTED DATE INFO CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurpleAccent.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "${_selectedHijri.hDay} ${_selectedHijri.longMonthName} ${_selectedHijri.hYear} AH",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  if (_holidayName(_selectedDay!) != null)
                    Text(
                      _holidayName(_selectedDay!)!,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 📅 CALENDAR
            Expanded(
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

            const SizedBox(height: 10),

            // 🟦 LEGEND — added under the calendar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendItem(Colors.lightBlue, "Selected Day"),
                _legendItem(Colors.lightGreen, "Holiday"),
                _legendItem(Colors.deepPurpleAccent, "Today"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 📌 LEGEND ITEM WIDGET
  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
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

  // 📌 NORMAL DAY
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

  // ⭐ TODAY TILE
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

  // ⭐ SELECTED DAY TILE (Light Blue)
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

  // 📅 Reusable Day Content
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
