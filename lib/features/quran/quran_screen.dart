import 'package:flutter/material.dart';
import 'package:quran_library/quran_library.dart';

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      // ✅ VERY IMPORTANT: use Builder to get ROOT context
      builder: (rootContext) {
        return Scaffold(
          appBar: AppBar(title: const Text('Qur\'an')),

          body: QuranLibraryScreen(
            parentContext: rootContext, // ✅ FIX
            withPageView: true,
            useDefaultAppBar: false,
            isShowAudioSlider: false, // text only
          ),
        );
      },
    );
  }
}
