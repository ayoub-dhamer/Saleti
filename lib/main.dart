import 'package:flutter/material.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const SaletiApp());
}

class SaletiApp extends StatelessWidget {
  const SaletiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saleti',

      // ✅ REQUIRED FOR quran_library
      theme: ThemeData(
        useMaterial3: false, // IMPORTANT
        primaryColor: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),

      home: const HomeScreen(),
    );
  }
}
