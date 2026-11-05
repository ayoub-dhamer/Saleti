import 'package:flutter/material.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            title: "Qur'an Text & Page Layout",
            children: [
              _paragraph(
                theme,
                "The Qur'an text (Uthmani script) and the Mushaf page and line "
                "layout used in this app were obtained from the Quran.com API, "
                "provided by the Quran Foundation.",
              ),
              const SizedBox(height: 8),
              _paragraph(
                theme,
                "The Qur'an text is displayed as provided by the source, apart "
                "from kashida (tatweel) characters added at display time to "
                "justify the lines.",
              ),
              const SizedBox(height: 10),
              _linkRow(theme, 'Quran.com', 'https://quran.com'),
              _linkRow(
                theme,
                'Quran Foundation API documentation',
                'https://api-docs.quran.foundation',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            theme,
            title: 'Mushaf Frame Images',
            children: [
              _paragraph(
                theme,
                'The decorative page frames and surah name banners in the Mushaf '
                'view were created with the help of AI image generation tools, '
                'and edited for use in this app.',
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
