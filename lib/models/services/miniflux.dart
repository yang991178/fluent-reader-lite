import 'dart:convert';
import 'dart:math';

import 'package:fluent_reader_lite/models/item.dart';
import 'package:fluent_reader_lite/models/service.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:html/parser.dart';
import 'package:tuple/tuple.dart';
import 'package:http/http.dart' as http;
import 'package:fluent_reader_lite/models/source.dart';

class MinifluxServiceHandler extends ServiceHandler {
  static const _ENTRIES_OPERATIONS = "/v1/entries";
  static const _GET_FEEDS = "/v1/feeds";
  static const _AUTHENTICATE = "/v1/me";
  Map<String, dynamic> user;
  String endpoint;
  String username;
  String apiKey;
  int fetchLimit;
  int _lastFetched;
  String _lastId;

  MinifluxServiceHandler() {
    endpoint = Store.sp.getString(StoreKeys.ENDPOINT);
    username = Store.sp.getString(StoreKeys.USERNAME);
    String userPref = Store.sp.getString(StoreKeys.USER);
    if (userPref != null) user = jsonDecode(userPref) as Map<String, dynamic>;
    apiKey = Store.sp.getString(StoreKeys.API_KEY);
    fetchLimit = Store.sp.getInt(StoreKeys.FETCH_LIMIT);
    _lastFetched = Store.sp.getInt(StoreKeys.LAST_FETCHED);
    _lastId = Store.sp.getString(StoreKeys.LAST_ID);
  }

  MinifluxServiceHandler.fromValues(
      this.endpoint, this.username, this.apiKey, this.fetchLimit) {
    _lastFetched = Store.sp.getInt(StoreKeys.LAST_FETCHED);
    _lastId = Store.sp.getString(StoreKeys.LAST_ID);
  }

  void persist() {
    Store.sp.setInt(StoreKeys.SYNC_SERVICE, SyncService.Miniflux.index);
    Store.sp.setString(StoreKeys.ENDPOINT, endpoint);
    Store.sp.setString(StoreKeys.USERNAME, username);
    Store.sp.setString(StoreKeys.API_KEY, apiKey);
    Store.sp.setInt(StoreKeys.FETCH_LIMIT, fetchLimit);
    Global.service = this;
  }

  @override
  void remove() {
    super.remove();
    Store.sp.remove(StoreKeys.ENDPOINT);
    Store.sp.remove(StoreKeys.USERNAME);
    Store.sp.remove(StoreKeys.USER);
    Store.sp.remove(StoreKeys.API_KEY);
    Store.sp.remove(StoreKeys.FETCH_LIMIT);
    Store.sp.remove(StoreKeys.LAST_FETCHED);
    Store.sp.remove(StoreKeys.LAST_ID);
    Global.service = null;
  }

  int get lastFetched => _lastFetched;
  set lastFetched(int value) {
    _lastFetched = value;
    Store.sp.setInt(StoreKeys.LAST_FETCHED, value);
  }

  String get lastId => _lastId;
  set lastId(String value) {
    _lastId = value;
    Store.sp.setString(StoreKeys.LAST_ID, value);
  }

  Future<http.Response> _fetchAPI(String params, String method,
      {dynamic body}) async {
    final headers = Map<String, String>();
    headers["X-Auth-Token"] = apiKey;
    var uri = Uri.parse(endpoint + params);
    switch (method) {
      case "GET":
        return await http.get(uri, headers: headers);
        break;
      case "PUT":
        headers["Content-Type"] = "application/json";
        return await http.put(uri, headers: headers, body: jsonEncode(body));
        break;
      case "POST":
        headers["Content-Type"] = "application/json";
        return await http.post(uri, headers: headers, body: jsonEncode(body));
        break;
    }
  }

  @override
  Future<bool> validate() async {
    try {
      final result = await _fetchAPI(_AUTHENTICATE, "GET");
      if (Store.sp.getString('user') == null) {
        user = jsonDecode(result.body);
        Store.sp.setString('user', jsonEncode(user));
      }
      return result.statusCode == 200;
    } catch (exp) {
      return false;
    }
  }

  @override
  Future<Tuple2<List<RSSSource>, Map<String, List<String>>>>
      getSources() async {
    final response = await _fetchAPI(_GET_FEEDS, "GET");
    assert(response.statusCode == 200);
    List subscriptions = jsonDecode(response.body);
    final groupsMap = Map<String, List<String>>();
    for (var s in subscriptions) {
      final category = s["category"];
      if (category != null) {
        groupsMap.putIfAbsent(category["title"], () => []);
        groupsMap[category["title"]].add(s["id"].toString());
      }
    }
    final sources = subscriptions.map<RSSSource>((s) {
      return RSSSource(s["id"].toString(), s["feed_url"], s["title"]);
    }).toList();
    return Tuple2(sources, groupsMap);
  }

  Future<Set<String>> _fetchAll(String params) async {
    final results = List<String>.empty(growable: true);
    List fetched;
    var total;
    final limit = min(fetchLimit - results.length, 1000);
    int offset = 10;
    do {
      var p = params;
      p += "&offset=$offset";
      final response = await _fetchAPI(p, "GET");
      assert(response.statusCode == 200);
      final parsed = jsonDecode(response.body);
      total = parsed["total"];
      fetched = parsed["entries"];
      if (fetched != null && fetched.length > 0) {
        for (var i in fetched) {
          results.add(i["id"].toString());
        }
      }
      offset += limit;
    } while (
        offset + limit < total && fetched != null && fetched.length >= 1000);
    return new Set.from(results);
  }

  @override
  Future<List<RSSItem>> fetchItems() async {
    List items = [];
    List fetchedItems;
    final limit = min(fetchLimit - items.length, 1000);
    var total;
    int offset = 10;
    do {
      try {
        var params = _ENTRIES_OPERATIONS + "?limit=$limit&status=unread";
        params += "&offset=$offset";
        final response = await _fetchAPI(params, "GET");
        assert(response.statusCode == 200);
        final fetched = jsonDecode(response.body);
        total = fetched["total"];
        fetchedItems = fetched["entries"];
        for (var i in fetchedItems) {
          if (i["id"].toString() == lastId || items.length >= fetchLimit) {
            break;
          } else {
            items.add(i);
          }
        }
      } catch (exp) {
        break;
      }
      offset += limit;
    } while (offset + limit < total && items.length < fetchLimit);
    final parsedItems = items.map<RSSItem>((i) {
      final dom = parse(i["content"]);
      final item = RSSItem(
        id: i["id"].toString(),
        source: i["feed_id"].toString(),
        title: i["title"],
        link: i["url"],
        date: DateTime.parse(i["published_at"]),
        content: dom.body.innerHtml,
        snippet: dom.documentElement.text.trim(),
        creator: i["author"],
        hasRead: false,
        starred: false,
      );
      var img = dom.querySelector("img");
      if (img != null && img.attributes["src"] != null) {
        var thumb = img.attributes["src"];
        if (thumb.startsWith("http")) {
          item.thumb = thumb;
        }
      }
      return item;
    }).toList();
    return parsedItems;
  }

  @override
  Future<Tuple2<Set<String>, Set<String>>> syncItems() async {
    List<Set<String>> results;
    results = await Future.wait([
      _fetchAll(_ENTRIES_OPERATIONS + "?status=unread&limit=1000"),
      _fetchAll(_ENTRIES_OPERATIONS + "?starred=true&limit=1000"),
    ]);
    assert(results.length == 2);
    return Tuple2.fromList(results);
  }

  @override
  Future<void> markAllRead(Set<String> sids, DateTime date, bool before) async {
    if (date != null) {
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
      final iids = rows.map((r) => r["iid"]).iterator;
      List<String> refs = [];
      while (iids.moveNext()) {
        refs.add(iids.current);
        if (refs.length >= 1000) {
          _fetchAPI("/v1/users/${user['id']}/mark-all-as-read", "PUT");
          refs = [];
        }
      }
      if (refs.length > 0)
        _fetchAPI("/v1/users/${user['id']}/mark-all-as-read", "PUT");
      ;
      ;
    } else {
      if (sids.length == 0)
        sids = Set.from(Global.sourcesModel.getSources().map((s) => s.id));
      for (var sid in sids) {
        _fetchAPI("/v1/feeds/$sid/mark-all-as-read", "PUT");
      }
    }
  }

  @override
  Future<void> markRead(RSSItem item) async {
    final data = await _fetchAPI(_ENTRIES_OPERATIONS, "PUT", body: {
      "entry_ids": [int.parse(item.id)],
      "status": "read"
    });
    return data;
  }

  @override
  Future<void> markUnread(RSSItem item) async {
    await _fetchAPI(_ENTRIES_OPERATIONS, "PUT", body: {
      "entry_ids": [int.parse(item.id)],
      "status": "unread"
    });
  }

  @override
  Future<void> star(RSSItem item) async {
    await _fetchAPI(_ENTRIES_OPERATIONS + "/${item.id}/bookmark", "PUT");
  }

  @override
  Future<void> unstar(RSSItem item) async {
    await _fetchAPI(_ENTRIES_OPERATIONS + "/${item.id}/bookmark", "PUT");
  }
}
