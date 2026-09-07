import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saleti/utils/hold_to_delete_button.dart';
import 'package:saleti/widgets/icon_action.dart';
import 'package:saleti/widgets/tap_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class DuaNotesScreen extends StatefulWidget {
  const DuaNotesScreen({super.key});

  @override
  State<DuaNotesScreen> createState() => _DuaNotesScreenState();
}

class _DuaNotesScreenState extends State<DuaNotesScreen> {
  final TextEditingController _addController = TextEditingController();
  List<String> _duaList = [];
  bool _isGalleryMode = false;

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);
  static const String arabicFont = 'Amiri';

  PageController? _pageController;
  int _galleryIndex = 0;

  Map<int, double> _duaFontSizes = {};
  static const double _minFontSize = 14;
  static const double _maxFontSize = 34;
  static const double _fontStep = 2;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _loadDuaNotes();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pageController?.dispose();
    _addController.dispose();
    super.dispose();
  }

  Future<void> _loadDuaNotes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _duaList = prefs.getStringList('dua_notes') ?? [];

      final stored = prefs.getStringList('dua_font_sizes') ?? [];
      _duaFontSizes = {
        for (var i = 0; i < stored.length; i++)
          i: double.tryParse(stored[i]) ?? 24,
      };
    });
  }

  Future<void> _saveFontSizes() async {
    final prefs = await SharedPreferences.getInstance();
    final list = List.generate(
      _duaList.length,
      (i) => (_duaFontSizes[i] ?? 24).toString(),
    );
    await prefs.setStringList('dua_font_sizes', list);
  }

  void _increaseFont(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _duaFontSizes[index] = ((_duaFontSizes[index] ?? 24) + _fontStep).clamp(
        _minFontSize,
        _maxFontSize,
      );
    });
    _saveFontSizes();
  }

  void _decreaseFont(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _duaFontSizes[index] = ((_duaFontSizes[index] ?? 24) - _fontStep).clamp(
        _minFontSize,
        _maxFontSize,
      );
    });
    _saveFontSizes();
  }

  // ───────────── Dialogs ─────────────

  void _showAddDialog() {
    _addController.clear();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Add Dua',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Transform.scale(
          scale: 0.9 + (0.1 * curved.value.clamp(0.0, 1.0)),
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: _DuaEditorDialog(
              title: "New Du'a",
              initialText: '',
              onSave: (text) => _saveDua(text),
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(int index) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Dua',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Transform.scale(
          scale: 0.9 + (0.1 * curved.value.clamp(0.0, 1.0)),
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: _DuaEditorDialog(
              title: "Edit Du'a",
              initialText: _duaList[index],
              onSave: (text) => _updateDua(index, text),
            ),
          ),
        );
      },
    );
  }

  // ───────────── Storage Logic ─────────────

  Future<void> _saveDua(String dua) async {
    if (dua.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _duaList.insert(0, dua.trim());
      _duaFontSizes[0] = 24;
    });

    await prefs.setStringList('dua_notes', _duaList);
    await _saveFontSizes();
  }

  Future<void> _updateDua(int index, String dua) async {
    if (dua.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() => _duaList[index] = dua.trim());
    await prefs.setStringList('dua_notes', _duaList);
  }

  Future<void> _deleteDua(int index) async {
    final theme = Theme.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardColor, // CHANGED
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Delete Du'a?",
            style: TextStyle(
              fontFamily: arabicFont,
              color: theme.textTheme.bodyLarge?.color,
            ), // CHANGED
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Remove this prayer from your journal?",
                style: TextStyle(
                  fontFamily: arabicFont,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ), // CHANGED
              ),
              const SizedBox(height: 8),
              const Text(
                "Hold to delete",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.redAccent,
                  fontFamily: arabicFont,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Cancel",
                style: TextStyle(fontFamily: arabicFont),
              ),
            ),
            const SizedBox(width: 8),
            HoldToDeleteButton(onConfirmed: () => Navigator.pop(context, true)),
          ],
        );
      },
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      setState(() => _duaList.removeAt(index));
      await prefs.setStringList('dua_notes', _duaList);
    }
  }

  void _openGalleryAt(int index) {
    if (_duaList.isEmpty) return;
    setState(() {
      _isGalleryMode = true;
      _galleryIndex = index;
      _pageController = PageController(
        initialPage: index,
        viewportFraction: 0.9,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_isGalleryMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _isGalleryMode = false);
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor, // CHANGED
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "Du'a Journal",
            style: TextStyle(
              fontFamily: arabicFont,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          leading: _isGalleryMode
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _exitGalleryMode,
                )
              : null,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGreen, secondaryGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            if (_isGalleryMode)
              IconButton(
                icon: const Icon(Icons.list_rounded),
                onPressed: _exitGalleryMode,
              ),
          ],
        ),
        body: Column(
          children: [
            if (!_isGalleryMode) _header(),
            Expanded(
              child: _isGalleryMode
                  ? _galleryView(theme, isDark)
                  : _listView(theme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  void _exitGalleryMode() {
    setState(() {
      _isGalleryMode = false;
    });
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryGreen, secondaryGreen]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Personal Du'as",
                style: TextStyle(
                  fontFamily: arabicFont,
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _duaList.isEmpty
                    ? "Heartfelt whispers"
                    : "${_duaList.length} saved ${_duaList.length == 1 ? 'du\'a' : 'du\'as'}",
                style: const TextStyle(
                  fontFamily: arabicFont,
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconAction(
                label: _isGalleryMode
                    ? 'Switch to list view'
                    : 'Switch to gallery view',
                onTap: () {
                  if (_duaList.isEmpty) return;
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (_isGalleryMode) {
                      _isGalleryMode = false;
                    } else {
                      _isGalleryMode = true;
                      _galleryIndex = _duaList.length - 1;
                      _pageController = PageController(
                        initialPage: _duaList.length - 1,
                        viewportFraction: 0.9,
                      );
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Icon(
                    _isGalleryMode
                        ? Icons.list_rounded
                        : Icons.auto_stories_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconAction(
                label: "Add a new dua",
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showAddDialog();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _listView(ThemeData theme, bool isDark) {
    if (_duaList.isEmpty) return _emptyState(theme);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _duaList.length,
      itemBuilder: (_, i) => _duaCard(i, theme, isDark),
    );
  }

  Widget _duaCard(int index, ThemeData theme, bool isDark) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('dua_$index-${_duaList[index].hashCode}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index.clamp(0, 6) * 40)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.cardColor, // CHANGED
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(isDark ? 0.15 : 0.1),
                blurRadius: 18,
                spreadRadius: 1,
              ), // CHANGED
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ), // CHANGED
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openGalleryAt(index),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 1. "Tap to view" + Icon (Placed FIRST to render on the RIGHT in RTL mode)
                      Text(
                        "Tap to view",
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.6,
                          ),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 14,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.4,
                        ),
                      ),

                      const Spacer(),

                      // 2. Index Circle (Placed LAST to render on the LEFT in RTL mode)
                      // Index Circle (Placed LAST to render on the LEFT in RTL mode)
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        // ADD: same text-scale lock — this is a fixed 26x26 circle
                        child: MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(textScaler: const TextScaler.linear(1.0)),
                          child: Text(
                            '${index + 1}',
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _duaList[index],
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: arabicFont,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.7,
                      color: theme.textTheme.bodyLarge?.color, // CHANGED
                    ),
                  ),
                  Divider(
                    height: 20,
                    color: isDark ? Colors.white.withOpacity(0.08) : null,
                  ), // CHANGED
                  _cardActions(index, isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardActions(int index, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _smallActionButton(
          icon: Icons.edit_note,
          color: primaryGreen,
          label: 'Edit',
          onTap: () => _showEditDialog(index),
        ),
        const SizedBox(width: 8),
        _smallActionButton(
          icon: Icons.delete_outline,
          color: Colors.redAccent,
          label: 'Delete',
          onTap: () => _deleteDua(index),
        ),
      ],
    );
  }

  Widget _smallActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _galleryView(ThemeData theme, bool isDark) {
    if (_pageController == null) return const SizedBox.shrink();

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _duaList.length,
          onPageChanged: (i) => setState(() => _galleryIndex = i),
          itemBuilder: (_, i) {
            final fontSize = _duaFontSizes[i] ?? 24;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                    decoration: BoxDecoration(
                      color: theme.cardColor, // CHANGED
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: primaryGreen.withOpacity(isDark ? 0.15 : 0.08),
                      ), // CHANGED
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ), // CHANGED
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: AutoSizeText(
                                _duaList[i],
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                maxLines: null,
                                minFontSize: fontSize,
                                maxFontSize: fontSize,
                                overflow: TextOverflow.visible,
                                style: TextStyle(
                                  fontFamily: arabicFont,
                                  fontWeight: FontWeight.w700,
                                  height: 1.9,
                                  color: theme
                                      .textTheme
                                      .bodyLarge
                                      ?.color, // CHANGED
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Positioned(
                    top: -10,
                    right: -10,
                    child: Icon(
                      Icons.wb_sunny_outlined,
                      size: 100,
                      color: Colors.green.withOpacity(
                        isDark ? 0.08 : 0.05,
                      ), // CHANGED
                    ),
                  ),

                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isDark ? theme.cardColor : Colors.white)
                            .withOpacity(0.92), // CHANGED
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark ? 0.3 : 0.08,
                            ),
                            blurRadius: 12,
                          ), // CHANGED
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add),
                            color: primaryGreen,
                            tooltip: 'Increase text size',
                            onPressed: () => _increaseFont(i),
                          ),
                          Text(
                            '${fontSize.round()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(
                                    0.6,
                                  ), // also bumped per contrast fix
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconAction(
                            label: 'Decrease text size',
                            onTap: () => _decreaseFont(i),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.remove, color: primaryGreen),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_galleryIndex + 1} / ${_duaList.length}',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
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
                Icons.menu_book_outlined,
                size: 64,
                color: primaryGreen.withOpacity(.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Your Du'a Journal is Empty",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: arabicFont,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: theme.textTheme.bodyLarge?.color,
              ), // CHANGED
            ),
            const SizedBox(height: 8),
            Text(
              "Save the du'as closest to your heart and revisit them anytime.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: arabicFont,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                fontSize: 13,
              ), // CHANGED
            ),
          ],
        ),
      ),
    );
  }
}

class _DuaEditorDialog extends StatefulWidget {
  final String title;
  final String initialText;
  final ValueChanged<String> onSave;

  const _DuaEditorDialog({
    required this.title,
    required this.initialText,
    required this.onSave,
  });

  @override
  State<_DuaEditorDialog> createState() => _DuaEditorDialogState();
}

class _DuaEditorDialogState extends State<_DuaEditorDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);
  static const String arabicFont = 'Amiri';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _focusNode.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSave() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    widget.onSave(text);
    Navigator.pop(context);
  }

  void _handleCancel() {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: theme.cardColor, // CHANGED
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ), // CHANGED
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 20, 20, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGreen, secondaryGreen],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: arabicFont,
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconAction(
                      label: 'Close',
                      onTap: _handleCancel,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : const Color(0xFFF4F7F5), // CHANGED
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? primaryGreen.withOpacity(0.4)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 6,
                    minLines: 4,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    cursorColor: primaryGreen,
                    style: TextStyle(
                      fontFamily: arabicFont,
                      fontSize: 18,
                      height: 1.8,
                      color: theme.textTheme.bodyLarge?.color,
                    ), // CHANGED
                    decoration: InputDecoration(
                      hintText: "اكتب دعاءك هنا...",
                      hintStyle: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.35,
                        ),
                        fontFamily: arabicFont,
                      ), // CHANGED
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_controller.text.trim().length} characters',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.6,
                      ),
                    ), // CHANGED
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _controller.text.trim().isEmpty ? 0.5 : 1,
                        child: ElevatedButton(
                          onPressed: _controller.text.trim().isEmpty
                              ? null
                              : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            disabledBackgroundColor: isDark
                                ? Colors.white12
                                : Colors.grey.shade300, // CHANGED
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Save",
                            style: TextStyle(
                              fontFamily: arabicFont,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handleCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                          ), // CHANGED
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            fontFamily: arabicFont,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ), // CHANGED
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
