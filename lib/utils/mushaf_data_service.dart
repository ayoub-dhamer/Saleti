import 'dart:convert';
import 'package:flutter/material.dart';
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

  // ADD: the single most horizontally demanding line across the entire
  // 604-page book — used as the worst case for choosing one fixed font
  // size that guarantees every line, anywhere, fits without wrapping.
  MushafLine? _densestLine;

  MushafLine _findDensestLine() {
    if (_densestLine != null) return _densestLine!;

    MushafLine? worst;
    int worstScore = -1;

    for (final page in _pages.values) {
      for (final line in page.lines) {
        int score = 0;
        for (final el in line.elements) {
          if (el.type == 'word') {
            score +=
                (el.text?.length ?? 0) +
                1; // +1 approximates the inter-word gap
          } else {
            score += 6; // fixed rough weight for an ayah-end marker's footprint
          }
        }
        if (score > worstScore) {
          worstScore = score;
          worst = line;
        }
      }
    }

    _densestLine = worst;
    return worst!;
  }

  // ADD: cached fixed font size per available width, so the (somewhat
  // expensive) binary-search measurement only runs once per distinct
  // screen width, not on every page build.
  final Map<int, double> _fontSizeCache = {};

  /// Computes the single fixed font size that guarantees the densest line
  /// in the whole book fits [availableWidth] on one line — every other,
  /// shorter line then uses TextAlign.justify to stretch and fill the
  /// remaining width via inter-word spacing.
  double computeFixedFontSize(
    double availableWidth, {
    double ayahBadgeWidth = 28,
    double minFont = 14,
    double maxFont = 30,
  }) {
    final key = availableWidth.round();
    final cached = _fontSizeCache[key];
    if (cached != null) return cached;

    final densest = _findDensestLine();
    final wordsText = densest.elements
        .where((e) => e.type == 'word')
        .map((e) => e.text)
        .join('  ');
    final ayahCount = densest.elements
        .where((e) => e.type == 'ayah_end')
        .length;

    double lo = minFont, hi = maxFont, best = minFont;

    for (int i = 0; i < 20; i++) {
      final mid = (lo + hi) / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: wordsText,
          style: TextStyle(
            fontFamily: 'Amiri',
            fontSize: mid,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.rtl,
        maxLines: 1,
      )..layout();

      final neededWidth = tp.width + (ayahCount * ayahBadgeWidth);

      if (neededWidth <= availableWidth) {
        best = mid;
        lo = mid;
      } else {
        hi = mid;
      }
    }

    _fontSizeCache[key] = best;
    return best;
  }
}
