import 'dart:convert';
import 'package:flutter/services.dart';

class MushafWordElement {
  final String type; // 'word' or 'ayah_end'
  final int surah;
  final int ayah;
  final String? text;
  final String? symbol;
  final String? numberAr;

  MushafWordElement({
    required this.type,
    required this.surah,
    required this.ayah,
    this.text,
    this.symbol,
    this.numberAr,
  });

  factory MushafWordElement.fromJson(Map<String, dynamic> json) {
    return MushafWordElement(
      type: json['type'],
      surah: json['surah'],
      ayah: json['ayah'],
      text: json['text'],
      symbol: json['symbol'],
      numberAr: json['number_ar'],
    );
  }
}

class MushafLine {
  final int lineNumber;
  final List<MushafWordElement> elements;

  MushafLine({required this.lineNumber, required this.elements});

  factory MushafLine.fromJson(Map<String, dynamic> json) {
    return MushafLine(
      lineNumber: json['line_number'],
      elements: (json['elements'] as List)
          .map((e) => MushafWordElement.fromJson(e))
          .toList(),
    );
  }
}

class MushafPageData {
  final int pageNumber;
  final List<String> surahsOnPage;
  final List<MushafLine> lines;

  MushafPageData({
    required this.pageNumber,
    required this.surahsOnPage,
    required this.lines,
  });

  factory MushafPageData.fromJson(Map<String, dynamic> json) {
    return MushafPageData(
      pageNumber: json['page_number'],
      surahsOnPage: List<String>.from(json['surahs_on_page'] ?? []),
      lines: (json['lines'] as List)
          .map((l) => MushafLine.fromJson(l))
          .toList(),
    );
  }
}

/// Loads and caches the full 604-page Uthmani-script Qur'an text dataset.
/// Parsed once, kept in memory for the lifetime of the app.
class MushafDataService {
  static final MushafDataService _instance = MushafDataService._internal();
  factory MushafDataService() => _instance;
  MushafDataService._internal();

  final Map<int, MushafPageData> _pages = {};
  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString('assets/data/mushaf_complete.json');
    final Map<String, dynamic> decoded = jsonDecode(raw);

    decoded.forEach((key, value) {
      final pageNum = int.parse(key);
      _pages[pageNum] = MushafPageData.fromJson(value);
    });

    _loaded = true;
  }

  MushafPageData? getPage(int pageNumber) => _pages[pageNumber];
}
