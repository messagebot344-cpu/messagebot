import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService._(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesService> create() async {
    return PreferencesService._(await SharedPreferences.getInstance());
  }

  ThemeMode get themeMode {
    switch (_prefs.getString('theme_mode')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString('theme_mode', mode.name);
  }

  double get fontSize => _prefs.getDouble('reader_font_size') ?? 18;
  Future<void> setFontSize(double value) async {
    await _prefs.setDouble('reader_font_size', value);
  }

  bool get historyEnabled => _prefs.getBool('history_enabled') ?? true;
  Future<void> setHistoryEnabled(bool value) async {
    await _prefs.setBool('history_enabled', value);
  }

  List<String> get history => _prefs.getStringList('search_history') ?? const [];

  Future<void> addHistory(String query) async {
    if (!historyEnabled) return;
    final q = query.trim();
    if (q.isEmpty) return;
    final list = history.where((e) => e != q).toList();
    list.insert(0, q);
    if (list.length > 20) list.removeRange(20, list.length);
    await _prefs.setStringList('search_history', list);
  }

  Future<void> clearHistory() async {
    await _prefs.remove('search_history');
  }

  Set<String> get favoriteCodes =>
      (_prefs.getStringList('favorite_codes') ?? const []).toSet();

  bool isFavorite(String code) => favoriteCodes.contains(code);

  Future<void> toggleFavorite(String code) async {
    final values = favoriteCodes;
    if (!values.add(code)) values.remove(code);
    final sorted = values.toList()..sort();
    await _prefs.setStringList('favorite_codes', sorted);
  }

  Map<String, int> get readingPositionsSnapshot {
    final result = <String, int>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith('reading_position_')) continue;
      final value = _prefs.getInt(key);
      if (value != null) {
        result[key.substring('reading_position_'.length)] = value;
      }
    }
    return result;
  }

  int readingPosition(String editionId) =>
      _prefs.getInt('reading_position_$editionId') ?? 0;

  Future<void> setReadingPosition(String editionId, int ordinal) async {
    await _prefs.setInt('reading_position_$editionId', ordinal);
  }
}

class AppController extends ChangeNotifier {
  AppController(this.preferences)
      : _themeMode = preferences.themeMode,
        _fontSize = preferences.fontSize,
        _historyEnabled = preferences.historyEnabled;

  final PreferencesService preferences;
  ThemeMode _themeMode;
  double _fontSize;
  bool _historyEnabled;

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  bool get historyEnabled => _historyEnabled;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await preferences.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    _fontSize = value;
    await preferences.setFontSize(value);
    notifyListeners();
  }

  Future<void> setHistoryEnabled(bool value) async {
    _historyEnabled = value;
    await preferences.setHistoryEnabled(value);
    notifyListeners();
  }
}
