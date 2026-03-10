import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDuaNotes();
  }

  Future<void> _loadDuaNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _duaList = prefs.getStringList('dua_notes') ?? [];
    });
  }

  // --- MISSING DIALOG LOGIC ---

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
    final editController = TextEditingController(text: _duaList[index]);
    showDialog(
      context: context,
      builder: (_) => _duaEditorDialog(
        title: "Edit Du'a",
        controller: editController,
        onSave: () => _updateDua(index, editController.text),
      ),
    );
  }

  Widget _duaEditorDialog({
    required String title,
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        title,
        style: GoogleFonts.philosopher(
          color: const Color(0xFF0F593E),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: TextField(
        controller: controller,
        maxLines: 6,
        autofocus: true,
        textDirection: TextDirection.rtl, // Keeps the input aligned for Arabic
        style: GoogleFonts.amiri(fontSize: 18),
        decoration: InputDecoration(
          hintText: "Enter your prayer here...",
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
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
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            onSave();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1FA45B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text(
            "Save to Journal",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  // --- REFINED SAVE/UPDATE LOGIC ---

  Future<void> _saveDua(String dua) async {
    if (dua.trim().isEmpty) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _duaList.insert(0, dua.trim());
    });
    await prefs.setStringList('dua_notes', _duaList);
  }

  Future<void> _updateDua(int index, String newDua) async {
    if (newDua.trim().isEmpty) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _duaList[index] = newDua.trim();
    });
    await prefs.setStringList('dua_notes', _duaList);
  }

  // Logic for saving, updating, deleting remains the same as your previous version...
  // (Assuming _saveDua, _updateDua, _deleteDua are implemented)

  void _toggleGalleryMode() {
    if (_duaList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add some du'as first to enter gallery!")),
      );
      return;
    }
    setState(() => _isGalleryMode = !_isGalleryMode);
  }

  Future<void> _deleteDua(int index) async {
    // Show a confirmation dialog before deleting
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Du'a?"),
        content: const Text(
          "Are you sure you want to remove this prayer from your journal?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _duaList.removeAt(index);
      });
      await prefs.setStringList('dua_notes', _duaList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Du'a deleted"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5), // Soft Islamic Mint/Grey
      appBar: AppBar(
        title: Text(
          "Du'a Journal",
          style: GoogleFonts.philosopher(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F593E), Color(0xFF1FA45B)],
            ),
          ),
        ),
        actions: [
          if (_isGalleryMode)
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: () => setState(() => _isGalleryMode = false),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isGalleryMode) _headerWithActions(),
          Expanded(
            child: _isGalleryMode ? _buildGalleryView() : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _headerWithActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F593E), Color(0xFF1FA45B)],
        ),
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
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Heartfelt whispers",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          Row(
            children: [
              _headerCircleButton(
                icon: Icons.auto_stories_rounded, // Gallery icon
                onTap: _toggleGalleryMode,
              ),
              const SizedBox(width: 12),
              _headerCircleButton(icon: Icons.add, onTap: _showAddDialog),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  // --- LIST VIEW ---
  Widget _buildListView() {
    return _duaList.isEmpty
        ? _buildEmptyState()
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _duaList.length,
            itemBuilder: (context, index) => _duaContentCard(index),
          );
  }

  // --- GALLERY VIEW (Swipe Mode) ---
  Widget _buildGalleryView() {
    return PageView.builder(
      itemCount: _duaList.length,
      controller: PageController(viewportFraction: 0.9),
      itemBuilder: (context, index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            image: const DecorationImage(
              image: AssetImage(
                'assets/images/pattern_subtle.png',
              ), // Add a light Islamic pattern here
              opacity: 0.03,
              repeat: ImageRepeat.repeat,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative Corner
              Positioned(
                top: -10,
                right: -10,
                child: Icon(
                  Icons.wb_sunny_outlined,
                  size: 100,
                  color: Colors.green.withOpacity(0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(30),
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      _duaList[index],
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.amiri(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.8,
                        color: const Color(0xFF2D3142),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Text(
                  "${index + 1} / ${_duaList.length}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _duaContentCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              height: 4,
              color: const Color(0xFF1FA45B),
            ), // Top Accent Bar
            ListTile(
              contentPadding: const EdgeInsets.all(20),
              title: Text(
                _duaList[index],
                textDirection: TextDirection.rtl,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.amiri(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  "Tap to view full du'a",
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
              onTap: () {
                // Open Gallery mode at specific index
                setState(() {
                  _isGalleryMode = true;
                });
              },
            ),
            _cardActionButtons(index),
          ],
        ),
      ),
    );
  }

  Widget _cardActionButtons(int index) {
    return Container(
      color: Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.blueGrey),
            onPressed: () => _showEditDialog(index),
          ),
          const VerticalDivider(width: 1),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.green),
            onPressed: () {},
          ),
          const VerticalDivider(width: 1),
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: Colors.redAccent,
            ),
            onPressed: () => _deleteDua(index),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40), // Moved padding here
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined, // Fixed the lowercase 'm' here too
              size: 100,
              color: const Color(0xFF0F593E).withOpacity(0.1),
            ),
            const SizedBox(height: 24),
            Text(
              "Your Du'a Journal is Empty",
              textAlign: TextAlign.center,
              style: GoogleFonts.philosopher(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F593E).withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "“And your Lord says, 'Call upon Me; I will respond to you.'” (40:60)",
              textAlign: TextAlign.center,
              style: GoogleFonts.amiri(
                fontSize: 16,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
