import 'package:fluent_reader_lite/models/item.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:tuple/tuple.dart';

enum SyncService {
  None, Fever, Feedbin, GReader, Inoreader
}

abstract class ServiceHandler {
  void remove() {
    Store.sp.remove(StoreKeys.SYNC_SERVICE);
    Global.groupsModel.groups = Map();
    Global.groupsModel.showUncategorized = false;
  }
  Future<bool> validate();
  Future<void> reauthenticate() async { }
  Future<Tuple2<List<RSSSource>, Map<String, List<String>>>> getSources();
  Future<List<RSSItem>> fetchItems();
  Future<Tuple2<Set<String>, Set<String>>> syncItems();
  Future<void> markAllRead(Set<String> sids, DateTime date, bool before);
  Future<void> markRead(RSSItem item);
  Future<void> markUnread(RSSItem item);
  Future<void> star(RSSItem item);
  Future<void> unstar(RSSItem item);
}
