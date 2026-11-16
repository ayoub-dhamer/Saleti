import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saleti/utils/hold_to_delete_button.dart';
import 'package:saleti/utils/reminder_service.dart';
import 'package:saleti/widgets/icon_action.dart';

const Color _primaryGreen = Color(0xFF1FA45B);
const Color _secondaryGreen = Color(0xFF4FC3A1);

String _freqLabel(ReminderFrequency f) => switch (f) {
  ReminderFrequency.once => 'Once',
  ReminderFrequency.daily => 'Daily',
  ReminderFrequency.weekly => 'Weekly',
  ReminderFrequency.monthly => 'Monthly',
};

/// Shared hold-to-confirm dialog. Returns true if the user confirmed.
Future<bool> _confirmHold(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
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
  return ok == true;
}

/// Asks for a category name; returns it, or null if cancelled.
Future<String?> _askCategoryName(BuildContext context, List<String> existing) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CategoryNameDialog(existing: existing),
  );
}

// ───────────────────────── List screen ─────────────────────────

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> _reminders = [];
  List<String> _categories = [];
  bool _loaded = false;

  final Set<String> _categoryFilter = {};
  final Set<ReminderFrequency> _frequencyFilter = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ReminderService.load();
    final cats = await ReminderService.loadCategories();
    if (!mounted) return;
    setState(() {
      _reminders = list;
      _categories = cats;
      _loaded = true;
    });
  }

  List<Reminder> get _visible {
    final list = _reminders.where((r) {
      final catOk =
          _categoryFilter.isEmpty || _categoryFilter.contains(r.category);
      final freqOk =
          _frequencyFilter.isEmpty || _frequencyFilter.contains(r.frequency);
      return catOk && freqOk;
    }).toList();

    list.sort((a, b) {
      final an = (a.enabled && !a.isPassed) ? a.nextOccurrence() : null;
      final bn = (b.enabled && !b.isPassed) ? b.nextOccurrence() : null;
      if (an != null && bn != null) return an.compareTo(bn);
      if (an != null) return -1;
      if (bn != null) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list;
  }

  // ── Categories ──

  /// Creates a category; returns its name, or null if cancelled.
  Future<String?> _addCategory() async {
    final name = await _askCategoryName(context, _categories);
    if (name == null || !mounted) return null;
    setState(() => _categories.add(name));
    await ReminderService.saveCategories(_categories);
    return name;
  }

  Future<void> _deleteCategory(String name) async {
    final ok = await _confirmHold(
      context,
      title: 'Delete "$name"?',
      message:
          'Your reminders in this category are kept, '
          'but will have no category.',
    );
    if (!ok || !mounted) return;
    setState(() {
      _categories.remove(name);
      _categoryFilter.remove(name);
      for (final r in _reminders) {
        if (r.category == name) r.category = null;
      }
    });
    await ReminderService.saveCategories(_categories);
    await ReminderService.save(_reminders);
  }

  // ── Reminders ──

  Future<void> _openEditor([Reminder? existing]) async {
    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderEditorScreen(
          existing: existing,
          categories: _categories,
          onCreateCategory: _addCategory,
        ),
      ),
    );
    if (!mounted) return;

    if (result == ReminderEditorScreen.deleted && existing != null) {
      await _removeReminder(existing);
      return;
    }
    if (result is! Reminder) return;

    final i = _reminders.indexWhere((r) => r.id == result.id);
    setState(() {
      if (i >= 0) {
        _reminders[i] = result;
      } else {
        _reminders.add(result);
      }
    });
    await ReminderService.save(_reminders);
    await ReminderService.schedule(result);
  }

  Future<void> _toggle(Reminder r, bool on) async {
    HapticFeedback.selectionClick();
    setState(() => r.enabled = on);
    await ReminderService.save(_reminders);
    await ReminderService.schedule(r);
  }

  Future<void> _removeReminder(Reminder r) async {
    // Remove and save first, so a failing alarm cancel can't block this.
    setState(() => _reminders.removeWhere((x) => x.id == r.id));
    await ReminderService.save(_reminders);
    await ReminderService.cancel(r);
  }

  /// Confirm, then delete. Returns true if deleted.
  Future<bool> _confirmAndDelete(Reminder r) async {
    final ok = await _confirmHold(
      context,
      title: 'Delete reminder?',
      message: '"${r.title}" will stop notifying you.',
    );
    if (!ok) return false;
    await _removeReminder(r);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final visible = _visible;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryGreen, _secondaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Reminders',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          _header(),
          if (_loaded) _filters(theme, isDark),
          Expanded(
            child: !_loaded
                ? const Center(
                    child: CircularProgressIndicator(color: _primaryGreen),
                  )
                : _reminders.isEmpty
                ? _emptyState(theme)
                : visible.isEmpty
                ? Center(
                    child: Text(
                      'No reminders match these filters',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: visible.length,
                    itemBuilder: (_, i) => _card(visible[i], theme, isDark),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final active = _reminders.where((r) => r.enabled && !r.isPassed).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_primaryGreen, _secondaryGreen]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Reminders',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _reminders.isEmpty
                    ? 'Never miss an extra prayer or dhikr'
                    : '$active active of ${_reminders.length}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          IconAction(
            label: 'Add a reminder',
            onTap: () {
              HapticFeedback.selectionClick();
              _openEditor();
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
    );
  }

  ChoiceChip _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: _primaryGreen,
      backgroundColor: theme.cardColor,
      side: BorderSide(
        color: selected
            ? _primaryGreen
            : _primaryGreen.withValues(alpha: isDark ? 0.25 : 0.15),
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : theme.textTheme.bodyMedium?.color,
      ),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }

  Widget _filters(ThemeData theme, bool isDark) {
    final gap = const SizedBox(width: 8);
    return Column(
      children: [
        const SizedBox(height: 6),
        // Categories: tap to filter, long-press a chip to delete it.
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _chip(
                label: 'All',
                selected: _categoryFilter.isEmpty,
                onTap: () => setState(_categoryFilter.clear),
                theme: theme,
                isDark: isDark,
              ),
              for (final c in _categories) ...[
                gap,
                GestureDetector(
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    _deleteCategory(c);
                  },
                  child: _chip(
                    label: c,
                    selected: _categoryFilter.contains(c),
                    onTap: () => setState(() {
                      if (!_categoryFilter.remove(c)) _categoryFilter.add(c);
                    }),
                    theme: theme,
                    isDark: isDark,
                  ),
                ),
              ],
              gap,
              ActionChip(
                avatar: const Icon(Icons.add, size: 18, color: _primaryGreen),
                label: const Text('New'),
                backgroundColor: theme.cardColor,
                side: BorderSide(color: _primaryGreen.withValues(alpha: 0.4)),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primaryGreen,
                ),
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  final created = await _addCategory();
                  if (created != null && mounted) {
                    setState(() => _categoryFilter.add(created));
                  }
                },
              ),
            ],
          ),
        ),
        if (_reminders.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _chip(
                  label: 'All',
                  selected: _frequencyFilter.isEmpty,
                  onTap: () => setState(_frequencyFilter.clear),
                  theme: theme,
                  isDark: isDark,
                ),
                for (final f in ReminderFrequency.values) ...[
                  gap,
                  _chip(
                    label: _freqLabel(f),
                    selected: _frequencyFilter.contains(f),
                    onTap: () => setState(() {
                      if (!_frequencyFilter.remove(f)) _frequencyFilter.add(f);
                    }),
                    theme: theme,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _card(Reminder r, ThemeData theme, bool isDark) {
    final next = (r.enabled && !r.isPassed) ? r.nextOccurrence() : null;
    final muted = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      // The dialog does the deletion itself, so the card must not also be
      // dismissed by the framework.
      confirmDismiss: (_) async {
        await _confirmAndDelete(r);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openEditor(r),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _primaryGreen.withValues(
                      alpha: isDark ? 0.18 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    reminderCategoryIcon(r.category),
                    color: _primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      if (r.body.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          r.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (r.category != null) _pill(r.category!, isDark),
                          _pill(r.summary, isDark),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.isPassed
                            ? 'Already passed'
                            : !r.enabled
                            ? 'Off'
                            : next == null
                            ? ''
                            : 'Next: ${Reminder.scheduleSummary(ReminderFrequency.once, next)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: r.isPassed ? Colors.orange : muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: r.enabled && !r.isPassed,
                      activeThumbColor: _primaryGreen,
                      onChanged: r.isPassed ? null : (v) => _toggle(r, v),
                    ),
                    IconButton(
                      tooltip: 'Delete reminder',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 22,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _confirmAndDelete(r),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _primaryGreen.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _primaryGreen,
        ),
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
                color: _primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: _primaryGreen.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No reminders yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to schedule a reminder for an extra prayer, a fast, or anything else.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Category name dialog ─────────────────────────

class _CategoryNameDialog extends StatefulWidget {
  final List<String> existing;
  const _CategoryNameDialog({required this.existing});

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  final _controller = TextEditingController();
  String? _error;

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
    if (widget.existing.any((c) => c.toLowerCase() == name.toLowerCase())) {
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
        'New category',
        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 24,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: _primaryGreen,
        decoration: InputDecoration(
          hintText: 'e.g. Tahajjud',
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
            'Add',
            style: TextStyle(color: _primaryGreen, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Editor screen ─────────────────────────

class ReminderEditorScreen extends StatefulWidget {
  /// Popped by the editor when the user deletes the reminder.
  static const Object deleted = 'deleted';

  final Reminder? existing;
  final List<String> categories;
  final Future<String?> Function() onCreateCategory;

  const ReminderEditorScreen({
    super.key,
    this.existing,
    required this.categories,
    required this.onCreateCategory,
  });

  @override
  State<ReminderEditorScreen> createState() => _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends State<ReminderEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late List<String> _cats;
  String? _category;
  late ReminderFrequency _frequency;
  late DateTime _when;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _cats = List<String>.of(widget.categories);
    _category = e?.category;
    _frequency = e?.frequency ?? ReminderFrequency.once;
    if (e != null) {
      _when = e.start;
    } else {
      final n = DateTime.now().add(const Duration(hours: 1));
      _when = DateTime(n.year, n.month, n.day, n.hour, 0);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = _when.isBefore(today) ? DateUtils.dateOnly(_when) : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: first,
      lastDate: today.add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    setState(() {
      _when = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _when.hour,
        _when.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (picked == null) return;
    setState(() {
      _when = DateTime(
        _when.year,
        _when.month,
        _when.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _newCategory() async {
    final created = await widget.onCreateCategory();
    if (created == null || !mounted) return;
    setState(() {
      _cats.add(created);
      _category = created;
    });
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await _confirmHold(
      context,
      title: 'Delete reminder?',
      message: '"${e.title}" will stop notifying you.',
    );
    if (ok && mounted) Navigator.pop(context, ReminderEditorScreen.deleted);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack('Enter a title');
      return;
    }
    if (!_when.isAfter(DateTime.now())) {
      _snack('Pick a date and time in the future');
      return;
    }

    setState(() => _saving = true);
    await ReminderService.requestPermission();
    final e = widget.existing;
    final reminder = Reminder(
      id: e?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      notifId: e?.notifId ?? await ReminderService.newNotifId(),
      title: title,
      body: _body.text.trim(),
      category: _category,
      frequency: _frequency,
      start: _when,
      enabled: true,
    );
    if (!mounted) return;
    Navigator.pop(context, reminder);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF4F7F5);

    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        t,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
    );

    Widget tile(IconData icon, String text, VoidCallback onTap) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: fieldFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: _primaryGreen),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateText = '${_when.day} ${months[_when.month - 1]} ${_when.year}';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryGreen, _secondaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          widget.existing == null ? 'New reminder' : 'Edit reminder',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Delete reminder',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          label('Title'),
          TextField(
            controller: _title,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: _primaryGreen,
            decoration: deco('e.g. Duha prayer').copyWith(counterText: ''),
          ),
          label('Description (optional)'),
          TextField(
            controller: _body,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: _primaryGreen,
            decoration: deco('What should the notification say?'),
          ),
          label('Category (optional)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _cats)
                ChoiceChip(
                  avatar: Icon(
                    reminderCategoryIcon(c),
                    size: 16,
                    color: _category == c ? Colors.white : _primaryGreen,
                  ),
                  label: Text(c),
                  selected: _category == c,
                  showCheckmark: false,
                  selectedColor: _primaryGreen,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: _category == c
                        ? Colors.white
                        : theme.textTheme.bodyMedium?.color,
                  ),
                  // Tap the selected chip again to clear it.
                  onSelected: (_) =>
                      setState(() => _category = _category == c ? null : c),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16, color: _primaryGreen),
                label: const Text('New'),
                labelStyle: const TextStyle(fontSize: 13, color: _primaryGreen),
                onPressed: _newCategory,
              ),
            ],
          ),
          label('Repeat'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ReminderFrequency>(
              showSelectedIcon: false,
              segments: [
                for (final f in ReminderFrequency.values)
                  ButtonSegment(value: f, label: Text(_freqLabel(f))),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) => setState(() => _frequency = s.first),
            ),
          ),
          label(
            _frequency == ReminderFrequency.once
                ? 'Date and time'
                : 'Starts on',
          ),
          Row(
            children: [
              tile(Icons.calendar_today_rounded, dateText, _pickDate),
              const SizedBox(width: 10),
              tile(
                Icons.access_time_rounded,
                TimeOfDay.fromDateTime(_when).format(context),
                _pickTime,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primaryGreen.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  size: 20,
                  color: _primaryGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    Reminder.scheduleSummary(_frequency, _when) +
                        (_frequency == ReminderFrequency.monthly &&
                                _when.day > 28
                            ? '\nMonths without a ${_when.day}th are skipped.'
                            : ''),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete reminder'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
