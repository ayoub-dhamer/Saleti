import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-chosen Mushaf colors, stored separately for light and dark mode.
/// A null color means "use the built-in default".
class MushafColorSettings extends ChangeNotifier {
  static final MushafColorSettings _instance = MushafColorSettings._internal();
  factory MushafColorSettings() => _instance;
  MushafColorSettings._internal();

  static const _kTextLight = 'mushaf_text_color_light';
  static const _kTextDark = 'mushaf_text_color_dark';
  static const _kAyahLight = 'mushaf_ayah_color_light';
  static const _kAyahDark = 'mushaf_ayah_color_dark';

  static const _kWeight = 'mushaf_text_weight';

  /// 400 = normal, 700 = bold, 900 = w900 (the previous behavior).
  int textWeight = 700;

  FontWeight get fontWeight => switch (textWeight) {
    400 => FontWeight.normal,
    900 => FontWeight.w900,
    _ => FontWeight.bold,
  };

  Color? textLight, textDark, ayahLight, ayahDark;

  Color? textFor(Brightness b) => b == Brightness.dark ? textDark : textLight;
  Color? ayahFor(Brightness b) => b == Brightness.dark ? ayahDark : ayahLight;

  Color? _read(SharedPreferences p, String key) {
    final v = p.getInt(key);
    return v == null ? null : Color(v);
  }

  /// Call once at startup (before runApp, next to ReligiousSettings.load()).
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    textLight = _read(p, _kTextLight);
    textDark = _read(p, _kTextDark);
    ayahLight = _read(p, _kAyahLight);
    ayahDark = _read(p, _kAyahDark);
    textWeight = p.getInt(_kWeight) ?? 700;
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    Future<void> write(String key, Color? c) =>
        c == null ? p.remove(key) : p.setInt(key, c.toARGB32());
    await write(_kTextLight, textLight);
    await write(_kTextDark, textDark);
    await write(_kAyahLight, ayahLight);
    await write(_kAyahDark, ayahDark);
    await p.setInt(_kWeight, textWeight);
    notifyListeners();
  }
}
