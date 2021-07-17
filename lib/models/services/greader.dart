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

class GReaderServiceHandler extends ServiceHandler {
  static const _ALL_TAG = "user/-/state/com.google/reading-list";
  static const _READ_TAG = "user/-/state/com.google/read";
  static const _STAR_TAG = "user/-/state/com.google/starred";

  String endpoint;
  String username;
  String password;
  int fetchLimit;
  int _lastFetched;
  String _lastId;
  String _auth;
  bool useInt64;
  String inoreaderId;
  String inoreaderKey;
  bool removeInoreaderAd;

  GReaderServiceHandler() {
    endpoint = Store.sp.getString(StoreKeys.ENDPOINT);
    username = Store.sp.getString(StoreKeys.USERNAME);
    password = Store.sp.getString(StoreKeys.PASSWORD);
    fetchLimit = Store.sp.getInt(StoreKeys.FETCH_LIMIT);
    _lastFetched = Store.sp.getInt(StoreKeys.LAST_FETCHED);
    _lastId = Store.sp.getString(StoreKeys.LAST_ID);
    _auth = Store.sp.getString(StoreKeys.AUTH);
    useInt64 = Store.sp.getBool(StoreKeys.USE_INT_64);
    inoreaderId = Store.sp.getString(StoreKeys.API_ID);
    inoreaderKey = Store.sp.getString(StoreKeys.API_KEY);
    removeInoreaderAd = Store.sp.getBool(StoreKeys.INOREADER_REMOVE_AD);
  }

  GReaderServiceHandler.fromValues(
    this.endpoint,
    this.username,
    this.password,
    this.fetchLimit, {
    this.inoreaderId,
    this.inoreaderKey,
    this.removeInoreaderAd,
  }) {
    _lastFetched = Store.sp.getInt(StoreKeys.LAST_FETCHED);
    _lastId = Store.sp.getString(StoreKeys.LAST_ID);
    _auth = Store.sp.getString(StoreKeys.AUTH);
    useInt64 = Store.sp.getBool(StoreKeys.USE_INT_64) ??
        !endpoint.endsWith("theoldreader.com");
  }

  void persist() {
    Store.sp.setInt(
        StoreKeys.SYNC_SERVICE,
        inoreaderId != null
            ? SyncService.Inoreader.index
            : SyncService.GReader.index);
    Store.sp.setString(StoreKeys.ENDPOINT, endpoint);
    Store.sp.setString(StoreKeys.USERNAME, username);
    Store.sp.setString(StoreKeys.PASSWORD, password);
    Store.sp.setInt(StoreKeys.FETCH_LIMIT, fetchLimit);
    Store.sp.setBool(StoreKeys.USE_INT_64, useInt64);
    if (inoreaderId != null) {
      Store.sp.setString(StoreKeys.API_ID, inoreaderId);
      Store.sp.setString(StoreKeys.API_KEY, inoreaderKey);
      Store.sp.setBool(StoreKeys.INOREADER_REMOVE_AD, removeInoreaderAd);
    }
    Global.service = this;
  }

  @override
  void remove() {
    super.remove();
    Store.sp.remove(StoreKeys.ENDPOINT);
    Store.sp.remove(StoreKeys.USERNAME);
    Store.sp.remove(StoreKeys.PASSWORD);
    Store.sp.remove(StoreKeys.FETCH_LIMIT);
    Store.sp.remove(StoreKeys.LAST_FETCHED);
    Store.sp.remove(StoreKeys.LAST_ID);
    Store.sp.remove(StoreKeys.AUTH);
    Store.sp.remove(StoreKeys.USE_INT_64);
    Store.sp.remove(StoreKeys.API_ID);
    Store.sp.remove(StoreKeys.API_KEY);
    Store.sp.remove(StoreKeys.INOREADER_REMOVE_AD);
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

  String get auth => _auth;
  set auth(String value) {
    _auth = value;
    Store.sp.setString(StoreKeys.AUTH, value);
  }

  Future<http.Response> _fetchAPI(String params, {dynamic body}) async {
    final headers = Map<String, String>();
    if (auth != null) headers["Authorization"] = auth;
    if (inoreaderId != null) {
      headers["AppId"] = inoreaderId;
      headers["AppKey"] = inoreaderKey;
    }
    var uri = Uri.parse(endpoint + params);
    if (body == null) {
      return await http.get(uri, headers: headers);
    } else {
      headers["Content-Type"] = "application/x-www-form-urlencoded";
      return await http.post(uri, headers: headers, body: body);
    }
  }

  Future<Set<String>> _fetchAll(String params) async {
    final results = List<String>.empty(growable: true);
    List fetched;
    String continuation;
    do {
      var p = params;
      if (continuation != null) p += "&c=$continuation";
      final response = await _fetchAPI(p);
      assert(response.statusCode == 200);
      final parsed = jsonDecode(response.body);
      fetched = parsed["itemRefs"];
      if (fetched != null && fetched.length > 0) {
        for (var i in fetched) {
          results.add(i["id"]);
        }
      }
      continuation = parsed["continuation"];
    } while (continuation != null && fetched != null && fetched.length >= 1000);
    return new Set.from(results);
  }

  Future<http.Response> _editTag(String ref, String tag, {add: true}) async {
    final body = "i=$ref&${add ? "a" : "r"}=$tag";
    return await _fetchAPI("/reader/api/0/edit-tag", body: body);
  }

  String _compactId(String longId) {
    final last = longId.split("/").last;
    if (!useInt64) return last;
    return int.parse(last, radix: 16).toString();
  }

  @override
  Future<bool> validate() async {
    try {
      final result = await _fetchAPI("/reader/api/0/user-info");
      return result.statusCode == 200;
    } catch (exp) {
      return false;
    }
  }

  static final _authRegex = RegExp(r"Auth=(\S+)");
  @override
  Future<void> reauthenticate() async {
    if (!await validate()) {
      final body = {
        "Email": username,
        "Passwd": password,
      };
      final result = await _fetchAPI("/accounts/ClientLogin", body: body);
      assert(result.statusCode == 200);
      final match = _authRegex.firstMatch(result.body);
      if (match != null && match.groupCount > 0) {
        auth = "GoogleLogin auth=${match.group(1)}";
      }
    }
  }

  @override
  Future<Tuple2<List<RSSSource>, Map<String, List<String>>>>
      getSources() async {
    final response =
        await _fetchAPI("/reader/api/0/subscription/list?output=json");
    assert(response.statusCode == 200);
    List subscriptions = jsonDecode(response.body)["subscriptions"];
    final groupsMap = Map<String, List<String>>();
    for (var s in subscriptions) {
      final categories = s["categories"];
      if (categories != null) {
        for (var c in categories) {
          groupsMap.putIfAbsent(c["label"], () => []);
          groupsMap[c["label"]].add(s["id"]);
        }
      }
    }
    final sources = subscriptions.map<RSSSource>((s) {
      return RSSSource(s["id"], s["url"] ?? s["htmlUrl"], s["title"]);
    }).toList();
    return Tuple2(sources, groupsMap);
  }

  @override
  Future<List<RSSItem>> fetchItems() async {
    List items = [];
    List fetchedItems;
    String continuation;
    do {
      try {
        final limit = min(fetchLimit - items.length, 1000);
        var params = "/reader/api/0/stream/contents?output=json&n=$limit";
        if (lastFetched != null) params += "&ot=$lastFetched";
        if (continuation != null) params += "&c=$continuation";
        final response = await _fetchAPI(params);
        assert(response.statusCode == 200);
        final fetched = jsonDecode(response.body);
        fetchedItems = fetched["items"];
        for (var i in fetchedItems) {
          i["id"] = _compactId(i["id"]);
          if (i["id"] == lastId || items.length >= fetchLimit) {
            break;
          } else {
            items.add(i);
          }
        }
        continuation = fetched["continuation"];
      } catch (exp) {
        break;
      }
    } while (continuation != null && items.length < fetchLimit);
    if (items.length > 0) {
      lastId = items[0]["id"];
      lastFetched = int.parse(items[0]["crawlTimeMsec"]) ~/ 1000;
    }
    final parsedItems = items.map<RSSItem>((i) {
      final dom = parse(i["summary"]["content"]);
      if (removeInoreaderAd == true) {
        if (dom.documentElement.text.trim().startsWith("Ads from Inoreader")) {
          dom.body.firstChild.remove();
        }
      }
      final item = RSSItem(
        id: i["id"],
        source: i["origin"]["streamId"],
        title: i["title"],
        link: i["canonical"][0]["href"],
        date: DateTime.fromMillisecondsSinceEpoch(i["published"] * 1000),
        content: dom.body.innerHtml,
        snippet: dom.documentElement.text.trim(),
        creator: i["author"],
        hasRead: false,
        starred: false,
      );
      if (inoreaderId != null) {
        final titleDom = parse(item.title);
        item.title = titleDom.documentElement.text;
      }
      var img = dom.querySelector("img");
      if (img != null && img.attributes["src"] != null) {
        var thumb = img.attributes["src"];
        if (thumb.startsWith("http")) {
          item.thumb = thumb;
        }
      }
      for (var c in i["categories"]) {
        if (!item.hasRead && c.endsWith("/state/com.google/read"))
          item.hasRead = true;
        else if (!item.starred && c.endsWith("/state/com.google/starred"))
          item.starred = true;
      }
      return item;
    }).toList();
    return parsedItems;
  }

  @override
  Future<Tuple2<Set<String>, Set<String>>> syncItems() async {
    List<Set<String>> results;
    if (inoreaderId != null) {
      results = await Future.wait([
        _fetchAll(
            "/reader/api/0/stream/items/ids?output=json&xt=$_READ_TAG&n=1000"),
        _fetchAll(
            "/reader/api/0/stream/items/ids?output=json&it=$_STAR_TAG&n=1000"),
      ]);
    } else {
      results = await Future.wait([
        _fetchAll(
            "/reader/api/0/stream/items/ids?output=json&s=$_ALL_TAG&xt=$_READ_TAG&n=1000"),
        _fetchAll(
            "/reader/api/0/stream/items/ids?output=json&s=$_STAR_TAG&n=1000"),
      ]);
    }
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
          _editTag(refs.join("&i="), _READ_TAG);
          refs = [];
        }
      }
      if (refs.length > 0) _editTag(refs.join("&i="), _READ_TAG);
    } else {
      if (sids.length == 0)
        sids = Set.from(Global.sourcesModel.getSources().map((s) => s.id));
      for (var sid in sids) {
        final body = {"s": sid};
        _fetchAPI("/reader/api/0/mark-all-as-read", body: body);
      }
    }
  }

  @override
  Future<void> markRead(RSSItem item) async {
    await _editTag(item.id, _READ_TAG);
  }

  @override
  Future<void> markUnread(RSSItem item) async {
    await _editTag(item.id, _READ_TAG, add: false);
  }

  @override
  Future<void> star(RSSItem item) async {
    await _editTag(item.id, _STAR_TAG);
  }

  @override
  Future<void> unstar(RSSItem item) async {
    await _editTag(item.id, _STAR_TAG, add: false);
  }
}
