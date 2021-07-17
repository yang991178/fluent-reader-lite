import 'dart:convert';
import 'dart:math';

import 'package:fluent_reader_lite/models/item.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:fluent_reader_lite/utils/utils.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:fluent_reader_lite/models/source.dart';
import 'package:tuple/tuple.dart';

import '../service.dart';

class FeverServiceHandler extends ServiceHandler {
  String endpoint;
  String apiKey;
  int _lastId;
  int fetchLimit;
  bool _useInt32;

  FeverServiceHandler() {
    endpoint = Store.sp.getString(StoreKeys.ENDPOINT);
    apiKey = Store.sp.getString(StoreKeys.API_KEY);
    _lastId = Store.sp.getInt(StoreKeys.LAST_ID) ?? 0;
    fetchLimit = Store.sp.getInt(StoreKeys.FETCH_LIMIT);
    _useInt32 = Store.sp.getBool(StoreKeys.FEVER_INT_32) ?? false;
  }

  FeverServiceHandler.fromValues(
    this.endpoint,
    this.apiKey,
    this.fetchLimit,
  ) {
    _lastId = Store.sp.getInt(StoreKeys.LAST_ID) ?? 0;
    _useInt32 = Store.sp.getBool(StoreKeys.FEVER_INT_32) ?? false;
  }

  void persist(String username, String password) {
    Store.sp.setInt(StoreKeys.SYNC_SERVICE, SyncService.Fever.index);
    Store.sp.setString(StoreKeys.ENDPOINT, endpoint);
    Store.sp.setString(StoreKeys.USERNAME, username);
    Store.sp.setString(StoreKeys.PASSWORD, password);
    Store.sp.setString(StoreKeys.API_KEY, apiKey);
    Store.sp.setInt(StoreKeys.FETCH_LIMIT, fetchLimit);
    Store.sp.setInt(StoreKeys.LAST_ID, _lastId);
    Store.sp.setBool(StoreKeys.FEVER_INT_32, _useInt32);
    Global.service = this;
  }

  @override
  void remove() {
    super.remove();
    Store.sp.remove(StoreKeys.ENDPOINT);
    Store.sp.remove(StoreKeys.USERNAME);
    Store.sp.remove(StoreKeys.PASSWORD);
    Store.sp.remove(StoreKeys.API_KEY);
    Store.sp.remove(StoreKeys.FETCH_LIMIT);
    Store.sp.remove(StoreKeys.LAST_ID);
    Store.sp.remove(StoreKeys.FEVER_INT_32);
    Global.service = null;
  }

  Future<Map<String, dynamic>> _fetchAPI({params: "", postparams: ""}) async {
    var uri = Uri.parse(endpoint + "?api" + params);
    final response = await http.post(
      uri,
      headers: {"content-type": "application/x-www-form-urlencoded"},
      body: "api_key=$apiKey$postparams",
    );
    final body = Utf8Decoder().convert(response.bodyBytes);
    return jsonDecode(body);
  }

  int get lastId => _lastId;
  set lastId(int value) {
    _lastId = value;
    Store.sp.setInt(StoreKeys.LAST_ID, value);
  }

  bool get useInt32 => _useInt32;
  set useInt32(bool value) {
    _useInt32 = value;
    Store.sp.setBool(StoreKeys.FEVER_INT_32, value);
  }

  @override
  Future<bool> validate() async {
    try {
      return (await _fetchAPI())["auth"] == 1;
    } catch (exp) {
      return false;
    }
  }

  @override
  Future<Tuple2<List<RSSSource>, Map<String, List<String>>>>
      getSources() async {
    var response = await _fetchAPI(params: "&feeds");
    var sources = response["feeds"].map<RSSSource>((f) {
      return RSSSource(f["id"].toString(), f["url"], f["title"]);
    }).toList();
    var feedGroups = response["feeds_groups"];
    var groupsMap = Map<String, List<String>>();
    var groups = (await _fetchAPI(params: "&groups"))["groups"];
    if (groups == null || feedGroups == null) throw Error();
    var groupsIdMap = Map<int, String>();
    for (var group in groups) {
      var title = group["title"].trim();
      groupsIdMap[group["id"]] = title;
    }
    for (var group in feedGroups) {
      var name = groupsIdMap[group["group_id"]];
      for (var fid in group["feed_ids"].split(",")) {
        groupsMap.putIfAbsent(name, () => []);
        groupsMap[name].add(fid);
      }
    }
    return Tuple2(sources, groupsMap);
  }

  @override
  Future<List<RSSItem>> fetchItems() async {
    var minId = useInt32 ? 2147483647 : Utils.syncMaxId;
    List<dynamic> response;
    List<dynamic> items = [];
    do {
      response = (await _fetchAPI(params: "&items&max_id=$minId"))["items"];
      if (response == null) throw Error();
      for (var i in response) {
        if (i["id"] is String) i["id"] = int.parse(i["id"]);
        if (i["id"] > lastId) items.add(i);
      }
      if (response.length == 0 && minId == Utils.syncMaxId) {
        useInt32 = true;
        minId = 2147483647;
        response = null;
      } else {
        minId = response.fold(minId, (m, n) => min<int>(m, n["id"]));
      }
    } while (minId > lastId &&
        (response == null || response.length >= 50) &&
        items.length < fetchLimit);
    var parsedItems = items.map<RSSItem>((i) {
      var dom = parse(i["html"]);
      var item = RSSItem(
        id: i["id"].toString(),
        source: i["feed_id"].toString(),
        title: i["title"],
        link: i["url"],
        date: DateTime.fromMillisecondsSinceEpoch(i["created_on_time"] * 1000),
        content: i["html"],
        snippet: dom.documentElement.text.trim(),
        creator: i["author"],
        hasRead: i["is_read"] == 1,
        starred: i["is_saved"] == 1,
      );
      // Try to get the thumbnail of the item
      var img = dom.querySelector("img");
      if (img != null && img.attributes["src"] != null) {
        var thumb = img.attributes["src"];
        if (thumb.startsWith("http")) {
          item.thumb = thumb;
        }
      } else if (useInt32) {
        // TTRSS Fever Plugin attachments
        var a = dom.querySelector("body>ul>li:first-child>a");
        if (a != null &&
            a.text.endsWith(", image\/generic") &&
            a.attributes["href"] != null) item.thumb = a.attributes["href"];
      }
      return item;
    });
    lastId = items.fold(lastId, (m, n) => max(m, n["id"]));
    return parsedItems.toList();
  }

  @override
  Future<Tuple2<Set<String>, Set<String>>> syncItems() async {
    final responses = await Future.wait([
      _fetchAPI(params: "&unread_item_ids"),
      _fetchAPI(params: "&saved_item_ids"),
    ]);
    final unreadIds = responses[0]["unread_item_ids"];
    final starredIds = responses[1]["saved_item_ids"];
    return Tuple2(
        Set.from(unreadIds.split(",")), Set.from(starredIds.split(",")));
  }

  Future<void> _markItem(RSSItem item, String asType) async {
    try {
      await _fetchAPI(postparams: "&mark=item&as=$asType&id=${item.id}");
    } catch (exp) {
      print(exp);
    }
  }

  @override
  Future<void> markAllRead(Set<String> sids, DateTime date, bool before) async {
    if (date != null && !before) {
      var items = Global.itemsModel.getItems().where((i) =>
          (sids.length == 0 || sids.contains(i.source)) &&
          i.date.compareTo(date) >= 0);
      await Future.wait(items.map((i) => markRead(i)));
    } else {
      var timestamp = date != null
          ? date.millisecondsSinceEpoch
          : DateTime.now().millisecondsSinceEpoch;
      timestamp = timestamp ~/ 1000 + 1;
      try {
        await Future.wait(Global.sourcesModel
            .getSources()
            .where((s) => sids.length == 0 || sids.contains(s.id))
            .map((s) => _fetchAPI(
                postparams:
                    "&mark=feed&as=read&id=${s.id}&before=$timestamp")));
      } catch (exp) {
        print(exp);
      }
    }
  }

  @override
  Future<void> markRead(RSSItem item) async {
    await _markItem(item, "read");
  }

  @override
  Future<void> markUnread(RSSItem item) async {
    await _markItem(item, "unread");
  }

  @override
  Future<void> star(RSSItem item) async {
    await _markItem(item, "saved");
  }

  @override
  Future<void> unstar(RSSItem item) async {
    await _markItem(item, "unsaved");
  }
}
