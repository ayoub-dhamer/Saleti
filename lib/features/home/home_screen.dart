import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Background Pattern
          Positioned.fill(
            child: Image.asset(
              "assets/images/islamic_pattern.png",
              fit: BoxFit.cover,
            ),
          ),

          // 🔹 Dark overlay for readability
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.45)),
          ),

          // 🔹 Main content scrollable
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // 🔹 Hijri Date + Islamic Greeting
                  Text(
                    "Assalamu Alaikum",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "15 Sha’ban 1446 AH",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 🔹 NEXT PRAYER CARD
                  _nextPrayerCard(),

                  const SizedBox(height: 25),

                  // 🔹 PRAYER TIMES LIST
                  Text(
                    "Today's Prayers",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _prayerCard("Fajr", "05:12 AM"),
                  _prayerCard("Dhuhr", "12:45 PM"),
                  _prayerCard("Asr", "04:10 PM"),
                  _prayerCard("Maghrib", "06:23 PM"),
                  _prayerCard("Isha", "07:45 PM"),

                  const SizedBox(height: 30),

                  // 🔹 QUICK ACTION BUTTONS
                  _quickActions(),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------
  // 🔸 NEXT PRAYER CARD
  // -------------------------------------------
  Widget _nextPrayerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Next Prayer",
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            "Dhuhr",
            style: GoogleFonts.poppins(
              fontSize: 26,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "in 02:14:56",
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.tealAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------
  // 🔸 PRAYER CARD
  // -------------------------------------------
  Widget _prayerCard(String name, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 17,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            time,
            style: GoogleFonts.poppins(fontSize: 17, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------
  // 🔸 QUICK ACTION BUTTONS
  // -------------------------------------------
  Widget _quickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _actionButton(Icons.explore, "Qibla"),
        _actionButton(Icons.calendar_month, "Calendar"),
        _actionButton(Icons.menu_book, "Quran"),
        _actionButton(Icons.settings, "Settings"),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        ),
      ],
    );
  }
}
