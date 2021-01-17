import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/material.dart';

enum ThemeSetting {
  Default, Light, Dark
}

class GlobalModel with ChangeNotifier {
  ThemeSetting _theme = Store.getTheme();
  Locale _locale = Store.getLocale();
  int _keepItemsDays = Store.sp.getInt(StoreKeys.KEEP_ITEMS_DAYS) ?? 21;
  bool _syncOnStart = Store.sp.getBool(StoreKeys.SYNC_ON_START) ?? true;

  ThemeSetting get theme => _theme;
  set theme(ThemeSetting value) {
    if (value != _theme) {
      _theme = value;
      notifyListeners();
      Store.setTheme(value);
    }
  }
  Brightness getBrightness() {
    if (_theme == ThemeSetting.Default) return null;
    else return _theme == ThemeSetting.Light ? Brightness.light : Brightness.dark;
  }

  Locale get locale => _locale;
  set locale(Locale value) {
    if (value != _locale) {
      _locale = value;
      notifyListeners();
      Store.setLocale(value);
    }
  }

  int get keepItemsDays => _keepItemsDays;
  set keepItemsDays(int value) {
    _keepItemsDays = value;
    Store.sp.setInt(StoreKeys.KEEP_ITEMS_DAYS, value);
  }

  bool get syncOnStart => _syncOnStart;
  set syncOnStart(bool value) {
    _syncOnStart = value;
    Store.sp.setBool(StoreKeys.SYNC_ON_START, value);
  }
}