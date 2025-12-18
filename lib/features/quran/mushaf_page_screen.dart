import 'package:flutter/material.dart';

class MushafPageScreen extends StatefulWidget {
  final int initialPage; // 1 → 604

  const MushafPageScreen({super.key, this.initialPage = 1});

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f2e8), // Mushaf paper color
      body: PageView.builder(
        controller: _controller,
        itemCount: 604,
        itemBuilder: (context, index) {
          final pageNumber = index + 1;
          return InteractiveViewer(
            minScale: 1,
            maxScale: 3,
            child: Image.asset(
              'assets/mushaf/page_${pageNumber.toString().padLeft(3, '0')}.png',
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }
}
