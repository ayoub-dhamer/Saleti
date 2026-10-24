import 'package:flutter/material.dart';

/// FIXED (Store/legal #3): no in-app attribution existed anywhere for the
/// Amiri font, the Qur'an text, the mushaf page-layout data, or the frame
/// images — all four need it; Amiri's own OFL license requires it, and an
/// Islamic app misattributing (or not attributing) its Qur'an text source
/// is a trust problem as much as a legal one. Reached from Settings.
///
/// IMPORTANT — read before shipping this: I only know the Amiri font's
/// source and license with real confidence; it's an identifiable,
/// well-known open font (amiri-regular.ttf / amiri-bold.ttf are
/// unambiguous). I do NOT know where mushaf_complete.json, the Qur'an
/// text it contains, or the frame images actually came from — that was
/// never shared with me anywhere in this project, and I'm not going to
/// guess at a source or license for content I can't verify. The three
/// sections below marked TODO must be filled in with the real source,
/// license, and (where the license requires it) a note on whether the
/// text was used unmodified, before this screen ships. See the inline
/// comments at each TODO for specifically what's needed and why.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, secondaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Credits & Licenses',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            theme,
            title: 'Amiri Font',
            children: [
              _paragraph(
                theme,
                'The Arabic text throughout this app, including the '
                "Mushaf page view, is set in Amiri, designed by Dr. "
                "Khaled Hosny and the Amiri Project — a revival of the "
                "typeface used in the 1924 Amiriya Press edition of the "
                "Qur'an.",
              ),
              const SizedBox(height: 8),
              _paragraph(
                theme,
                'Licensed under the SIL Open Font License, version 1.1.',
              ),
              const SizedBox(height: 10),
              _linkRow(theme, 'amirifont.org', 'https://www.amirifont.org'),
              _linkRow(
                theme,
                'Full license text (OFL 1.1)',
                'https://openfontlicense.org/open-font-license-official-text/',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            theme,
            title: "Qur'an Text",
            isDark: isDark,
            needsAttention: true,
            children: [
              // TODO (before release): replace this whole block with the
              // actual source of the Qur'an text used in
              // mushaf_complete.json. What's needed:
              //  1. The publisher/source name (e.g. a specific mushaf
              //     printing, or a text provider such as Tanzil.net).
              //  2. Its license terms — many Qur'an text sources (Tanzil
              //     included) explicitly require the text to be used
              //     UNMODIFIED. This app inserts kashida (tatweel) for
              //     line-justification (see mushaf_text_page.dart) — if
              //     the source's license requires unmodified text, this
              //     needs to be resolved (get explicit permission, switch
              //     to a source that allows reflow, or switch to a
              //     pre-laid-out glyph font/image approach instead of
              //     programmatic justification) before relying on that
              //     source.
              //  3. A link to the source and its license text, matching
              //     the Amiri section's format above.
              _paragraph(
                theme,
                'TODO: add the source and license for the Qur\'an text '
                'used in this app before release.',
                isWarning: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            theme,
            title: 'Mushaf Page Layout Data',
            isDark: isDark,
            needsAttention: true,
            children: [
              // TODO (before release): the per-page/per-line word
              // segmentation in assets/data/mushaf_complete.json (surah
              // boundaries, ayah markers, line breaks) — note where this
              // dataset came from and its license/attribution terms, the
              // same way the Amiri section does above.
              _paragraph(
                theme,
                'TODO: add the source and license for the mushaf page '
                'layout data before release.',
                isWarning: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            theme,
            title: 'Mushaf Frame Images',
            isDark: isDark,
            needsAttention: true,
            children: [
              // TODO (before release): mushaf_frame_dark.png,
              // mushaf_frame_light.png, surah_name_frame_light.png,
              // surah_name_frame_dark.png — note their source (an asset
              // pack, a commissioned design, a stock-asset site, ...)
              // and license/attribution terms.
              _paragraph(
                theme,
                'TODO: add the source and license for the decorative '
                'frame images before release.',
                isWarning: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            theme,
            title: 'Open Source Software',
            children: [
              _paragraph(
                theme,
                'Saleti is built with Flutter and a number of open-source '
                'packages, each under its own license.',
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'Saleti',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryGreen,
                    side: const BorderSide(color: primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('View open-source licenses'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card(
    ThemeData theme, {
    required String title,
    required List<Widget> children,
    bool isDark = false,
    bool needsAttention = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: needsAttention
            ? Border.all(color: Colors.orange.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (needsAttention) ...[
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 18,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _paragraph(ThemeData theme, String text, {bool isWarning = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal,
        color: isWarning
            ? Colors.orange.shade800
            : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
      ),
    );
  }

  // NOTE: this app has no URL-launching package (e.g. url_launcher) as a
  // dependency, and I'm not adding one just for this screen — that's a
  // pubspec.yaml change plus (on Android 11+) a <queries> manifest entry
  // for the browser intent, which is more to take on than a credits
  // screen needs. The URL itself is shown as selectable text instead, so
  // it can be copied and opened manually.
  Widget _linkRow(ThemeData theme, String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.link_rounded, size: 14, color: primaryGreen),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SelectableText(
                  url,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
