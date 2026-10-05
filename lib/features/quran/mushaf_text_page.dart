import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:saleti/data/juz_data.dart';
import 'package:saleti/utils/mushaf_data_service.dart';

// FIXED (Battery/CPU #3): see MushafTextPage._lineLayoutCache for why this
// exists. A record gives value-equality for free, so it works as a Map key
// with no custom hashCode/== to maintain.
typedef _LineLayoutKey = (
  int pageNumber,
  int lineNumber,
  double width,
  int fontSizeTenths,
  Color ayahEndColor,
  Color textColor,
);

class _JustifiedLine {
  final List<InlineSpan> spans;
  final double wordSpacing;
  const _JustifiedLine(this.spans, this.wordSpacing);
}

class MushafTextPage extends StatelessWidget {
  final int pageNumber;
  final bool isLectureMode;
  final Color? textColor;
  final Color accentColor;

  const MushafTextPage({
    super.key,
    required this.pageNumber,
    this.isLectureMode = false,
    this.textColor,
    this.accentColor = const Color(0xFF1FA45B),
  });

  static const int _totalSlots = 15;
  static const double _bodyFontSize = 23;
  static const double _lectureFontSize = 27;

  static const double _frameInsetLeft = 0.095;
  static const double _frameInsetRight = 0.095;
  static const double _frameInsetTop = 0.06;
  static const double _frameInsetBottom = 0.06;

  static const Set<int> _centeredPages = {602, 603, 604, 1, 2};

  static const Set<int> _verticallyCenteredPages = {1, 2};

  static const Set<int> _extraHeaderSlotPages = {
    77,
    208,
    332,
    342,
    350,
    367,
    377,
    415,
    418,
    446,
    453,
    499,
    507,
    526,
    549,
    556,
    558,
    585,
    587,
    591,
    595,
  };

  static const Set<int> _shortEndingPages = {
    76,
    207,
    331,
    341,
    349,
    366,
    376,
    414,
    417,
    445,
    452,
    498,
    506,
    525,
    548,
    555,
    557,
    584,
  };

  bool get _isCenteredPage => _centeredPages.contains(pageNumber);
  bool get _isVerticallyCenteredPage =>
      _verticallyCenteredPages.contains(pageNumber);

  // FIXED (Battery/CPU #3): MushafTextPage is a StatelessWidget rebuilt
  // fresh by its parent's PageView on every parent setState — including
  // the two _isPageSettled toggles per swipe (see MushafPageScreen) — so
  // without this cache, _justifyLine's ~3 TextPainter layouts plus a
  // regex-based kashida-insertion loop reran on the UI thread for every
  // one of a page's up to 15 lines, on every single one of those
  // rebuilds, even though the result is 100% determined by this record.
  // A static Map persists across those rebuilt instances for the app's
  // lifetime. Bounded domain (604 pages × 15 lines × however many
  // distinct width/fontSize/color combinations one session actually
  // sees), so this never grows unreasonably large.
  static final Map<_LineLayoutKey, _JustifiedLine> _lineLayoutCache = {};

  @override
  Widget build(BuildContext context) {
    final page = MushafDataService().getPage(pageNumber);

    if (page == null) {
      // FIXED (Battery/CPU #4): this showed the same "Page not available"
      // message regardless of *why* page was null — including the
      // entirely normal case where MushafDataService().load() (parsing a
      // multi-megabyte JSON file) simply hasn't finished yet, which a fast
      // cold start can easily reach this screen before. That's now told
      // apart from a genuinely missing page: loading finished and this
      // page still isn't in the data, which is an actual data problem.
      return Center(
        child: MushafDataService().isLoaded
            ? const Text('Page not available')
            : const CircularProgressIndicator(),
      );
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Resolves to custom passed textColor (light mode -> black, dark mode -> white)
    final Color resolvedTextColor =
        textColor ?? (isDarkMode ? Colors.white : Colors.black);

    final ayahEndColor = Colors.lightBlue;

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
              top: isLectureMode ? 55 : height * _frameInsetTop,
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

        // Calculate base font size from service
        final baseFontSize = MushafDataService().computeFixedFontSize(
          availableTextWidth,
        );

        // Increase font size on pages 1 and 2 (e.g., 25% larger)
        final fontSize = _isVerticallyCenteredPage
            ? baseFontSize * 1.5
            : baseFontSize;

        final lineMap = {for (final l in page.lines) l.lineNumber: l};
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        final headerSlots = <({int span, Widget child})>[];
        final bodySlots = <({int span, Widget child})>[];

        final lastContentLine = lineMap.keys.isEmpty
            ? 0
            : lineMap.keys.reduce((a, b) => a > b ? a : b);

        final lastSlot =
            (_isVerticallyCenteredPage ||
                _shortEndingPages.contains(
                  pageNumber,
                )) // CHANGED: was just `_isVerticallyCenteredPage`
            ? lastContentLine
            : _totalSlots;

        int i = 1;
        while (i <= lastSlot) {
          if (lineMap.containsKey(i)) {
            final slot = (
              span: 1,
              child: Center(
                child: _buildTextLine(
                  lineMap[i]!,
                  fontSize,
                  availableTextWidth,
                  ayahEndColor,
                  effectiveTextColor,
                ),
              ),
            );

            // Add to body slots
            bodySlots.add(slot);
            i++;
          } else {
            final gapStart = i;
            while (i <= lastSlot && !lineMap.containsKey(i)) {
              i++;
            }
            final gapLen = i - gapStart;

            int? nextSurah;
            if (i <= lastSlot &&
                lineMap.containsKey(i) &&
                lineMap[i]!.elements.isNotEmpty) {
              nextSurah = lineMap[i]!.elements.first.surah;
            }

            final slot = (
              span:
                  _extraHeaderSlotPages.contains(
                    pageNumber,
                  ) // CHANGED: was `span: gapLen`
                  ? gapLen + 1
                  : gapLen,
              child: nextSurah != null
                  ? OverflowBox(
                      maxHeight: double.infinity,
                      alignment: Alignment.center,
                      child: _surahBanner(
                        nextSurah,
                        includeBismillah: nextSurah != 9 && nextSurah != 1,
                        effectiveTextColor: effectiveTextColor,
                        isDarkMode: isDarkMode,
                      ),
                    )
                  : const SizedBox.shrink(),
            );

            // If on pages 1-2 and no body lines have been processed yet,
            // treat this banner/basmallah gap as the non-centered header.
            if (_isVerticallyCenteredPage && bodySlots.isEmpty) {
              headerSlots.add(slot);
            } else {
              bodySlots.add(slot);
            }
          }
        }

        final double verticalPadding = isLectureMode ? 16 : 4;
        final padding = EdgeInsets.symmetric(
          horizontal: isLectureMode ? 20 : 8,
          vertical: verticalPadding,
        );

        final gridHeight = constraints.maxHeight - (verticalPadding * 2);
        final slotHeight = gridHeight / _totalSlots;

        if (_isVerticallyCenteredPage) {
          // Define a vertical spacing multiplier for body lines on pages 1 & 2
          const double lineSpacingMultiplier = 1.5;

          return Padding(
            padding: padding,
            child: Column(
              children: [
                // 1. Top Surah Banner & Basmallah (Stays at top)
                for (final slot in headerSlots)
                  SizedBox(height: slotHeight * slot.span, child: slot.child),

                // 2. Vertically Centered Quranic Text
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final slot in bodySlots)
                          SizedBox(
                            height:
                                slotHeight * slot.span * lineSpacingMultiplier,
                            child: slot.child,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final allSlots = [...headerSlots, ...bodySlots];
        return Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              for (final slot in allSlots)
                Expanded(flex: slot.span, child: slot.child),
            ],
          ),
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
  ) {
    final segments = line.elements;
    if (segments.isEmpty) return const SizedBox.shrink();

    // FIXED (Battery/CPU #3): was computed fresh on every build — see the
    // cache field above for why that was expensive and how often it ran.
    // Rounding width/fontSize to whole units avoids sub-pixel
    // floating-point jitter between rebuilds splitting what's really the
    // same layout into separate cache entries.
    final key = (
      pageNumber,
      line.lineNumber,
      availableWidth.roundToDouble(),
      (fontSize * 10).round(),
      ayahEndColor,
      activeTextColor,
    );

    final justified = _lineLayoutCache.putIfAbsent(
      key,
      () => _justifyLine(
        segments,
        fontSize,
        availableWidth,
        ayahEndColor,
        activeTextColor,
      ),
    );

    return SizedBox(
      width: availableWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text.rich(
          TextSpan(
            style: TextStyle(wordSpacing: justified.wordSpacing),
            children: justified.spans,
          ),
          textDirection: TextDirection.rtl,
          softWrap: false,
          // FIXED (Battery/CPU #4): without this, the rendered line
          // follows the system's accessibility text-scale setting, but
          // the measurements below that decide how many kashida
          // characters and how much word-spacing to add do NOT (Flutter's
          // TextPainter defaults to no scaling) — so on a device with
          // text scaling turned up, the actually-rendered line would be
          // wider than what was measured against availableWidth,
          // defeating the justification this method exists to do, and
          // FittedBox would then shrink each line by a different amount
          // to compensate, breaking consistent font size across the page.
          // This view already has its own dedicated font-size control
          // (MushafDataService.computeFixedFontSize), so pinning it here
          // is intentional, not a missed accessibility feature.
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }

  /// The expensive computation _buildTextLine's cache exists to avoid
  /// redoing: unchanged logic from before, just extracted so it only
  /// actually runs on a cache miss.
  _JustifiedLine _justifyLine(
    List<MushafWordElement> segments,
    double fontSize,
    double availableWidth,
    Color ayahEndColor,
    Color activeTextColor,
  ) {
    final naturalSpans = _buildSpansFromSegments(
      segments,
      fontSize,
      ayahEndColor,
      activeTextColor,
    );

    // ADD: centered pages render at natural width — no kashida, no word-spacing
    // top-up. Returning early also skips that measurement work entirely.
    if (_isCenteredPage) {
      return _JustifiedLine(naturalSpans, 0.0);
    }

    final naturalWidth = _measureSpanWidth(naturalSpans);
    final targetExtraWidth = (availableWidth - naturalWidth).clamp(
      0.0,
      double.infinity,
    );

    final kashidaSpans = targetExtraWidth > 0
        ? _applyDynamicKashida(
            segments,
            fontSize,
            targetExtraWidth,
            ayahEndColor,
            activeTextColor,
          )
        : naturalSpans;

    final afterKashidaWidth = _measureSpanWidth(kashidaSpans);
    final gapCount = segments.length - 1;
    final leftover = availableWidth - afterKashidaWidth;
    final topUpSpacing = (gapCount > 0 && leftover > 0)
        ? leftover / gapCount
        : 0.0;

    return _JustifiedLine(kashidaSpans, topUpSpacing);
  }

  double _measureSpanWidth(List<InlineSpan> spans) {
    final painter = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      // FIXED (Battery/CPU #4): explicit, even though this is already
      // TextPainter's default — see the matching textScaler on the
      // rendered Text.rich above for why measurement and render must
      // always agree here.
      textScaler: TextScaler.noScaling,
    )..layout();
    return painter.width;
  }

  List<InlineSpan> _applyDynamicKashida(
    List<MushafWordElement> segments,
    double fontSize,
    double targetExtraWidth,
    Color ayahEndColor,
    Color activeTextColor,
  ) {
    const kashidaChar = 'ـ';
    final mutatedSegments = segments.map((e) => e.clone()).toList();

    final singleKashidaWidth = _measureSpanWidth([
      TextSpan(
        text: kashidaChar,
        style: TextStyle(
          fontFamily: kQuranFontFamily,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    ]);

    if (singleKashidaWidth <= 0) {
      return _buildSpansFromSegments(
        segments,
        fontSize,
        ayahEndColor,
        activeTextColor,
      );
    }

    int kashidasToInsert = (targetExtraWidth / singleKashidaWidth).floor();

    final stretchableRegex = RegExp(
      r'([بتثجحخسشصضطظعغفقكلمنهي])((?:[\u064B-\u065F\u0670\u06D6-\u06ED])*)(?=[بتثجحخسشصضطظعغفقكلمنهي])',
    );

    while (kashidasToInsert > 0) {
      bool insertedAny = false;

      for (final el in mutatedSegments) {
        if (el.type == 'word' && el.text != null && kashidasToInsert > 0) {
          if (stretchableRegex.hasMatch(el.text!)) {
            el.text = el.text!.replaceFirstMapped(
              stretchableRegex,
              (match) => '${match.group(1)}${match.group(2)}$kashidaChar',
            );
            kashidasToInsert--;
            insertedAny = true;
          }
        }
      }
      if (!insertedAny) break;
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
