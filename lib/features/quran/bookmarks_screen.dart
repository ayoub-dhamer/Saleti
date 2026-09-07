import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:saleti/widgets/icon_action.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mushaf_page_screen.dart';
import 'package:saleti/utils/hold_to_delete_button.dart';

/// 🔹 Bookmark model
class BookmarkItem {
  final int page;
  final String surah;
  final String date;

  BookmarkItem({required this.page, required this.surah, required this.date});
}

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<BookmarkItem> _bookmarks = [];

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    final parsed = <BookmarkItem>[];

    for (final item in list) {
      final parts = item.split('|');
      if (parts.length != 3) continue;

      final page = int.tryParse(parts[0]);
      if (page == null) continue;

      parsed.add(BookmarkItem(page: page, surah: parts[1], date: parts[2]));
    }

    parsed.sort((a, b) => a.page.compareTo(b.page));

    setState(() => _bookmarks = parsed);
  }

  Future<void> _deleteBookmark(BookmarkItem b) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('mushaf_bookmarks') ?? [];

    list.removeWhere((e) => e.startsWith('${b.page}|'));
    await prefs.setStringList('mushaf_bookmarks', list);

    _loadBookmarks();
  }

  Future<void> _confirmDelete(BookmarkItem b) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardColor, // ADD
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Bookmark?',
            style: TextStyle(color: theme.textTheme.bodyLarge?.color), // ADD
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Remove page ${b.page} from your bookmarks?',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ), // ADD
              ),
              const SizedBox(height: 8),
              const Text(
                "Hold to delete",
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],
          ),

          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            HoldToDeleteButton(onConfirmed: () => Navigator.pop(context, true)),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteBookmark(b);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme
          .scaffoldBackgroundColor, // CHANGED: was hardcoded Color(0xFFF4F6F8)
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
          'Bookmarks',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ), // ADD: explicit white on the green gradient
        ),
      ),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: _bookmarks.isEmpty
                ? _emptyState(theme)
                : _bookmarksList(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryGreen, secondaryGreen]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Saved Pages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _bookmarks.isEmpty
                ? 'Quick access to your favorite places in the Qur\'an'
                : '${_bookmarks.length} saved ${_bookmarks.length == 1 ? 'page' : 'pages'}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_outline_rounded,
                size: 64,
                color: primaryGreen.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No bookmarks yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ), // CHANGED
            ),
            const SizedBox(height: 8),
            Text(
              'Start reading and save pages for quick access later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                fontSize: 13,
              ), // CHANGED
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookmarksList(ThemeData theme, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final b = _bookmarks[index];

        return TweenAnimationBuilder<double>(
          key: ValueKey('bookmark_${b.page}'),
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 280 + (index.clamp(0, 6) * 40)),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 14),
              child: child,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MushafPageScreen(
                    startPage: b.page,
                    storageKey: 'last_jumped_page',
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor, // CHANGED: was hardcoded Colors.white
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      isDark ? 0.3 : 0.04,
                    ), // CHANGED
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryGreen.withOpacity(0.15),
                          secondaryGreen.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.bookmark_rounded,
                      color: primaryGreen,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.surah,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.textTheme.bodyLarge?.color, // CHANGED
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: primaryGreen.withOpacity(
                                  isDark ? 0.18 : 0.1,
                                ), // CHANGED
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'page ${b.page}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat.yMMMMd().format(
                                  DateTime.parse(b.date),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.6), // CHANGED
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconAction(
                    label: 'Delete bookmark for page ${b.page}',
                    onTap: () => _confirmDelete(b),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small reusable scale-on-tap wrapper.
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.9),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
