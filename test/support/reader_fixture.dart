import 'package:fluent_reader_lite/models/feeds_model.dart';
import 'package:fluent_reader_lite/models/global_model.dart';
import 'package:fluent_reader_lite/models/groups_model.dart';
import 'package:fluent_reader_lite/models/item.dart';
import 'package:fluent_reader_lite/models/items_model.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/models/sync_model.dart';
import 'package:fluent_reader_lite/utils/global.dart';

void initializeReaderFixture() {
  Global.globalModel = GlobalModel();
  Global.sourcesModel = _FixtureSources();
  Global.itemsModel = ItemsModel();
  Global.feedsModel = FeedsModel();
  Global.groupsModel = GroupsModel();
  Global.syncModel = SyncModel()..hasService = true;
  final items = List.generate(
    2,
    (index) => RSSItem(
      id: '$index',
      source: 'fixture',
      title: 'Article $index',
      link: 'http://127.0.0.1:9000/fixture/story',
      date: DateTime(2026, 10, 21),
      content: '<p>Article $index content for testing the reader theme.</p>',
      snippet: 'Article $index content',
      hasRead: true,
      starred: false,
    ),
  );
  Global.itemsModel!.loadItems(items);
  Global.feedsModel!.all
    ..iids = items.map((item) => item.id).toList()
    ..initialized = true
    ..allLoaded = true;
}

class _FixtureSources extends SourcesModel {
  final source = RSSSource('fixture', 'https://example.com', 'Test source');

  @override
  RSSSource? getSource(String? id) => id == source.id ? source : null;

  @override
  Iterable<RSSSource> getSources() => [source];
}
