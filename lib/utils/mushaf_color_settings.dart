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

  static const _kBannerLight = 'mushaf_banner_color_light';
  static const _kBannerDark = 'mushaf_banner_color_dark';
  static const _kLabelLight = 'mushaf_label_color_light';
  static const _kLabelDark = 'mushaf_label_color_dark';

  static const _kBasmalaLight = 'mushaf_basmala_color_light';
  static const _kBasmalaDark = 'mushaf_basmala_color_dark';

  Color? basmalaLight, basmalaDark;

  Color? basmalaFor(Brightness b) =>
      b == Brightness.dark ? basmalaDark : basmalaLight;

  Color? bannerLight, bannerDark, labelLight, labelDark;

  Color? bannerFor(Brightness b) =>
      b == Brightness.dark ? bannerDark : bannerLight;
  Color? labelFor(Brightness b) =>
      b == Brightness.dark ? labelDark : labelLight;

  static const _kPageFlip = 'mushaf_page_flip';

  /// Book-style page turn animation. On by default.
  bool pageFlip = true;

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
    pageFlip = p.getBool(_kPageFlip) ?? true;
    bannerLight = _read(p, _kBannerLight);
    bannerDark = _read(p, _kBannerDark);
    labelLight = _read(p, _kLabelLight);
    labelDark = _read(p, _kLabelDark);
    basmalaLight = _read(p, _kBasmalaLight);
    basmalaDark = _read(p, _kBasmalaDark);
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
    await p.setBool(_kPageFlip, pageFlip);
    await write(_kBannerLight, bannerLight);
    await write(_kBannerDark, bannerDark);
    await write(_kLabelLight, labelLight);
    await write(_kLabelDark, labelDark);
    await write(_kBasmalaLight, basmalaLight);
    await write(_kBasmalaDark, basmalaDark);
    notifyListeners();
  }
}
