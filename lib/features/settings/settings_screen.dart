import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:saleti/utils/mushaf_color_settings.dart';
import 'package:saleti/utils/notification_service.dart';
import 'package:saleti/utils/prayer_cache.dart';
import 'package:saleti/utils/religious_settings.dart';
import 'credits_screen.dart';
import 'package:saleti/utils/theme_controller.dart';

/// FIXED (polish #2): calculation method, madhab, high-latitude rule, and
/// per-prayer minute adjustments were hard-coded before ReligiousSettings
/// existed. This is the UI for it — reached from a settings icon next to
/// the theme toggle on the Prayer tab's header.
///
/// Deliberately edits a LOCAL copy of the settings, not
/// ReligiousSettings' static fields directly, until Save is tapped —
/// mutating those live would affect prayer-time calculations used
/// elsewhere in the app (other tabs stay alive via IndexedStack) while
/// the user is still mid-edit and hasn't confirmed anything.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);
  static const int _maxAdjustmentMinutes = 30;
  static const int _maxHijriOffsetDays = 2;

  late CalculationMethod _method;
  late Madhab _madhab;
  late HighLatitudeRule _highLatitudeRule;
  late Map<String, int> _adjustments;
  late int _hijriOffset;
  bool _saving = false;

  late Color? _textLight, _textDark, _ayahLight, _ayahDark;

  late int _textWeight;

  FontWeight get _previewWeight => switch (_textWeight) {
    400 => FontWeight.normal,
    900 => FontWeight.w900,
    _ => FontWeight.bold,
  };

  final ThemeController _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    _method = ReligiousSettings.method;
    _madhab = ReligiousSettings.madhab;
    _highLatitudeRule = ReligiousSettings.highLatitudeRule;
    _adjustments = Map<String, int>.from(ReligiousSettings.adjustmentsMinutes);
    _hijriOffset = ReligiousSettings.hijriDayOffset;
    final mc = MushafColorSettings();
    _textLight = mc.textLight;
    _textDark = mc.textDark;
    _ayahLight = mc.ayahLight;
    _ayahDark = mc.ayahDark;
    _textWeight = mc.textWeight;
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    ReligiousSettings.method = _method;
    ReligiousSettings.madhab = _madhab;
    ReligiousSettings.highLatitudeRule = _highLatitudeRule;
    ReligiousSettings.adjustmentsMinutes
      ..clear()
      ..addAll(_adjustments);
    ReligiousSettings.hijriDayOffset = _hijriOffset;
    await ReligiousSettings.save();

    final mc = MushafColorSettings();
    mc.textLight = _textLight;
    mc.textDark = _textDark;
    mc.ayahLight = _ayahLight;
    mc.ayahDark = _ayahDark;
    mc.textWeight = _textWeight;
    await mc.save();

    // The calculation itself just changed, so every prayer and azan alarm
    // needs recomputing against it — not just today's reminder settings.
    if (PrayerCache().hasLocation) {
      await NotificationService.rescheduleAllForToday(
        PrayerCache().calculatePrayerTimes(),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
  }

  Widget _modeColors(
    ThemeData theme,
    bool isDark, {
    required String title,
    required Color bg,
    required Color defaultText,
    required Color? text,
    required Color? ayah,
    required ValueChanged<Color?> onText,
    required ValueChanged<Color?> onAyah,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        // Live preview on that mode's background
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ',
                    style: TextStyle(
                      fontFamily: 'amiri',
                      fontSize: 22,
                      fontWeight: _previewWeight, // was FontWeight.w900
                      color: text ?? defaultText,
                    ),
                  ),
                  TextSpan(
                    text: '\u06DD١',
                    style: TextStyle(
                      fontFamily: 'amiri',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ayah ?? Colors.lightBlue,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _colorTile(
          theme,
          isDark,
          label: 'Text color',
          current: text,
          fallback: defaultText,
          onChanged: onText,
        ),
        _colorTile(
          theme,
          isDark,
          label: 'Ayah number color',
          current: ayah,
          fallback: Colors.lightBlue,
          onChanged: onAyah,
        ),
      ],
    );
  }

  Widget _colorTile(
    ThemeData theme,
    bool isDark, {
    required String label,
    required Color? current,
    required Color fallback,
    required ValueChanged<Color?> onChanged,
  }) {
    final shown = current ?? fallback;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              current == null ? '$label (default)' : label,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            ),
          ),
          if (current != null)
            IconButton(
              tooltip: 'Reset to default',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.restart_alt_rounded,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                onChanged(null);
              },
            ),
          GestureDetector(
            onTap: () async {
              HapticFeedback.selectionClick();
              final picked = await _pickColor(shown);
              if (picked != null) onChanged(picked);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: shown,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Color?> _pickColor(Color initial) {
    Color temp = initial;
    final theme = Theme.of(context);
    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initial,
            onColorChanged: (c) => temp = c,
            enableAlpha: false,
            hexInputBar: true,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () => Navigator.pop(ctx, temp),
            child: const Text('Select', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _methodLabel(CalculationMethod m) {
    switch (m) {
      case CalculationMethod.muslim_world_league:
        return 'Muslim World League';
      case CalculationMethod.egyptian:
        return 'Egyptian General Authority of Survey';
      case CalculationMethod.karachi:
        return 'University of Islamic Sciences, Karachi';
      case CalculationMethod.umm_al_qura:
        return 'Umm al-Qura University, Makkah';
      case CalculationMethod.dubai:
        return 'Dubai (UAE)';
      case CalculationMethod.singapore:
        return 'Singapore / Malaysia / Indonesia';
      case CalculationMethod.tehran:
        return 'Institute of Geophysics, Tehran';
      case CalculationMethod.north_america:
        return 'ISNA (North America)';
      case CalculationMethod.other:
        return 'Other / Custom';
      default:
        return m.name
            .split('_')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');
    }
  }

  String _highLatLabel(HighLatitudeRule r) {
    switch (r) {
      case HighLatitudeRule.middle_of_the_night:
        return 'Middle of the night';
      case HighLatitudeRule.seventh_of_the_night:
        return 'Seventh of the night';
      case HighLatitudeRule.twilight_angle:
        return 'Twilight angle (recommended)';
      default:
        return r.name;
    }
  }

  String _prayerLabel(String key) {
    if (key == 'isha') return 'Isha';
    return key[0].toUpperCase() + key.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            theme,
            title: 'Prayer calculation',
            children: [
              Text(
                'Changes here affect every prayer time and azan alarm in the app.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _label(theme, 'Calculation method'),
              DropdownButtonFormField<CalculationMethod>(
                value: _method,
                isExpanded: true,
                decoration: _fieldDecoration(isDark),
                items: CalculationMethod.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          _methodLabel(m),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (m) {
                  if (m != null) setState(() => _method = m);
                },
              ),
              const SizedBox(height: 14),
              _label(theme, 'Madhab (affects Asr time)'),
              SegmentedButton<Madhab>(
                segments: const [
                  ButtonSegment(value: Madhab.shafi, label: Text('Shafi')),
                  ButtonSegment(value: Madhab.hanafi, label: Text('Hanafi')),
                ],
                selected: {_madhab},
                onSelectionChanged: (s) => setState(() => _madhab = s.first),
              ),
              const SizedBox(height: 14),
              _label(theme, 'High-latitude rule'),
              DropdownButtonFormField<HighLatitudeRule>(
                value: _highLatitudeRule,
                isExpanded: true,
                decoration: _fieldDecoration(isDark),
                items: HighLatitudeRule.values
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(
                          _highLatLabel(r),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (r) {
                  if (r != null) setState(() => _highLatitudeRule = r);
                },
              ),
              const SizedBox(height: 18),
              _label(
                theme,
                'Manual adjustments (minutes)',
                subtitle:
                    'Nudge individual prayers to match your local mosque, if needed.',
              ),
              const SizedBox(height: 4),
              for (final prayer in ReligiousSettings.adjustablePrayers)
                _adjustmentRow(theme, isDark, prayer),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(
            theme,
            title: 'Hijri calendar',
            children: [
              Text(
                "Hijri dates are calculated (Umm al-Qura), which can differ "
                "from your local mosque's moon-sighting announcement by a "
                "day. Adjust here if needed — this also affects Eid "
                "detection.",
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _stepperRow(
                theme,
                isDark,
                label: _hijriOffset == 0
                    ? 'No adjustment'
                    : '${_hijriOffset > 0 ? '+' : ''}$_hijriOffset day${_hijriOffset.abs() == 1 ? '' : 's'}',
                onDecrement: _hijriOffset > -_maxHijriOffsetDays
                    ? () => setState(() => _hijriOffset--)
                    : null,
                onIncrement: _hijriOffset < _maxHijriOffsetDays
                    ? () => setState(() => _hijriOffset++)
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 16),
          _sectionCard(
            theme,
            title: 'Mushaf text',
            children: [
              _label(theme, 'Text weight'),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 400, label: Text('Normal')),
                    ButtonSegment(value: 700, label: Text('Bold')),
                    ButtonSegment(value: 900, label: Text('W900')),
                  ],
                  selected: {_textWeight},
                  onSelectionChanged: (s) {
                    HapticFeedback.selectionClick();
                    setState(() => _textWeight = s.first);
                  },
                ),
              ),
              const SizedBox(height: 16),
              _modeColors(
                theme,
                isDark,
                title: 'Light mode',
                bg: const Color(0xFFFFFFFF),
                defaultText: Colors.black,
                text: _textLight,
                ayah: _ayahLight,
                onText: (c) => setState(() => _textLight = c),
                onAyah: (c) => setState(() => _ayahLight = c),
              ),
              const SizedBox(height: 18),
              _modeColors(
                theme,
                isDark,
                title: 'Dark mode',
                bg: const Color(0xFF121212),
                defaultText: Colors.white,
                text: _textDark,
                ayah: _ayahDark,
                onText: (c) => setState(() => _textDark = c),
                onAyah: (c) => setState(() => _ayahDark = c),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _sectionCard(
            theme,
            title: 'Appearance',
            children: [
              _label(theme, 'Theme'),
              ListenableBuilder(
                listenable: _themeController,
                builder: (context, _) => SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AppThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: AppThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded, size: 18),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded, size: 18),
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded, size: 18),
                        label: Text('Auto'),
                      ),
                    ],
                    selected: {_themeController.mode},
                    onSelectionChanged: (s) {
                      HapticFeedback.selectionClick();
                      _themeController.setMode(s.first);
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // ADDED (Store/legal #3): entry point for Amiri font / Qur'an
          // text / mushaf data / frame image attribution and the
          // open-source licenses page — see CreditsScreen.
          _sectionCard(
            theme,
            title: 'About',
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreditsScreen()),
                  ),
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('Credits & Licenses'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryGreen,
                    side: const BorderSide(color: primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionCard(
    ThemeData theme, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _label(ThemeData theme, String text, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.55,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(bool isDark) {
    return InputDecoration(
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF4F6F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _adjustmentRow(ThemeData theme, bool isDark, String prayer) {
    final minutes = _adjustments[prayer] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _prayerLabel(prayer),
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            ),
          ),
          _stepperRow(
            theme,
            isDark,
            label: '${minutes > 0 ? '+' : ''}$minutes min',
            onDecrement: minutes > -_maxAdjustmentMinutes
                ? () => setState(() => _adjustments[prayer] = minutes - 1)
                : null,
            onIncrement: minutes < _maxAdjustmentMinutes
                ? () => setState(() => _adjustments[prayer] = minutes + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _stepperRow(
    ThemeData theme,
    bool isDark, {
    required String label,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperButton(Icons.remove_rounded, onDecrement, isDark),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ),
        _stepperButton(Icons.add_rounded, onIncrement, isDark),
      ],
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback? onTap, bool isDark) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled
              ? primaryGreen.withValues(alpha: isDark ? 0.18 : 0.1)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? primaryGreen : Colors.grey,
        ),
      ),
    );
  }
}
