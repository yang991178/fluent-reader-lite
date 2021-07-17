import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:fluent_reader_lite/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import 'item.dart';

class SourcesModel with ChangeNotifier {
  Map<String, RSSSource> _sources = Map();
  Map<String, RSSSource> _deleted = Map();
  bool _showUnreadTip = Store.sp.getBool(StoreKeys.UNREAD_SOURCE_TIP) ?? true;

  bool get showUnreadTip => _showUnreadTip;
  set showUnreadTip(bool value) {
    if (_showUnreadTip != value) {
      _showUnreadTip = value;
      Store.sp.setBool(StoreKeys.UNREAD_SOURCE_TIP, value);
    }
  }

  bool has(String id) => _sources.containsKey(id);

  RSSSource getSource(String id) => _sources[id] ?? _deleted[id];

  Iterable<RSSSource> getSources() => _sources.values;

  Future<void> init() async {
    final maps = await Global.db.query("sources");
    for (var map in maps) {
      var source = RSSSource.fromMap(map);
      _sources[source.id] = source;
    }
    notifyListeners();
    await updateUnreadCounts();
  }

  Future<void> updateUnreadCounts() async {
    final rows = await Global.db.rawQuery(
        "SELECT source, COUNT(iid) FROM items WHERE hasRead=0 GROUP BY source;");
    for (var source in _sources.values) {
      var cloned = source.clone();
      _sources[source.id] = cloned;
      cloned.unreadCount = 0;
    }
    for (var row in rows) {
      _sources[row["source"]].unreadCount = row["COUNT(iid)"];
    }
    notifyListeners();
  }

  void updateUnreadCount(String sid, int diff) {
    _sources[sid].unreadCount += diff;
    notifyListeners();
  }

  Future<void> updateWithFetchedItems(Iterable<RSSItem> items) async {
    Set<String> changed = Set();
    for (var item in items) {
      var source = _sources[item.source];
      if (!item.hasRead) source.unreadCount += 1;
      if (item.date.compareTo(source.latest) > 0 ||
          source.lastTitle.length == 0) {
        source.latest = item.date;
        source.lastTitle = item.title;
        changed.add(source.id);
      }
    }
    notifyListeners();
    if (changed.length > 0) {
      var batch = Global.db.batch();
      for (var sid in changed) {
        var source = _sources[sid];
        batch.update(
          "sources",
          {
            "latest": source.latest.millisecondsSinceEpoch,
            "lastTitle": source.lastTitle,
          },
          where: "sid = ?",
          whereArgs: [source.id],
        );
      }
      await batch.commit();
    }
  }

  Future<void> put(RSSSource source, {force: false}) async {
    if (_deleted.containsKey(source.id) && !force) return;
    _sources[source.id] = source;
    notifyListeners();
    await Global.db.insert(
      "sources",
      source.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> putAll(Iterable<RSSSource> sources, {force: false}) async {
    Batch batch = Global.db.batch();
    for (var source in sources) {
      if (_deleted.containsKey(source.id) && !force) continue;
      _sources[source.id] = source;
      batch.insert(
        "sources",
        source.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    notifyListeners();
    await batch.commit(noResult: true);
  }

  Future<void> updateSources() async {
    final tuple = await Global.service.getSources();
    final sources = tuple.item1;
    var curr = Set<String>.from(_sources.keys);
    List<RSSSource> newSources = [];
    for (var source in sources) {
      if (curr.contains(source.id)) {
        curr.remove(source.id);
      } else {
        newSources.add(source);
      }
    }
    await putAll(newSources, force: true);
    await removeSources(curr);
    Global.groupsModel.groups = tuple.item2;
    fetchFavicons();
  }

  Future<void> removeSources(Iterable<String> ids) async {
    final batch = Global.db.batch();
    for (var id in ids) {
      if (!_sources.containsKey(id)) continue;
      var source = _sources[id];
      batch.delete(
        "items",
        where: "source = ?",
        whereArgs: [id],
      );
      batch.delete(
        "sources",
        where: "sid = ?",
        whereArgs: [id],
      );
      _sources.remove(id);
      _deleted[id] = source;
    }
    await batch.commit(noResult: true);
    Global.feedsModel.initAll();
    notifyListeners();
  }

  Future<void> fetchFavicons() async {
    for (var key in _sources.keys) {
      if (_sources[key].iconUrl == null) {
        _fetchFavicon(_sources[key].url).then((url) {
          if (!_sources.containsKey(key)) return;
          var source = _sources[key].clone();
          source.iconUrl = url == null ? "" : url;
          put(source);
        });
      }
    }
  }

  Future<String> _fetchFavicon(String url) async {
    try {
      url = url.split("/").getRange(0, 3).join("/");
      var uri = Uri.parse(url);
      var result = await http.get(uri);
      if (result.statusCode == 200) {
        var htmlStr = result.body;
        var dom = parse(htmlStr);
        var links = dom.getElementsByTagName("link");
        for (var link in links) {
          var rel = link.attributes["rel"];
          if ((rel == "icon" || rel == "shortcut icon") &&
              link.attributes.containsKey("href")) {
            var href = link.attributes["href"];
            var parsedUrl = Uri.parse(url);
            if (href.startsWith("//"))
              return parsedUrl.scheme + ":" + href;
            else if (href.startsWith("/"))
              return url + href;
            else
              return href;
          }
        }
      }
      url = url + "/favicon.ico";
      if (await Utils.validateFavicon(url)) {
        return url;
      } else {
        return null;
      }
    } catch (exp) {
      return null;
    }
  }
}
