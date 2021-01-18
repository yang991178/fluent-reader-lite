import 'dart:io';

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
  bool _inAppBrowser = Store.sp.getBool(StoreKeys.IN_APP_BROWSER) ?? Platform.isIOS;
  double _textScale = Store.sp.getDouble(StoreKeys.TEXT_SCALE);

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

  bool get inAppBrowser => _inAppBrowser;
  set inAppBrowser(bool value) {
    _inAppBrowser = value;
    Store.sp.setBool(StoreKeys.IN_APP_BROWSER, value);
  }

  double get textScale => _textScale;
  set textScale(double value) {
    if (_textScale != value) {
      _textScale = value;
      notifyListeners();
      if (value == null) {
        Store.sp.remove(StoreKeys.TEXT_SCALE);
      } else {
        Store.sp.setDouble(StoreKeys.TEXT_SCALE, value);
      }
    }
  }
}