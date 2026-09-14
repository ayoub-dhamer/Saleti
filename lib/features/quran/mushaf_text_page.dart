import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:saleti/data/juz_data.dart';
import 'package:saleti/utils/mushaf_data_service.dart';

class MushafTextPage extends StatelessWidget {
  final int pageNumber;
  final bool isLectureMode;
  final Color? textColor;
  final Color accentColor;

  static final Map<String, List<InlineSpan>> _lineSpanCache = {};
  static final Map<double, double> _kashidaWidthCache = {};

  String _getCacheKey({
    required int pageNum,
    required int lineNum,
    required double width,
    required bool isDark,
  }) {
    return '$pageNum-$lineNum-${width.toStringAsFixed(1)}-$isDark-$isLectureMode';
  }

  const MushafTextPage({
    super.key,
    required this.pageNumber,
    this.isLectureMode = false,
    this.textColor,
    this.accentColor = const Color(0xFF1FA45B),
  });

  static const int _totalSlots = 15;
  static const double _bodyFontSize = 27;
  static const double _lectureFontSize = 27;

  static const double _frameInsetLeft = 0.095;
  static const double _frameInsetRight = 0.095;
  static const double _frameInsetTop = 0.06;
  static const double _frameInsetBottom = 0.06;

  // mushaf_text_page.dart

  // mushaf_text_page.dart

  // In mushaf_text_page.dart

  @override
  Widget build(BuildContext context) {
    final page = MushafDataService().getPage(pageNumber);

    if (page == null) {
      return const Center(child: Text('Page not available'));
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Resolves to custom passed textColor (light mode -> black, dark mode -> white)
    final Color resolvedTextColor =
        textColor ?? (isDarkMode ? Colors.white : Colors.black);

    final ayahEndColor = isDarkMode ? accentColor : Colors.lightBlue;

    final frameAsset = isDarkMode
        ? 'assets/images/mushaf_frame_dark.png'
        : 'assets/images/mushaf_frame_light.png';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (!isLectureMode) Image.asset(frameAsset, fit: BoxFit.fill),
            Positioned(
              left: isLectureMode ? 0 : width * _frameInsetLeft,
              right: isLectureMode ? 0 : width * _frameInsetRight,
              top: isLectureMode ? 100 : height * _frameInsetTop,
              bottom: isLectureMode ? 0 : height * _frameInsetBottom,
              child: _buildContent(page, ayahEndColor, resolvedTextColor),
            ),
            if (!isLectureMode) ...[
              Positioned(
                top: height * 0.02,
                right: width * 0.20,
                child: _cornerLabel(_juzLabel(page), resolvedTextColor),
              ),
              Positioned(
                top: height * 0.02,
                left: width * 0.2,
                child: _cornerLabel(_surahLabel(page), resolvedTextColor),
              ),
              Positioned(
                bottom: height * 0.01,
                left: 0,
                right: 0,
                child: Center(
                  child: _cornerLabel('$pageNumber', resolvedTextColor),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildContent(
    MushafPageData page,
    Color ayahEndColor,
    Color effectiveTextColor,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableTextWidth =
            constraints.maxWidth - (isLectureMode ? 40 : 16);
        final fontSize = MushafDataService().computeFixedFontSize(
          availableTextWidth,
        );

        final lineMap = {for (final l in page.lines) l.lineNumber: l};
        final slots = <Widget>[];

        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        int i = 1;
        while (i <= _totalSlots) {
          if (lineMap.containsKey(i)) {
            slots.add(
              Expanded(
                child: Center(
                  child: _buildTextLine(
                    lineMap[i]!,
                    fontSize,
                    availableTextWidth,
                    ayahEndColor,
                    effectiveTextColor,
                    page.pageNumber,
                    isDarkMode,
                  ),
                ),
              ),
            );
            i++;
          } else {
            final gapStart = i;
            while (i <= _totalSlots && !lineMap.containsKey(i)) {
              i++;
            }
            final gapLen = i - gapStart;

            int? nextSurah;
            if (i <= _totalSlots &&
                lineMap.containsKey(i) &&
                lineMap[i]!.elements.isNotEmpty) {
              nextSurah = lineMap[i]!.elements.first.surah;
            }

            slots.add(
              Expanded(
                flex: gapLen,
                child: nextSurah != null
                    ? OverflowBox(
                        maxHeight: double.infinity,
                        alignment: Alignment.center,
                        child: _surahBanner(
                          nextSurah,
                          includeBismillah: gapLen >= 2 && nextSurah != 9,
                          effectiveTextColor: effectiveTextColor,
                          isDarkMode: isDarkMode,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }
        }

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLectureMode ? 20 : 8,
            vertical: isLectureMode ? 16 : 4,
          ),
          child: Column(mainAxisSize: MainAxisSize.max, children: slots),
        );
      },
    );
  }

  Widget _cornerLabel(String text, Color activeTextColor) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: kQuranFontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: activeTextColor,
      ),
    );
  }

  String _juzLabel(MushafPageData page) {
    final juz = juzForPage(page.pageNumber);
    return 'الجزء $juz';
  }

  String _surahLabel(MushafPageData page) {
    if (page.lines.isEmpty || page.lines.first.elements.isEmpty) {
      return page.surahsOnPage.isNotEmpty ? page.surahsOnPage.first : '';
    }
    final surahNumber = page.lines.first.elements.first.surah;
    return quran.getSurahNameArabic(surahNumber);
  }

  Widget _buildTextLine(
    MushafLine line,
    double fontSize,
    double availableWidth,
    Color ayahEndColor,
    Color activeTextColor,
    int pageNum,
    bool isDarkMode,
  ) {
    final segments = line.elements;
    if (segments.isEmpty) return const SizedBox.shrink();

    final cacheKey = _getCacheKey(
      pageNum: pageNum,
      lineNum: line.lineNumber,
      width: availableWidth,
      isDark: isDarkMode,
    );

    // 1. Retrieve cached spans if available
    List<InlineSpan>? kashidaSpans = _lineSpanCache[cacheKey];

    if (kashidaSpans == null) {
      // 2. Compute only on cache miss
      final naturalSpans = _buildSpansFromSegments(
        segments,
        fontSize,
        ayahEndColor,
        activeTextColor,
      );
      final naturalWidth = _measureSpanWidth(naturalSpans);
      final targetExtraWidth = (availableWidth - naturalWidth).clamp(
        0.0,
        double.infinity,
      );

      kashidaSpans = targetExtraWidth > 0
          ? _applyDynamicKashida(
              segments,
              fontSize,
              targetExtraWidth,
              ayahEndColor,
              activeTextColor,
            )
          : naturalSpans;

      // 3. Save to cache
      _lineSpanCache[cacheKey] = kashidaSpans;
    }

    final afterKashidaWidth = _measureSpanWidth(kashidaSpans);
    final gapCount = segments.length - 1;
    final leftover = availableWidth - afterKashidaWidth;
    final topUpSpacing = (gapCount > 0 && leftover > 0)
        ? leftover / gapCount
        : 0.0;

    return SizedBox(
      width: availableWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text.rich(
          TextSpan(
            style: TextStyle(wordSpacing: topUpSpacing),
            children: kashidaSpans,
          ),
          textDirection: TextDirection.rtl,
          softWrap: false,
        ),
      ),
    );
  }

  double _measureSpanWidth(List<InlineSpan> spans) {
    final painter = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  double _getKashidaWidth(double fontSize) {
    return _kashidaWidthCache.putIfAbsent(fontSize, () {
      final painter = TextPainter(
        text: TextSpan(
          text: 'ـ',
          style: TextStyle(
            fontFamily: kQuranFontFamily,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
        textDirection: TextDirection.rtl,
        maxLines: 1,
      )..layout();
      return painter.width;
    });
  }

  List<InlineSpan> _applyDynamicKashida(
    List<MushafWordElement> segments,
    double fontSize,
    double targetExtraWidth,
    Color ayahEndColor,
    Color activeTextColor,
  ) {
    const kashidaChar = 'ـ';
    final singleKashidaWidth = _getKashidaWidth(fontSize);

    if (singleKashidaWidth <= 0) {
      return _buildSpansFromSegments(
        segments,
        fontSize,
        ayahEndColor,
        activeTextColor,
      );
    }

    int kashidasToInsert = (targetExtraWidth / singleKashidaWidth).floor();
    if (kashidasToInsert <= 0) {
      return _buildSpansFromSegments(
        segments,
        fontSize,
        ayahEndColor,
        activeTextColor,
      );
    }

    final mutatedSegments = segments.map((e) => e.clone()).toList();
    final stretchableRegex = RegExp(
      r'([بتثجحخسشصضطظعغفقكلمنهي])((?:[\u064B-\u065F\u0670\u06D6-\u06ED])*)(?=[بتثجحخسشصضطظعغفقكلمنهي])',
    );

    // Distribute kashidas in a single pass instead of a while loop
    for (final el in mutatedSegments) {
      if (kashidasToInsert <= 0) break;
      if (el.type == 'word' && el.text != null) {
        final matches = stretchableRegex.allMatches(el.text!).toList();
        if (matches.isNotEmpty) {
          // Insert available kashidas across eligible spots in this word
          el.text = el.text!.replaceFirstMapped(stretchableRegex, (match) {
            kashidasToInsert--;
            return '${match.group(1)}${match.group(2)}$kashidaChar';
          });
        }
      }
    }

    return _buildSpansFromSegments(
      mutatedSegments,
      fontSize,
      ayahEndColor,
      activeTextColor,
    );
  }

  List<InlineSpan> _buildSpansFromSegments(
    List<MushafWordElement> segments,
    double fontSize,
    Color ayahEndColor,
    Color activeTextColor,
  ) {
    final renderSpans = <InlineSpan>[];

    for (int i = 0; i < segments.length; i++) {
      final el = segments[i];

      if (el.type == 'word') {
        renderSpans.add(
          TextSpan(
            text: el.text ?? '',
            style: TextStyle(
              fontFamily: kQuranFontFamily,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
              color: activeTextColor,
            ),
          ),
        );
      } else if (el.type == 'ayah_end') {
        renderSpans.add(
          TextSpan(
            text: '\u06DD${el.numberAr ?? ''}',
            style: TextStyle(
              fontFamily: kQuranFontFamily,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: ayahEndColor,
            ),
          ),
        );
      }

      if (i < segments.length - 1) {
        renderSpans.add(const TextSpan(text: ' '));
      }
    }

    return renderSpans;
  }

  Widget _surahBanner(
    int surahNumber, {
    required bool includeBismillah,
    required Color effectiveTextColor,
    required bool isDarkMode,
  }) {
    final arabicName = quran.getSurahNameArabic(surahNumber);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 350,
            child: _surahBannerImage(
              arabicName,
              isDarkMode: isDarkMode,
              textColor: effectiveTextColor,
            ),
          ),
          if (includeBismillah)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                style: TextStyle(
                  fontFamily: kQuranFontFamily,
                  fontSize: isLectureMode ? _lectureFontSize : _bodyFontSize,
                  height: 1.2,
                  color:
                      effectiveTextColor, // Updated to use effectiveTextColor
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ADD: the banner artwork with the surah name overlaid, kept clear of the
  // ornate scroll medallions on each end.
  Widget _surahBannerImage(
    String arabicName, {
    required bool isDarkMode,
    required Color textColor,
  }) {
    final bannerAsset = isDarkMode
        ? 'assets/images/surah_name_frame_dark.png'
        : 'assets/images/surah_name_frame_light.png';

    return AspectRatio(
      aspectRatio: 550 / 62,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(bannerAsset, fit: BoxFit.fill),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.16),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'سورة $arabicName',
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: kQuranFontFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: isLectureMode
                            ? _lectureFontSize
                            : _bodyFontSize,
                        color:
                            textColor, // Updated to use non-null resolved textColor
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
