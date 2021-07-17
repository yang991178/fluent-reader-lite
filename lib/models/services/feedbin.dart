import 'dart:convert';
import 'dart:math';

import 'package:fluent_reader_lite/models/service.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:fluent_reader_lite/utils/utils.dart';
import 'package:html/parser.dart';
import 'package:tuple/tuple.dart';
import 'package:http/http.dart' as http;

import '../item.dart';
import '../source.dart';

class FeedbinServiceHandler extends ServiceHandler {
  String endpoint;
  String username;
  String password;
  int fetchLimit;
  int _lastId;
  Tuple2<Set<String>, Set<String>> _lastSynced;

  FeedbinServiceHandler() {
    endpoint = Store.sp.getString(StoreKeys.ENDPOINT);
    username = Store.sp.getString(StoreKeys.USERNAME);
    password = Store.sp.getString(StoreKeys.PASSWORD);
    fetchLimit = Store.sp.getInt(StoreKeys.FETCH_LIMIT);
    _lastId = Store.sp.getInt(StoreKeys.LAST_ID) ?? 0;
  }

  FeedbinServiceHandler.fromValues(
      this.endpoint, this.username, this.password, this.fetchLimit) {
    _lastId = Store.sp.getInt(StoreKeys.LAST_ID) ?? 0;
  }

  void persist() {
    Store.sp.setInt(StoreKeys.SYNC_SERVICE, SyncService.Feedbin.index);
    Store.sp.setString(StoreKeys.ENDPOINT, endpoint);
    Store.sp.setString(StoreKeys.USERNAME, username);
    Store.sp.setString(StoreKeys.PASSWORD, password);
    Store.sp.setInt(StoreKeys.FETCH_LIMIT, fetchLimit);
    Store.sp.setInt(StoreKeys.LAST_ID, _lastId);
    Global.service = this;
  }

  @override
  void remove() {
    super.remove();
    Store.sp.remove(StoreKeys.ENDPOINT);
    Store.sp.remove(StoreKeys.USERNAME);
    Store.sp.remove(StoreKeys.PASSWORD);
    Store.sp.remove(StoreKeys.FETCH_LIMIT);
    Store.sp.remove(StoreKeys.LAST_ID);
    Global.service = null;
  }

  String _getApiKey() {
    final credentials = "$username:$password";
    final bytes = utf8.encode(credentials);
    return base64.encode(bytes);
  }

  Future<http.Response> _fetchAPI(String params) async {
    var uri = Uri.parse(endpoint + params);
    return await http.get(uri, headers: {
      "Authorization": "Basic ${_getApiKey()}",
    });
  }

  Future<void> _markItems(String type, String method, List<String> refs) async {
    final auth = "Basic ${_getApiKey()}";
    final promises = List<Future>.empty(growable: true);
    final client = http.Client();
    try {
      while (refs.length > 0) {
        final batch = List<int>.empty(growable: true);
        while (batch.length < 1000 && refs.length > 0) {
          batch.add(int.parse(refs.removeLast()));
        }
        final bodyObject = {
          "${type}_entries": batch,
        };
        final request = http.Request(
          method,
          Uri.parse(endpoint + type + "_entries.json"),
        );
        request.headers["Authorization"] = auth;
        request.headers["Content-Type"] = "application/json; charset=utf-8";
        request.body = jsonEncode(bodyObject);
        promises.add(client.send(request));
      }
      await Future.wait(promises);
    } finally {
      client.close();
    }
  }

  int get lastId => _lastId;
  set lastId(int value) {
    _lastId = value;
    Store.sp.setInt(StoreKeys.LAST_ID, value);
  }

  @override
  Future<bool> validate() async {
    try {
      final response = await _fetchAPI("authentication.json");
      return response.statusCode == 200;
    } catch (exp) {
      print(exp);
      return false;
    }
  }

  @override
  Future<Tuple2<List<RSSSource>, Map<String, List<String>>>>
      getSources() async {
    final response = await _fetchAPI("subscriptions.json");
    assert(response.statusCode == 200);
    final subscriptions = jsonDecode(response.body);
    final groupsMap = Map<String, List<String>>();
    final tagsResponse = await _fetchAPI("taggings.json");
    assert(tagsResponse.statusCode == 200);
    final tags = jsonDecode(tagsResponse.body);
    for (var tag in tags) {
      final name = tag["name"].trim();
      groupsMap.putIfAbsent(name, () => []);
      groupsMap[name].add(tag["feed_id"].toString());
    }
    final sources = subscriptions.map<RSSSource>((s) {
      return RSSSource(s["feed_id"].toString(), s["feed_url"], s["title"]);
    }).toList();
    return Tuple2(sources, groupsMap);
  }

  @override
  Future<List<RSSItem>> fetchItems() async {
    var page = 1;
    var minId = Utils.syncMaxId;
    var items = [];
    List lastFetched;
    do {
      try {
        final response = await _fetchAPI(
            "entries.json?mode=extended&per_page=125&page=$page");
        assert(response.statusCode == 200);
        lastFetched = jsonDecode(response.body);
        items.addAll(
            lastFetched.where((i) => i["id"] > lastId && i["id"] < minId));
        minId = lastFetched.fold(minId, (m, n) => min(m, n["id"]));
        page += 1;
      } catch (exp) {
        break;
      }
    } while (minId > lastId &&
        lastFetched != null &&
        lastFetched.length >= 125 &&
        items.length < fetchLimit);
    lastId = items.fold(lastId, (m, n) => max(m, n["id"]));
    final parsedItems = List<RSSItem>.empty(growable: true);
    final unread = _lastSynced.item1;
    final starred = _lastSynced.item2;
    for (var i in items) {
      if (i["content"] == null) continue;
      final dom = parse(i["content"]);
      final iid = i["id"].toString();
      final item = RSSItem(
        id: iid,
        source: i["feed_id"].toString(),
        title: i["title"],
        link: i["url"],
        date: DateTime.parse(i["published"]),
        content: i["content"],
        snippet: dom.documentElement.text.trim(),
        creator: i["author"],
        hasRead: !unread.contains(iid),
        starred: starred.contains(iid),
      );
      if (i["images"] != null && i["images"]["original_url"] != null) {
        item.thumb = i["images"]["original_url"];
      } else {
        var img = dom.querySelector("img");
        if (img != null && img.attributes["src"] != null) {
          var thumb = img.attributes["src"];
          if (thumb.startsWith("http")) {
            item.thumb = thumb;
          }
        }
      }
      parsedItems.add(item);
    }
    _lastSynced = null;
    return parsedItems;
  }

  @override
  Future<Tuple2<Set<String>, Set<String>>> syncItems() async {
    final responses = await Future.wait([
      _fetchAPI("unread_entries.json"),
      _fetchAPI("starred_entries.json"),
    ]);
    assert(responses[0].statusCode == 200);
    assert(responses[1].statusCode == 200);
    final unread = jsonDecode(responses[0].body);
    final starred = jsonDecode(responses[1].body);
    _lastSynced = Tuple2(
      Set.from(unread.map((i) => i.toString())),
      Set.from(starred.map((i) => i.toString())),
    );
    return _lastSynced;
  }

  @override
  Future<void> markAllRead(Set<String> sids, DateTime date, bool before) async {
    List<String> predicates = ["hasRead = 0"];
    if (sids.length > 0) {
      predicates
          .add("source IN (${List.filled(sids.length, "?").join(" , ")})");
    }
    if (date != null) {
      predicates
          .add("date ${before ? "<=" : ">="} ${date.millisecondsSinceEpoch}");
    }
    final rows = await Global.db.query(
      "items",
      columns: ["iid"],
      where: predicates.join(" AND "),
      whereArgs: sids.toList(),
    );
    final iids = rows.map((r) => r["iid"]);
    await _markItems("unread", "DELETE", List.from(iids));
  }

  @override
  Future<void> markRead(RSSItem item) async {
    await _markItems("unread", "DELETE", [item.id]);
  }

  @override
  Future<void> markUnread(RSSItem item) async {
    await _markItems("unread", "POST", [item.id]);
  }

  @override
  Future<void> star(RSSItem item) async {
    await _markItems("starred", "POST", [item.id]);
  }

  @override
  Future<void> unstar(RSSItem item) async {
    await _markItems("starred", "DELETE", [item.id]);
  }
}
