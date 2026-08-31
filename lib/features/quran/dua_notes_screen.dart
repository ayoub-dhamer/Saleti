import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saleti/utils/hold_to_delete_button.dart';
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Delete Du'a?",
            style: TextStyle(fontFamily: arabicFont),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                "Remove this prayer from your journal?",
                style: TextStyle(fontFamily: arabicFont),
              ),
              SizedBox(height: 8),
              Text(
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
    return WillPopScope(
      onWillPop: () async {
        if (_isGalleryMode) {
          setState(() {
            _isGalleryMode = false;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F5),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "Du'a Journal",
            style: TextStyle(
              fontFamily: arabicFont,
              fontWeight: FontWeight.bold,
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
            Expanded(child: _isGalleryMode ? _galleryView() : _listView()),
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
              _headerButton(
                _isGalleryMode
                    ? Icons.list_rounded
                    : Icons.auto_stories_rounded,
                () {
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
              ),
              const SizedBox(width: 12),
              _headerButton(Icons.add, () {
                HapticFeedback.selectionClick();
                _showAddDialog();
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerButton(IconData icon, VoidCallback onTap) {
    return _TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _listView() {
    if (_duaList.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _duaList.length,
      itemBuilder: (_, i) => _duaCard(i),
    );
  }

  Widget _duaCard(int index) {
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.1),
                blurRadius: 18,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
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
                      Text(
                        "Tap to view",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                      const Spacer(),
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _duaList[index],
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: arabicFont,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.7,
                      color: Colors.black87,
                    ),
                  ),
                  const Divider(height: 20),
                  _cardActions(index),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardActions(int index) {
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
    return _TapScale(
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

  Widget _galleryView() {
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: primaryGreen.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
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
                                style: const TextStyle(
                                  fontFamily: arabicFont,
                                  fontWeight: FontWeight.w700,
                                  height: 1.9,
                                  color: Colors.black87,
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
                      color: Colors.green.withOpacity(0.05),
                    ),
                  ),

                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add),
                            color: primaryGreen,
                            onPressed: () => _increaseFont(i),
                          ),
                          Text(
                            '${fontSize.round()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            color: primaryGreen,
                            onPressed: () => _decreaseFont(i),
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

        // Page counter
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

  Widget _emptyState() {
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
            const Text(
              "Your Du'a Journal is Empty",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: arabicFont,
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Save the du'as closest to your heart and revisit them anytime.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: arabicFont,
                color: Colors.black45,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add your first du'a"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small reusable scale-on-tap wrapper for header/action buttons.
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
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
                    GestureDetector(
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
                    color: const Color(0xFFF4F7F5),
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
                    style: const TextStyle(
                      fontFamily: arabicFont,
                      fontSize: 18,
                      height: 1.8,
                    ),
                    decoration: const InputDecoration(
                      hintText: "Enter your prayer here",
                      hintStyle: TextStyle(
                        color: Colors.black38,
                        fontFamily: arabicFont,
                      ),
                      contentPadding: EdgeInsets.all(16),
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
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
                            disabledBackgroundColor: Colors.grey.shade300,
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
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            fontFamily: arabicFont,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
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
