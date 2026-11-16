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

// ───────────────────────── List screen ─────────────────────────

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> _reminders = [];
  bool _loaded = false;

  final Set<ReminderCategory> _categoryFilter = {};
  final Set<ReminderFrequency> _frequencyFilter = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ReminderService.load();
    if (!mounted) return;
    setState(() {
      _reminders = list;
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

    // Active reminders first by next fire time; disabled or passed last.
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

  Future<void> _openEditor([Reminder? existing]) async {
    final result = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderEditorScreen(existing: existing),
      ),
    );
    if (result == null || !mounted) return;

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

  Future<bool> _confirmDelete(Reminder r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete reminder?',
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '"${r.title}" will stop notifying you.',
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
    if (ok != true) return false;

    await ReminderService.cancel(r);
    if (!mounted) return true;
    setState(() => _reminders.removeWhere((x) => x.id == r.id));
    await ReminderService.save(_reminders);
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
          if (_reminders.isNotEmpty) _filters(theme, isDark),
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

  Widget _chipRow<T>({
    required List<T> values,
    required Set<T> selected,
    required String Function(T) label,
    required ThemeData theme,
    required bool isDark,
  }) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selected.isEmpty,
            showCheckmark: false,
            selectedColor: _primaryGreen,
            backgroundColor: theme.cardColor,
            side: BorderSide(
              color: selected.isEmpty
                  ? _primaryGreen
                  : _primaryGreen.withValues(alpha: isDark ? 0.25 : 0.15),
            ),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected.isEmpty
                  ? Colors.white
                  : theme.textTheme.bodyMedium?.color,
            ),
            onSelected: (_) {
              HapticFeedback.selectionClick();
              setState(selected.clear);
            },
          ),
          for (final v in values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(label(v)),
              selected: selected.contains(v),
              showCheckmark: false,
              selectedColor: _primaryGreen,
              backgroundColor: theme.cardColor,
              side: BorderSide(
                color: selected.contains(v)
                    ? _primaryGreen
                    : _primaryGreen.withValues(alpha: isDark ? 0.25 : 0.15),
              ),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected.contains(v)
                    ? Colors.white
                    : theme.textTheme.bodyMedium?.color,
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (!selected.remove(v)) selected.add(v);
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _filters(ThemeData theme, bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 6),
        _chipRow<ReminderCategory>(
          values: ReminderCategory.values,
          selected: _categoryFilter,
          label: (c) => c.label,
          theme: theme,
          isDark: isDark,
        ),
        _chipRow<ReminderFrequency>(
          values: ReminderFrequency.values,
          selected: _frequencyFilter,
          label: _freqLabel,
          theme: theme,
          isDark: isDark,
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
      confirmDismiss: (_) => _confirmDelete(r),
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
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
                  child: Icon(r.category.icon, color: _primaryGreen, size: 24),
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
                          _pill(r.category.label, isDark),
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
                Switch(
                  value: r.enabled && !r.isPassed,
                  activeThumbColor: _primaryGreen,
                  onChanged: r.isPassed ? null : (v) => _toggle(r, v),
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

// ───────────────────────── Editor screen ─────────────────────────

class ReminderEditorScreen extends StatefulWidget {
  final Reminder? existing;
  const ReminderEditorScreen({super.key, this.existing});

  @override
  State<ReminderEditorScreen> createState() => _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends State<ReminderEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late ReminderCategory _category;
  late ReminderFrequency _frequency;
  late DateTime _when;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _category = e?.category ?? ReminderCategory.extraPrayer;
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

    final dateText =
        '${_when.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_when.month - 1]} ${_when.year}';

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
          label('Category'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in ReminderCategory.values)
                ChoiceChip(
                  avatar: Icon(
                    c.icon,
                    size: 16,
                    color: _category == c ? Colors.white : _primaryGreen,
                  ),
                  label: Text(c.label),
                  selected: _category == c,
                  showCheckmark: false,
                  selectedColor: _primaryGreen,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: _category == c
                        ? Colors.white
                        : theme.textTheme.bodyMedium?.color,
                  ),
                  onSelected: (_) => setState(() => _category = c),
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
        ],
      ),
    );
  }
}
