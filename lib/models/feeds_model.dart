import 'package:fluent_reader_lite/models/feed.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:fluent_reader_lite/utils/utils.dart';
import 'package:flutter/cupertino.dart';

import 'item.dart';

enum ItemSwipeOption {
  ToggleRead, ToggleStar, Share, OpenMenu, OpenExternal,
}

class FeedsModel with ChangeNotifier {
  RSSFeed all = RSSFeed();
  RSSFeed source;

  bool _showThumb = Store.sp.getBool(StoreKeys.SHOW_THUMB) ?? true;
  bool get showThumb => _showThumb;
  set showThumb(bool value) {
    _showThumb = value;
    Store.sp.setBool(StoreKeys.SHOW_THUMB, value);
    notifyListeners();
  }

  bool _showSnippet = Store.sp.getBool(StoreKeys.SHOW_SNIPPET) ?? true;
  bool get showSnippet => _showSnippet;
  set showSnippet(bool value) {
    _showSnippet = value;
    Store.sp.setBool(StoreKeys.SHOW_SNIPPET, value);
    notifyListeners();
  }

  bool _dimRead = Store.sp.getBool(StoreKeys.DIM_READ) ?? false;
  bool get dimRead => _dimRead;
  set dimRead(bool value) {
    _dimRead = value;
    Store.sp.setBool(StoreKeys.DIM_READ, value);
    notifyListeners();
  }

  ItemSwipeOption _swipeR = ItemSwipeOption.values[Store.sp.getInt(StoreKeys.FEED_SWIPE_R) ?? 0];
  ItemSwipeOption get swipeR => _swipeR;
  set swipeR(ItemSwipeOption value) {
    _swipeR = value;
    Store.sp.setInt(StoreKeys.FEED_SWIPE_R, value.index);
    notifyListeners();
  }

  ItemSwipeOption _swipeL = ItemSwipeOption.values[Store.sp.getInt(StoreKeys.FEED_SWIPE_L) ?? 1];
  ItemSwipeOption get swipeL => _swipeL;
  set swipeL(ItemSwipeOption value) {
    _swipeL = value;
    Store.sp.setInt(StoreKeys.FEED_SWIPE_L, value.index);
    notifyListeners();
  }

  void broadcast() { notifyListeners(); }

  Future<void> initSourcesFeed(Iterable<String> sids) async {
    Set<String> sidSet = Set.from(sids);
    source = RSSFeed(sids: sidSet);
    await source.init();
  }

  void addFetchedItems(Iterable<RSSItem> items) {
    for (var feed in [all, source]) {
      if (feed == null) continue;
      var lastDate = feed.iids.length > 0
        ? Global.itemsModel.getItem(feed.iids.last).date
        : null;
      for (var item in items) {
        if (!feed.testItem(item)) continue;
        if (lastDate != null && item.date.isBefore(lastDate)) continue;
        var idx = Utils.binarySearch(feed.iids, item.id, (a, b) {
          return Global.itemsModel.getItem(b).date.compareTo(Global.itemsModel.getItem(a).date);
        });
        feed.iids.insert(idx, item.id);
      }
    }
    notifyListeners();
  }

  void initAll() {
    for (var feed in [all, source]) {
      if (feed == null) continue;
      feed.init();
    }
  }
}