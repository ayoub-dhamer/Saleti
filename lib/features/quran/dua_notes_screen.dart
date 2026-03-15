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
  int _currentIndex = 0;

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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Delete Du'a?",
          style: TextStyle(fontFamily: arabicFont),
        ),
        content: const Text(
          "Remove this prayer from your journal?",
          style: TextStyle(fontFamily: arabicFont),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(fontFamily: arabicFont),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(fontFamily: arabicFont, color: Colors.redAccent),
            ),
          ),
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
      _currentIndex = index;
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
              _headerButton(Icons.auto_stories_rounded, () {}),
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
        border: Border.all(color: primaryGreen.withOpacity(.1)),
      ),
      child: Column(
        children: [
          Container(height: 4, color: primaryGreen),
          ListTile(
            contentPadding: const EdgeInsets.all(20),
            title: Text(
              _duaList[index],
              textDirection: TextDirection.rtl,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: arabicFont,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.7,
              ),
            ),
            onTap: () => _openGalleryAt(index),
          ),
          _cardActions(index),
        ],
      ),
    );
  }

  Widget _cardActions(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_note),
          onPressed: () => _showEditDialog(index),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _deleteDua(index),
        ),
      ],
    );
  }

  Widget _galleryView() {
    if (_pageController == null) return const SizedBox.shrink();
    return PageView.builder(
      controller: _pageController,
      itemCount: _duaList.length,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Text(
              _duaList[i],
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamily: arabicFont,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.9,
              ),
            ),
          ),
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
