import 'dart:convert';

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

String _newDuaId([int salt = 0]) =>
    '${DateTime.now().microsecondsSinceEpoch}_$salt';

class _DuaNotesScreenState extends State<DuaNotesScreen> {
  List<_Dua> _duaList = [];
  bool _isGalleryMode = false;

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);
  static const String arabicFont = 'Amiri';

  PageController? _pageController;
  int _galleryIndex = 0;

  static const String _storageKeyV2 = 'dua_notes_v2';
  static const double _minFontSize = 14;
  static const double _maxFontSize = 34;
  static const double _fontStep = 2;

  static const String _categoriesKey = 'dua_categories_v1';
  List<String> _categories = [];

  final Set<String> _selectedCategories = {}; // empty = All

  List<_Dua> get _visible => _selectedCategories.isEmpty
      ? _duaList
      : _duaList
            .where((d) => d.categories.any(_selectedCategories.contains))
            .toList();

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
    super.dispose();
  }

  void _tapCounter(_Dua dua) {
    if (!dua.hasCounter) return;
    if (dua.isDone) {
      HapticFeedback.lightImpact();
      return;
    }
    setState(() => dua.count++);
    if (dua.isDone) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _resetCounter(_Dua dua) {
    HapticFeedback.mediumImpact();
    setState(() => dua.count = 0);
  }

  void _changeFont(_Dua dua, double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      dua.fontSize = (dua.fontSize + delta)
          .clamp(_minFontSize, _maxFontSize)
          .toDouble();
    });
    _persist();
  }

  Future<void> _loadDuaNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final v2 = prefs.getStringList(_storageKeyV2);
    final cats = prefs.getStringList(_categoriesKey) ?? [];

    List<_Dua> loaded;
    if (v2 != null) {
      loaded = v2.map(_Dua.tryFromJson).whereType<_Dua>().toList();
    } else {
      // One-time migration from the old parallel 'dua_notes' /
      // 'dua_font_sizes' lists. Sizes are paired by index, which is the
      // best information available — any pairing that had already drifted
      // out of sync under the old bug can't be recovered. The old keys are
      // left untouched as a backup.
      final oldNotes = prefs.getStringList('dua_notes') ?? [];
      final oldSizes = prefs.getStringList('dua_font_sizes') ?? [];
      loaded = [
        for (var i = 0; i < oldNotes.length; i++)
          _Dua(
            id: _newDuaId(i),
            text: oldNotes[i],
            fontSize: i < oldSizes.length
                ? (double.tryParse(oldSizes[i]) ?? 24)
                : 24,
          ),
      ];
      if (loaded.isNotEmpty) {
        await prefs.setStringList(
          _storageKeyV2,
          loaded.map((d) => jsonEncode(d.toJson())).toList(),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _duaList = loaded;
      _categories = cats;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKeyV2,
      _duaList.map((d) => jsonEncode(d.toJson())).toList(),
    );
  }

  Future<void> _persistCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_categoriesKey, _categories);
  }

  /// Returns the created name, or null if cancelled.
  Future<String?> _addCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _CategoryNameDialog(title: 'New category', existing: _categories),
    );
    if (name == null || !mounted) return null;
    setState(() => _categories.add(name));
    await _persistCategories();
    return name;
  }

  Future<void> _renameCategory(String old) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryNameDialog(
        title: 'Rename category',
        initialName: old,
        existing: _categories.where((c) => c != old).toList(),
      ),
    );
    if (name == null || name == old || !mounted) return;
    setState(() {
      _categories[_categories.indexOf(old)] = name;
      for (final d in _duaList) {
        final i = d.categories.indexOf(old);
        if (i >= 0) d.categories[i] = name;
      }
      if (_selectedCategories.remove(old)) _selectedCategories.add(name);
    });
    await _persistCategories();
    await _persist();
  }

  Future<void> _deleteCategory(String cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete "$cat"?',
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Your du'as in this category won't be deleted. "
                'They will just have no category.',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hold to delete',
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
    if (confirm != true || !mounted) return;
    setState(() {
      _categories.remove(cat);
      for (final d in _duaList) {
        d.categories.remove(cat);
      }
      _selectedCategories.remove(cat);
    });
    await _persistCategories();
    await _persist();
  }

  void _showCategoryOptions(String cat) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(sheetContext);
                _renameCategory(cat);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteCategory(cat);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ───────────── Dialogs ─────────────

  void _showEditor({_Dua? dua}) {
    final id = dua?.id;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: dua == null ? 'Add Dua' : 'Edit Dua',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => _DuaEditorDialog(
        title: dua == null ? "New Du'a" : "Edit Du'a",
        categories: _categories,
        onCreateCategory: _addCategory,
        initialText: dua?.text ?? '',
        initialCategories: dua != null
            ? List<String>.of(dua.categories)
            : _selectedCategories.toList(),
        initialTarget: dua?.target ?? 0,
        onSave: (text, cats, target) => id == null
            ? _saveDua(text, cats, target)
            : _updateDua(id, text, cats, target),
      ),
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  // ───────────── Storage Logic ─────────────

  Future<void> _saveDua(String text, List<String> cats, int target) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !mounted) return;
    setState(() {
      _duaList.insert(
        0,
        _Dua(
          id: _newDuaId(),
          text: trimmed,
          categories: List<String>.of(cats),
          target: target,
        ),
      );
    });
    await _persist();
  }

  Future<void> _updateDua(
    String id,
    String text,
    List<String> cats,
    int target,
  ) async {
    final trimmed = text.trim();
    final dua = _duaList.where((d) => d.id == id).firstOrNull;
    if (trimmed.isEmpty || dua == null || !mounted) return;
    setState(() {
      dua.text = trimmed;
      dua.categories = List<String>.of(cats);
      dua.target = target;
      dua.count = 0;
    });
    await _persist();
  }

  Widget _counterButton(_Dua dua, ThemeData theme, bool isDark) {
    final done = dua.isDone;
    final progress = dua.target == 0 ? 0.0 : dua.count / dua.target;

    return MediaQuery(
      // fixed-size circle: ignore system text scaling
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dua.count > 0) ...[
            IconAction(
              label: 'Reset counter',
              onTap: () => _resetCounter(dua),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? theme.cardColor : Colors.white).withValues(
                    alpha: 0.92,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.08,
                      ),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TapScale(
            onTap: () => _tapCounter(dua),
            child: SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor: primaryGreen.withValues(alpha: 0.18),
                      valueColor: AlwaysStoppedAnimation(
                        done ? Colors.amber : primaryGreen,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? Colors.amber.shade400 : primaryGreen,
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: done
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.black,
                            size: 34,
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${dua.count}',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '/ ${dua.target}',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDua(_Dua dua) async {
    final id = dua.id;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        // Read the theme here, from the dialog's own context, so it
        // rebuilds when the app theme changes while the dialog is open.
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Delete Du'a?",
            style: TextStyle(
              fontFamily: arabicFont,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Remove this prayer from your journal?",
                style: TextStyle(
                  fontFamily: arabicFont,
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
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
      if (!mounted) return;
      setState(() => _duaList.removeWhere((d) => d.id == id));
      await _persist();
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    // Reorder the currently visible du'as...
    final reordered = List<_Dua>.of(_visible);
    reordered.insert(newIndex, reordered.removeAt(oldIndex));

    // ...then put them back into the slots they occupied in the full list,
    // so du'as hidden by a category filter keep their positions.
    final ids = {for (final d in reordered) d.id};
    final slots = [
      for (var i = 0; i < _duaList.length; i++)
        if (ids.contains(_duaList[i].id)) i,
    ];
    setState(() {
      for (var k = 0; k < slots.length; k++) {
        _duaList[slots[k]] = reordered[k];
      }
    });
    _persist();
  }

  void _openGallery(int index) {
    if (_visible.isEmpty) return;
    setState(() {
      _isGalleryMode = true;
      _galleryIndex = index;
      _pageController?.dispose();
      _pageController = PageController(
        initialPage: index,
        viewportFraction: 0.9,
      );
    });
  }

  Widget _categoryBar(ThemeData theme, bool isDark) {
    // index 0 = All, 1..n = categories, last = "+ New"
    final count = _categories.length + 2;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == count - 1) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 18, color: primaryGreen),
              label: const Text('New'),
              backgroundColor: theme.cardColor,
              side: BorderSide(color: primaryGreen.withValues(alpha: 0.4)),
              labelStyle: const TextStyle(
                fontFamily: arabicFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primaryGreen,
              ),
              onPressed: () async {
                HapticFeedback.selectionClick();
                final created = await _addCategory();
                if (created != null && mounted) {
                  setState(() => _selectedCategories.add(created));
                }
              },
            );
          }

          final String? cat = i == 0 ? null : _categories[i - 1];
          final selected = cat == null
              ? _selectedCategories.isEmpty
              : _selectedCategories.contains(cat);
          final chip = ChoiceChip(
            label: Text(cat ?? 'All'),
            selected: selected,
            showCheckmark: false,
            selectedColor: primaryGreen,
            backgroundColor: theme.cardColor,
            side: BorderSide(
              color: selected
                  ? primaryGreen
                  : primaryGreen.withValues(alpha: isDark ? 0.25 : 0.15),
            ),
            labelStyle: TextStyle(
              fontFamily: arabicFont,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : theme.textTheme.bodyMedium?.color,
            ),
            onSelected: (_) {
              HapticFeedback.selectionClick();
              setState(() {
                if (cat == null) {
                  _selectedCategories.clear();
                } else if (!_selectedCategories.remove(cat)) {
                  _selectedCategories.add(cat);
                }
              });
            },
          );

          // "All" can't be renamed or deleted
          if (cat == null) return chip;
          return GestureDetector(
            onLongPress: () => _showCategoryOptions(cat),
            child: chip,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: !_isGalleryMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exitGalleryMode();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
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
            if (!_isGalleryMode &&
                (_duaList.isNotEmpty || _categories.isNotEmpty))
              _categoryBar(theme, isDark),
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
      for (final d in _duaList) {
        d.count = 0;
      }
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
                    : "${_duaList.length} saved ${_duaList.length == 1 ? "du'a" : "du'as"}",
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
                label: 'Open gallery view',
                onTap: () {
                  if (_visible.isEmpty) return;
                  HapticFeedback.selectionClick();
                  _openGallery(_visible.length - 1);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white30),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconAction(
                label: "Add a new dua",
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showEditor();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
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
    final visible = _visible;
    if (visible.isEmpty) {
      return Center(
        child: Text(
          "No du'as match these categories",
          style: TextStyle(
            fontFamily: arabicFont,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
          ),
        ),
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: visible.length,
      buildDefaultDragHandles: false, // no drag icons, long press only
      onReorderStart: (_) => HapticFeedback.mediumImpact(),
      onReorder: _reorder,
      proxyDecorator: (child, index, animation) =>
          Material(type: MaterialType.transparency, child: child),
      itemBuilder: (_, i) => ReorderableDelayedDragStartListener(
        key: ValueKey(visible[i].id),
        index: i,
        child: _duaCard(visible[i], i, theme, isDark),
      ),
    );
  }

  Widget _duaCard(_Dua dua, int index, ThemeData theme, bool isDark) {
    return TweenAnimationBuilder<double>(
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
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withValues(alpha: isDark ? 0.15 : 0.1),
                blurRadius: 18,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openGallery(index),
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
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.6,
                          ),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 14,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.4,
                        ),
                      ),

                      const Spacer(),

                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primaryGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
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
                    dua.text,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: arabicFont,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.7,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  Divider(
                    height: 20,
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : null,
                  ),
                  _cardActions(dua, isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const int _maxCardCategories = 2;

  Widget _cardActions(_Dua dua, bool isDark) {
    final cats = dua.categories;
    final shown = cats.take(_maxCardCategories).toList();
    final hidden = cats.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cats.isNotEmpty || dua.hasCounter) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (dua.hasCounter)
                _badge(
                  color: primaryGreen.withValues(alpha: isDark ? 0.22 : 0.14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.repeat_rounded,
                        size: 12,
                        color: primaryGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${dua.target}×',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final c in shown)
                _badge(
                  color: primaryGreen.withValues(alpha: isDark ? 0.18 : 0.1),
                  child: Text(
                    c,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                ),
              if (hidden > 0)
                GestureDetector(
                  onTap: () => _showDuaCategories(dua),
                  child: _badge(
                    color: primaryGreen.withValues(alpha: isDark ? 0.32 : 0.2),
                    child: Text(
                      '+$hidden',
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
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _smallActionButton(
              icon: Icons.edit_note,
              color: primaryGreen,
              label: 'Edit',
              onTap: () => _showEditor(dua: dua),
            ),
            const SizedBox(width: 8),
            _smallActionButton(
              icon: Icons.delete_outline,
              color: Colors.redAccent,
              label: 'Delete',
              onTap: () => _deleteDua(dua),
            ),
          ],
        ),
      ],
    );
  }

  Widget _badge({required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  void _showDuaCategories(_Dua dua) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in dua.categories)
                      _badge(
                        color: primaryGreen.withValues(alpha: 0.14),
                        child: Text(
                          c,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
          color: color.withValues(alpha: 0.08),
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
    final visible = _visible;
    if (_pageController == null || visible.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: visible.length,
          onPageChanged: (i) => setState(() => _galleryIndex = i),
          itemBuilder: (_, i) {
            final dua = visible[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: primaryGreen.withValues(
                          alpha: isDark ? 0.15 : 0.08,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.06,
                          ),
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
                              child: Text(
                                dua.text,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontFamily: arabicFont,
                                  fontSize: dua.fontSize,
                                  fontWeight: FontWeight.w700,
                                  height: 1.9,
                                  color: theme.textTheme.bodyLarge?.color,
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
                      color: Colors.green.withValues(
                        alpha: isDark ? 0.08 : 0.05,
                      ),
                    ),
                  ),
                  if (dua.hasCounter)
                    Positioned(
                      bottom: 24,
                      left: 24,
                      child: _counterButton(dua, theme, isDark),
                    ),
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isDark ? theme.cardColor : Colors.white)
                            .withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.08,
                            ),
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
                            tooltip: 'Increase text size',
                            onPressed: () => _changeFont(dua, _fontStep),
                          ),
                          Text(
                            '${dua.fontSize.round()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconAction(
                            label: 'Decrease text size',
                            onTap: () => _changeFont(dua, -_fontStep),
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
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_galleryIndex + 1} / ${visible.length}',
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
                color: primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 64,
                color: primaryGreen.withValues(alpha: .5),
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
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Save the du'as closest to your heart and revisit them anytime.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: arabicFont,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.5,
                ),
                fontSize: 13,
              ),
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
  final List<String> initialCategories;
  final int initialTarget;
  final List<String> categories;
  final Future<String?> Function() onCreateCategory;
  final void Function(String text, List<String> categories, int target) onSave;

  const _DuaEditorDialog({
    required this.title,
    required this.initialText,
    this.initialCategories = const [],
    this.initialTarget = 0,
    required this.categories,
    required this.onCreateCategory,
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

  late List<String> _selected;

  late List<String> _cats;

  late int _target;

  static const List<int> _presets = [10, 30, 50, 80, 100];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
    _selected = List<String>.of(widget.initialCategories);
    _cats = List.of(widget.categories);
    _target = widget.initialTarget;

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
    widget.onSave(text, _selected, _target);
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
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 20, 20, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryGreen, secondaryGreen],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
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
                            color: Colors.white.withValues(alpha: 0.15),
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

                // ── Text field ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF4F7F5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _focusNode.hasFocus
                            ? primaryGreen.withValues(alpha: 0.4)
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
                      ),
                      decoration: InputDecoration(
                        hintText: "Write your dua here",
                        hintStyle: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.35,
                          ),
                          fontFamily: arabicFont,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),

                // ── Category picker ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final c in _cats)
                          FilterChip(
                            label: Text(c),
                            selected: _selected.contains(c),
                            showCheckmark: false,
                            selectedColor: primaryGreen,
                            labelStyle: TextStyle(
                              fontFamily: arabicFont,
                              fontSize: 12,
                              color: _selected.contains(c)
                                  ? Colors.white
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                            onSelected: (on) => setState(() {
                              if (on) {
                                _selected.add(c);
                              } else {
                                _selected.remove(c);
                              }
                            }),
                          ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.add,
                            size: 16,
                            color: primaryGreen,
                          ),
                          label: const Text('New'),
                          labelStyle: const TextStyle(
                            fontFamily: arabicFont,
                            fontSize: 12,
                            color: primaryGreen,
                          ),
                          onPressed: () async {
                            final created = await widget.onCreateCategory();
                            if (created == null || !mounted) return;
                            setState(() {
                              _cats.add(created);
                              _selected.add(created);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Repeat counter ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.repeat_rounded,
                            size: 18,
                            color: primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Repeat counter',
                            style: TextStyle(
                              fontFamily: arabicFont,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: primaryGreen,
                            onPressed: _target > 0
                                ? () => setState(() => _target--)
                                : null,
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              _target == 0 ? 'Off' : '$_target×',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.add_circle_outline),
                            color: primaryGreen,
                            onPressed: _target < 9999
                                ? () => setState(() => _target++)
                                : null,
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final p in _presets)
                            ChoiceChip(
                              label: Text('$p'),
                              selected: _target == p,
                              showCheckmark: false,
                              selectedColor: primaryGreen,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: _target == p
                                    ? Colors.white
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                              onSelected: (on) =>
                                  setState(() => _target = on ? p : 0),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Character count ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_controller.text.trim().length} characters',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Buttons ──
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
                                  : Colors.grey.shade300,
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
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              fontFamily: arabicFont,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.7),
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
      ),
    );
  }
}

class _Dua {
  final String id;
  String text;
  double fontSize;
  List<String> categories;
  int target; // 0 = no counter
  int count;

  _Dua({
    required this.id,
    required this.text,
    this.fontSize = 24,
    List<String>? categories,
    this.target = 0,
    this.count = 0,
  }) : categories = categories ?? [];

  bool get hasCounter => target > 0;
  bool get isDone => hasCounter && count >= target;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'fontSize': fontSize,
    'categories': categories,
    'target': target,
  };

  static _Dua? tryFromJson(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;

      final cats = <String>[];
      final list = map['categories'];
      if (list is List) {
        cats.addAll(list.whereType<String>());
      } else if (map['category'] is String) {
        cats.add(map['category'] as String);
      }

      return _Dua(
        id: map['id'] as String,
        text: map['text'] as String,
        fontSize: (map['fontSize'] as num?)?.toDouble() ?? 24,
        categories: cats,
        target: (map['target'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class _CategoryNameDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final List<String> existing;

  const _CategoryNameDialog({
    required this.title,
    required this.existing,
    this.initialName = '',
  });

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _controller;
  String? _error;

  static const Color primaryGreen = Color(0xFF1FA45B);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    final taken = widget.existing.any(
      (c) => c.toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      setState(() => _error = 'That category already exists');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.title,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 24,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: primaryGreen,
        decoration: InputDecoration(
          hintText: 'e.g. After Fajr',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text(
            'Save',
            style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
