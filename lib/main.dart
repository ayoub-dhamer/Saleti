import 'package:flutter/material.dart';
import 'navigation/main_navigation.dart';

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
      theme: ThemeData(
        fontFamily: 'Amiri',
        useMaterial3: false,
        primaryColor: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MainNavigation(),
    );
  }
}
