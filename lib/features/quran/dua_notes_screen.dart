import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDuaNotes();
  }

  Future<void> _loadDuaNotes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _duaList = prefs.getStringList('dua_notes') ?? [];
    });
  }

  // ───────────── Dialogs ─────────────

  void _showAddDialog() {
    _addController.clear();
    showDialog(
      context: context,
      builder: (_) => _duaEditorDialog(
        title: "New Du'a",
        controller: _addController,
        onSave: () => _saveDua(_addController.text),
      ),
    );
  }

  void _showEditDialog(int index) {
    final controller = TextEditingController(text: _duaList[index]);
    showDialog(
      context: context,
      builder: (_) => _duaEditorDialog(
        title: "Edit Du'a",
        controller: controller,
        onSave: () => _updateDua(index, controller.text),
      ),
    );
  }

  Widget _duaEditorDialog({
    required String title,
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: arabicFont,
          fontWeight: FontWeight.bold,
          color: primaryGreen,
        ),
      ),
      content: TextField(
        controller: controller,
        maxLines: 6,
        autofocus: true,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontFamily: arabicFont,
          fontSize: 18,
          height: 1.8,
        ),
        decoration: InputDecoration(
          hintText: "Enter your prayer here...",
          filled: true,
          fillColor: const Color(0xFFF4F7F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(fontFamily: arabicFont)),
        ),
        ElevatedButton(
          onPressed: () {
            onSave();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text("Save", style: TextStyle(fontFamily: arabicFont)),
        ),
      ],
    );
  }

  // ───────────── Storage Logic ─────────────

  Future<void> _saveDua(String dua) async {
    if (dua.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() => _duaList.insert(0, dua.trim()));
    await prefs.setStringList('dua_notes', _duaList);
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
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  size: 36,
                  color: Colors.red,
                ),
              ),

              const SizedBox(height: 16),

              /// Title
              const Text(
                "Delete Du'a?",
                style: TextStyle(
                  fontFamily: arabicFont,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              /// Message
              const Text(
                "Remove this prayer from your journal?",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: arabicFont, color: Colors.black54),
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

              const SizedBox(height: 24),

              /// Buttons (aligned right, closer together)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(fontFamily: arabicFont),
                    ),
                  ),
                  const SizedBox(width: 8), // smaller gap
                  HoldToDeleteButton(
                    onConfirmed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ],
          ),
        ),
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
            _isGalleryMode = false; // exit gallery mode
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
                  onPressed: () {
                    setState(() => _isGalleryMode = false);
                  },
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
                onPressed: () => setState(() => _isGalleryMode = false),
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

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openGalleryAt(index),
        child: Column(
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Text(
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
            ),
            _cardActions(index),
          ],
        ),
      ),
    );
  }

  Widget _cardActions(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
      itemBuilder: (_, i) => Padding(
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
                          maxLines: null, // 👈 IMPORTANT: unlimited lines
                          minFontSize: 14, // allow smaller for very long duʿāʾ
                          maxFontSize: 28,
                          stepGranularity: 1,
                          overflow: TextOverflow.visible,
                          softWrap: true,
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
          ],
        ),
      ),
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

class HoldToDeleteButton extends StatefulWidget {
  final VoidCallback onConfirmed;

  const HoldToDeleteButton({super.key, required this.onConfirmed});

  @override
  State<HoldToDeleteButton> createState() => _HoldToDeleteButtonState();
}

class _HoldToDeleteButtonState extends State<HoldToDeleteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              widget.onConfirmed();
              _reset();
            }
          });
  }

  void _reset() {
    _controller.reset();
    setState(() => _isHolding = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startHold() {
    setState(() => _isHolding = true);
    _controller.forward();
  }

  void _cancelHold() {
    _controller.reset();
    setState(() => _isHolding = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startHold(),
      onLongPressEnd: (_) => _cancelHold(),
      child: SizedBox(
        width: 100,
        height: 50,
        child: Center(
          child: _isHolding
              ? AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => CircularProgressIndicator(
                    value: _controller.value,
                    strokeWidth: 3,
                    color: Colors.redAccent,
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                  ),
                )
              : const Text(
                  "Delete",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}
