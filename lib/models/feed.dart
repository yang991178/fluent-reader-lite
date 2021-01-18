import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:tuple/tuple.dart';

import 'item.dart';

enum FilterType {
  All, Unread, Starred
}

const _LOAD_LIMIT = 50;

class RSSFeed {
  bool initialized = false;
  bool loading = false;
  bool allLoaded = false;
  Set<String> sids;
  List<String> iids = [];
  FilterType filterType;
  String search = "";

  RSSFeed({this.sids}) {
    if (sids == null) sids = Set();
    filterType = FilterType.values[Store.sp.getInt(_filterKey) ?? 0];
  }

  String get _filterKey => sids.length == 0
    ? StoreKeys.FEED_FILTER_ALL
    : StoreKeys.FEED_FILTER_SOURCE;

  Tuple2<String, List<String>> _getPredicates() {
    List<String> where = ["1 = 1"];
    List<String> whereArgs = [];
    if (sids.length > 0) {
      var placeholders = List.filled(sids.length, "?").join(" , ");
      where.add("source IN ($placeholders)");
      whereArgs.addAll(sids);
    }
    if (filterType == FilterType.Unread) {
      where.add("hasRead = 0");
    } else if (filterType == FilterType.Starred) {
      where.add("starred = 1");
    }
    if (search != "") {
      where.add("(UPPER(title) LIKE ? OR UPPER(snippet) LIKE ?)");
      var keyword = "%$search%".toUpperCase();
      whereArgs.add(keyword);
      whereArgs.add(keyword);
    }
    return Tuple2(where.join(" AND "), whereArgs);
  }

  bool testItem(RSSItem item) {
    if (sids.length > 0 && !sids.contains(item.source)) return false;
    if (filterType == FilterType.Unread && item.hasRead) return false;
    if (filterType == FilterType.Starred && !item.starred) return false;
    if (search != "") {
      var keyword = search.toUpperCase();
      if (item.title.toUpperCase().contains(keyword)) return true;
      if (item.snippet.toUpperCase().contains(keyword)) return true;
      return false;
    }
    return true;
  }

  Future<void> init() async {
    if (loading) return;
    loading = true;
    var predicates = _getPredicates();
    var items = (await Global.db.query(
      "items",
      orderBy: "date DESC",
      limit: _LOAD_LIMIT,
      where: predicates.item1,
      whereArgs: predicates.item2,
    )).map((m) => RSSItem.fromMap(m)).toList();
    allLoaded = items.length < _LOAD_LIMIT;
    Global.itemsModel.loadItems(items);
    iids = items.map((i) => i.id).toList();
    loading = false;
    initialized = true;
    Global.feedsModel.broadcast();
  }

  Future<void> loadMore() async {
    if (loading || allLoaded) return;
    loading = true;
    var predicates = _getPredicates();
    var offset = iids
      .map((iid) => Global.itemsModel.getItem(iid))
      .fold(0, (c, i) => c + (testItem(i) ? 1 : 0));
    var items = (await Global.db.query(
      "items",
      orderBy: "date DESC",
      limit: _LOAD_LIMIT,
      offset: offset,
      where: predicates.item1,
      whereArgs: predicates.item2,
    )).map((m) => RSSItem.fromMap(m)).toList();
    if (items.length < _LOAD_LIMIT) {
      allLoaded = true;
    }
    Global.itemsModel.loadItems(items);
    iids.addAll(items.map((i) => i.id));
    loading = false;
    Global.feedsModel.broadcast();
  }

  Future<void> setFilter(FilterType filter) async {
    if (filterType == filter && filter == FilterType.All) return;
    filterType = filter;
    Store.sp.setInt(_filterKey, filter.index);
    await init();
  }

  Future<void> performSearch(String keyword) async {
    if (search == keyword) return;
    search = keyword;
    await init();
  }
}
