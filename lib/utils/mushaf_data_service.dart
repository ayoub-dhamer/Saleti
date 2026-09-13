import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single source of truth for the Quran font family — used both here (for
/// sizing measurements) and in MushafTextPage (for actual rendering), so
/// the two can never silently drift apart.
const String kQuranFontFamily = 'amiri';

class MushafWordElement {
  final String type; // 'word' or 'ayah_end'
  final int surah;
  final int ayah;
  String? text;
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

  MushafWordElement clone() {
    return MushafWordElement(
      type: type,
      surah: surah,
      ayah: ayah,
      text: text,
      symbol: symbol,
      numberAr: numberAr,
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

  /// Builds the exact plain-text representation of a line as it will
  /// actually be rendered (words + ayah-end marker glyphs), for measurement
  /// purposes. Must match _buildSpansFromSegments' text content exactly,
  /// or the sizing calculation will silently drift from the real render.
  String _plainLineText(MushafLine line) {
    final buffer = StringBuffer();
    for (int i = 0; i < line.elements.length; i++) {
      final el = line.elements[i];
      if (el.type == 'word') {
        buffer.write(el.text ?? '');
      } else if (el.type == 'ayah_end') {
        buffer.write('\u06DD${el.numberAr ?? ''}');
      }
      if (i < line.elements.length - 1) buffer.write(' ');
    }
    return buffer.toString();
  }

  final Map<int, double> _fontSizeCache = {};

  /// Computes the single fixed font size that guarantees the single widest
  /// natural line in the whole book fits [availableWidth] on one line.
  /// CHANGED: previously scored lines with a crude word-length heuristic
  /// and measured using 'Amiri' — a font never actually used for rendering.
  /// Now measures every line's TRUE natural width directly, in the SAME
  /// font (kQuranFontFamily) actually used to render it, then scales
  /// linearly to fit — both more accurate and simpler than a binary search.
  double computeFixedFontSize(
    double availableWidth, {
    double referenceFontSize = 20,
    double minFont = 12,
    double maxFont = 34,
  }) {
    final key = availableWidth.round();
    final cached = _fontSizeCache[key];
    if (cached != null) return cached;

    double maxNaturalWidth = 0;

    for (final page in _pages.values) {
      for (final line in page.lines) {
        final text = _plainLineText(line);
        if (text.isEmpty) continue;

        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: const TextStyle(
              fontFamily: kQuranFontFamily,
              fontSize: 20, // fixed reference size for measurement
            ),
          ),
          textDirection: TextDirection.rtl,
          maxLines: 1,
        )..layout();

        if (tp.width > maxNaturalWidth) maxNaturalWidth = tp.width;
      }
    }

    double fontSize = maxNaturalWidth > 0
        ? (availableWidth / maxNaturalWidth) * referenceFontSize
        : maxFont;

    fontSize = fontSize.clamp(minFont, maxFont);

    _fontSizeCache[key] = fontSize;
    return fontSize;
  }
}
