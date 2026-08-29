import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:saleti/utils/hold_to_delete_button.dart';

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

  // Fonts (no Google Fonts)
  static const String arabicFont = 'Amiri';

  // Gallery tracking
  PageController? _pageController;

  Map<int, double> _duaFontSizes = {}; // index → font size
  static const double _minFontSize = 14;
  static const double _maxFontSize = 34;
  static const double _fontStep = 2;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _loadDuaNotes();
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
    setState(() {
      _duaFontSizes[index] = ((_duaFontSizes[index] ?? 24) + _fontStep).clamp(
        _minFontSize,
        _maxFontSize,
      );
    });
    _saveFontSizes();
  }

  void _decreaseFont(int index) {
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

  // REMOVE the old `Widget _duaEditorDialog({...})` method entirely —
  // replaced by the standalone `_DuaEditorDialog` widget below.

  // ───────────── Storage Logic ─────────────

  Future<void> _saveDua(String dua) async {
    if (dua.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _duaList.insert(0, dua.trim());
      _duaFontSizes[0] = 24; // default size for new duʿāʾ
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Delete Du'a?",
          style: TextStyle(fontFamily: arabicFont),
        ),

        /// CONTENT
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

        /// ACTIONS
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(fontFamily: arabicFont),
            ),
          ),
          HoldToDeleteButton(onConfirmed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      setState(() => _duaList.removeAt(index));
      await prefs.setStringList('dua_notes', _duaList);
    }
  }

  // Open gallery at specific index
  void _openGalleryAt(int index) {
    if (_duaList.isEmpty) return;
    setState(() {
      _isGalleryMode = true;

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
            // exit gallery mode
          });
          return false; // prevent exiting the screen
        }
        return true; // allow normal back behavior
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Personal Du'as",
                style: TextStyle(
                  fontFamily: arabicFont,
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Heartfelt whispers",
                style: TextStyle(fontFamily: arabicFont, color: Colors.white70),
              ),
            ],
          ),
          Row(
            children: [
              // Gallery toggle button
              _headerButton(
                _isGalleryMode
                    ? Icons.list_rounded
                    : Icons.auto_stories_rounded,
                () {
                  if (_duaList.isEmpty) return;
                  setState(() {
                    if (_isGalleryMode) {
                      // Exit gallery
                      _isGalleryMode = false;
                    } else {
                      // Enter gallery at the last du'a
                      _isGalleryMode = true;
                      _pageController = PageController(
                        initialPage: _duaList.length - 1, // start at last du'a
                        viewportFraction: 0.9,
                      );
                    }
                  });
                },
              ),
              const SizedBox(width: 12),
              _headerButton(Icons.add, _showAddDialog),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
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
      padding: const EdgeInsets.all(16),
      itemCount: _duaList.length,
      itemBuilder: (_, i) => _duaCard(i),
    );
  }

  Widget _duaCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.12),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openGalleryAt(index),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _duaList[index],
                textDirection: TextDirection.rtl,
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
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "Tap to view full du'a",
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _cardActions(index), // buttons aligned to bottom-right
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardActions(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end, // push to the right
        children: [
          IconButton(
            icon: Icon(Icons.edit_note, color: primaryGreen.withOpacity(0.8)),
            onPressed: () => _showEditDialog(index),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _deleteDua(index),
          ),
        ],
      ),
    );
  }

  Widget _galleryView() {
    if (_pageController == null) return const SizedBox.shrink();

    return PageView.builder(
      controller: _pageController,
      itemCount: _duaList.length,
      itemBuilder: (_, i) {
        final fontSize = _duaFontSizes[i] ?? 24;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Stack(
            children: [
              // Card
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

              // Islamic Watermark
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
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        color: primaryGreen,
                        onPressed: () => _increaseFont(i),
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
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 100,
            color: primaryGreen.withOpacity(.12),
          ),
          const SizedBox(height: 24),
          const Text(
            "Your Du'a Journal is Empty",
            style: TextStyle(fontFamily: arabicFont, color: Colors.black54),
          ),
        ],
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
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
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

            // Text field
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
                  cursorColor: primaryGreen,
                  style: const TextStyle(
                    fontFamily: arabicFont,
                    fontSize: 18,
                    height: 1.8,
                  ),
                  decoration: const InputDecoration(
                    hintText: "Enter your prayer here...",
                    hintStyle: TextStyle(
                      color: Colors.black38,
                      fontFamily: arabicFont,
                    ),
                    contentPadding: EdgeInsets.all(16),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) =>
                      setState(() {}), // refresh char count + save button state
                ),
              ),
            ),

            // Character counter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_controller.text.trim().length} characters',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
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
                  const SizedBox(width: 12),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
