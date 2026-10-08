import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:saleti/utils/notification_service.dart';
import 'package:saleti/utils/prayer_cache.dart';
import 'package:saleti/utils/religious_settings.dart';

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

  @override
  void initState() {
    super.initState();
    _method = ReligiousSettings.method;
    _madhab = ReligiousSettings.madhab;
    _highLatitudeRule = ReligiousSettings.highLatitudeRule;
    _adjustments = Map<String, int>.from(ReligiousSettings.adjustmentsMinutes);
    _hijriOffset = ReligiousSettings.hijriDayOffset;
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
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
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
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
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
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.55),
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
          ? Colors.white.withOpacity(0.06)
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
              ? primaryGreen.withOpacity(isDark ? 0.18 : 0.1)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
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
