import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:saleti/data/juz_data.dart';
import 'package:saleti/utils/mushaf_data_service.dart';

class MushafTextPage extends StatelessWidget {
  final int pageNumber;
  final bool isLectureMode;
  final Color textColor;
  final Color accentColor;

  const MushafTextPage({
    super.key,
    required this.pageNumber,
    this.isLectureMode = false,
    this.textColor = Colors.black,
    this.accentColor = const Color(0xFF1FA45B),
  });

  static const int _totalSlots = 15;
  static const double _ayahBadgeSize =
      26; // ADD: fixed pixel size, doesn't scale with font
  static const double _bodyFontSize = 21;
  static const double _lectureFontSize = 27;

  static const double _frameInsetLeft = 0.10;
  static const double _frameInsetRight = 0.10;
  static const double _frameInsetTop = 0.095;
  static const double _frameInsetBottom = 0.095;
  static const String _quranFontFamily = 'amiri';

  @override
  Widget build(BuildContext context) {
    final page = MushafDataService().getPage(pageNumber);

    if (page == null) {
      return const Center(child: Text('Page not available'));
    }

    if (isLectureMode) {
      return _buildContent(page);
    }

    final isDarkMode =
        Theme.of(context).brightness == Brightness.dark ||
        textColor.computeLuminance() > 0.5;

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
            Image.asset(frameAsset, fit: BoxFit.fill),
            Positioned(
              left: width * _frameInsetLeft,
              right: width * _frameInsetRight,
              top: height * _frameInsetTop,
              bottom: height * _frameInsetBottom,
              child: _buildContent(page),
            ),
            Positioned(
              top: height * 0.02,
              right: width * 0.20,
              child: _cornerLabel(_juzLabel(page)),
            ),
            Positioned(
              top: height * 0.02,
              left: width * 0.2,
              child: _cornerLabel(_surahLabel(page)),
            ),
            Positioned(
              bottom: height * 0.01,
              left: 0,
              right: 0,
              child: Center(child: _cornerLabel('$pageNumber')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(MushafPageData page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // CHANGED: one fixed font size, computed once for this available
        // width and reused for every line on the page (and every other
        // page at the same width, via the service's cache).
        final availableTextWidth =
            constraints.maxWidth - (isLectureMode ? 40 : 16);
        final fontSize = MushafDataService().computeFixedFontSize(
          availableTextWidth,
        );

        final lineMap = {for (final l in page.lines) l.lineNumber: l};
        final slots = <Widget>[];

        int i = 1;
        while (i <= _totalSlots) {
          if (lineMap.containsKey(i)) {
            slots.add(
              Expanded(
                child: Center(
                  child: _buildTextLine(
                    lineMap[i]!,
                    fontSize,
                    constraints.maxWidth - (isLectureMode ? 40 : 16),
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
                // CHANGED: OverflowBox instead of shrinking — the banner
                // renders at its natural fixed-font size; on very tight
                // header gaps it may slightly overlap the neighboring slot
                // rather than shrinking text, per your request to keep
                // sizes fixed everywhere.
                child: nextSurah != null
                    ? OverflowBox(
                        maxHeight: double.infinity,
                        alignment: Alignment.center,
                        child: _surahBanner(
                          nextSurah,
                          includeBismillah: gapLen >= 2 && nextSurah != 9,
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

  Widget _cornerLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: _quranFontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: textColor,
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
  ) {
    final segments = line.elements;
    if (segments.isEmpty) return const SizedBox.shrink();

    final renderSpans = <InlineSpan>[];

    for (int i = 0; i < segments.length; i++) {
      final el = segments[i];

      if (el.type == 'word') {
        renderSpans.add(
          TextSpan(
            text: el.text,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: isLectureMode ? _lectureFontSize : fontSize,
              color: textColor,
              // Slight word spacing aids full justification alignment
              wordSpacing: 1.5,
            ),
          ),
        );
        // Append standard space between words
        if (i < segments.length - 1) {
          renderSpans.add(const TextSpan(text: ' '));
        }
      } else if (el.type == 'ayah_end') {
        renderSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: _ayahBadgeSize,
                height: _ayahBadgeSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor, width: 1.4),
                  ),
                  child: Center(
                    child: Text(
                      el.numberAr ?? '',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        if (i < segments.length - 1) {
          renderSpans.add(const TextSpan(text: ' '));
        }
      }
    }

    return SizedBox(
      width: availableWidth,
      child: Text.rich(
        TextSpan(children: renderSpans),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify, // Native browser/OS justification engine
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      ),
    );
  }

  Widget _surahBanner(int surahNumber, {required bool includeBismillah}) {
    final arabicName = quran.getSurahNameArabic(surahNumber);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize
            .min, // CHANGED: was implicit max — min lets FittedBox measure natural size correctly
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 5,
            ), // CHANGED: tightened from 20/6
            decoration: BoxDecoration(
              border: Border.all(
                color: accentColor.withOpacity(0.6),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'سورة $arabicName',
              style: TextStyle(
                fontFamily: _quranFontFamily,
                fontWeight: FontWeight.bold,
                fontSize: isLectureMode
                    ? _lectureFontSize
                    : _bodyFontSize, // CHANGED: unified closer to body text scale (was 25/19 — now 24/20, less of a mismatch)
                color: textColor,
                height:
                    1.1, // ADD: tighter line box, avoids extra baked-in padding
              ),
            ),
          ),
          if (includeBismillah)
            Padding(
              padding: const EdgeInsets.only(
                top: 4,
              ), // CHANGED: was 6, tightened
              child: Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                style: TextStyle(
                  fontFamily: _quranFontFamily,
                  fontSize: isLectureMode
                      ? _lectureFontSize
                      : _bodyFontSize, // CHANGED: matches surah-name size now for visual consistency
                  height: 1.2, // CHANGED: was 1.4, tightened
                  color: textColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
