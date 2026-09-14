import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String kQuranFontFamily = 'UthmanicHafs';

class MushafWordElement {
  final String type;
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
/// CHANGED: now also a ChangeNotifier — listeners are notified once the
/// one-time "widest line in the book" scan finishes in the background,
/// so a page built before that's ready can refine its font size shortly
/// after, instead of the calling code blocking on it.
class MushafDataService extends ChangeNotifier {
  static final MushafDataService _instance = MushafDataService._internal();
  factory MushafDataService() => _instance;
  MushafDataService._internal();

  final Map<int, MushafPageData> _pages = {};
  bool _loaded = false;
  bool get isLoaded => _loaded;

  static const double _referenceFontSize = 20;
  static const double _fallbackFontSize =
      20; // used instantly, before the one-time scan finishes

  // CHANGED: this is now the ONLY expensive value, computed exactly once
  // per app session — not once per distinct availableWidth like before.
  double? _maxNaturalWidthAtReference;
  bool _isWarmingUp = false;

  Future<void> load() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString('assets/data/mushaf_complete.json');
    final Map<String, dynamic> decoded = jsonDecode(raw);

    decoded.forEach((key, value) {
      final pageNum = int.parse(key);
      _pages[pageNum] = MushafPageData.fromJson(value);
    });

    _loaded = true;

    // ADD: fire-and-forget — starts warming up the expensive measurement
    // right away, in the background, typically well before the user has
    // navigated to the Mushaf screen at all.
    _warmUpMaxNaturalWidth();
  }

  MushafPageData? getPage(int pageNumber) => _pages[pageNumber];

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

  // ADD: the one-time scan, broken into small chunks with a yield between
  // each, so even if it's still running when the reader opens, it never
  // blocks a single frame for long — the UI stays smooth throughout.
  Future<void> _warmUpMaxNaturalWidth() async {
    if (_isWarmingUp || _maxNaturalWidthAtReference != null) return;
    _isWarmingUp = true;

    double maxWidth = 0;
    int pagesProcessed = 0;

    for (final page in _pages.values) {
      for (final line in page.lines) {
        final text = _plainLineText(line);
        if (text.isEmpty) continue;

        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: const TextStyle(
              fontFamily: kQuranFontFamily,
              fontSize: _referenceFontSize,
            ),
          ),
          textDirection: TextDirection.rtl,
          maxLines: 1,
        )..layout();

        if (tp.width > maxWidth) maxWidth = tp.width;
      }

      pagesProcessed++;
      if (pagesProcessed % 40 == 0) {
        // Yield back to the event loop every 40 pages — keeps this from
        // ever freezing a single frame, even during the one-time warm-up.
        await Future.delayed(Duration.zero);
      }
    }

    _maxNaturalWidthAtReference = maxWidth;
    _isWarmingUp = false;
    notifyListeners(); // lets any open Mushaf screen refine its font size now that the real value is ready
  }

  final Map<int, double> _fontSizeCache = {};

  /// CHANGED: now always fast and synchronous-safe to call from build().
  /// Returns instantly — either the real best-fit size (if the one-time
  /// scan has already finished, which is the common case since it starts
  /// warming up as soon as the JSON loads) or a sensible fallback while
  /// that's still running in the background.
  double computeFixedFontSize(
    double availableWidth, {
    double minFont = 12,
    double maxFont = 34,
  }) {
    if (_maxNaturalWidthAtReference == null) {
      _warmUpMaxNaturalWidth(); // no-op if already running
      return _fallbackFontSize.clamp(minFont, maxFont);
    }

    final key = availableWidth.round();
    final cached = _fontSizeCache[key];
    if (cached != null) return cached;

    double fontSize =
        (availableWidth / _maxNaturalWidthAtReference!) * _referenceFontSize;
    fontSize = fontSize.clamp(minFont, maxFont);

    _fontSizeCache[key] = fontSize;
    return fontSize;
  }
}
