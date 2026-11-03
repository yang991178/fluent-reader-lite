import 'dart:async';
import 'dart:io';

import 'package:fluent_reader_lite/models/feed.dart';
import 'package:fluent_reader_lite/models/item.dart';
import 'package:fluent_reader_lite/models/service.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/utils/db.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:tuple/tuple.dart';

import 'support/reader_fixture.dart';

RSSItem article(
  int id,
  String source, {
  bool read = false,
  bool starred = false,
}) => RSSItem(
  id: '$id',
  source: source,
  title: 'Article $id',
  link: 'https://example.com/articles/$id',
  date: DateTime.utc(2026, 10, 20).add(Duration(minutes: id)),
  content: 'Body $id',
  snippet: 'Snippet $id',
  hasRead: read,
  starred: starred,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late _Service service;

  setUpAll(() async {
    ffi.sqfliteFfiInit();
    databaseFactory = ffi.databaseFactoryFfiNoIsolate;
    final directory = await Directory.systemTemp.createTemp(
      'frlite-visibility-',
    );
    await databaseFactory.setDatabasesPath(directory.path);
    db = (await DatabaseHelper.getDatabase())!;
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Store.sp = await SharedPreferences.getInstance();
    initializeReaderFixture();
    Global.sourcesModel!.dispose();
    Global.sourcesModel = SourcesModel();
    Global.db = db;
    Global.service = service = _Service();
    await db.delete('items');
    await db.delete('sources');
    for (final id in ['visible', 'quiet']) {
      await Global.sourcesModel!.put(
        RSSSource(id, 'https://example.com/$id', id)..iconUrl = '',
      );
    }
    for (final item in [
      article(0, 'visible'),
      article(1, 'quiet', starred: true),
      article(2, 'visible', read: true, starred: true),
      article(3, 'quiet', read: true),
    ]) {
      await db.insert('items', item.toMap());
    }
    await Global.sourcesModel!.updateUnreadCounts();
    await Global.feedsModel!.all.init();
  });

  tearDown(() {
    Global.globalModel!.dispose();
    Global.sourcesModel!.dispose();
    Global.itemsModel!.dispose();
    Global.feedsModel!.dispose();
    Global.groupsModel!.dispose();
    Global.syncModel!.dispose();
    Global.db = null;
    Global.service = null;
  });

  test(
    'New source rows default to visible when visibility is omitted',
    () async {
      final values = RSSSource(
        'default',
        'https://example.com/default',
        'Default',
      ).toMap()..remove('hidden');
      await db.insert('sources', values);
      final stored = (await db.query(
        'sources',
        where: 'sid = ?',
        whereArgs: ['default'],
      )).single;
      expect(stored['hidden'], 0);
      expect(RSSSource.fromMap(stored).hidden, isFalse);
      expect(RSSSource.fromMap(values).hidden, isFalse);
    },
  );

  test(
    'Fresh sources default to visible and hidden survives cloning and reload',
    () async {
      final all = Global.feedsModel!.all;
      expect(all.iids, ['3', '2', '1', '0']);
      expect(Global.sourcesModel!.getSource('quiet')!.hidden, isFalse);
      await all.setFilter(FilterType.Unread);
      await all.performSearch('Article');
      await Global.sourcesModel!.setHidden('quiet', true);
      expect(all.iids, ['0']);
      expect(all.filterType, FilterType.Unread);
      expect(all.search, 'Article');

      final edited = Global.sourcesModel!.getSource('quiet')!.clone()
        ..name = 'Renamed'
        ..openTarget = SourceOpenTarget.FullContent;
      expect(edited.hidden, isTrue);
      await Global.sourcesModel!.put(edited);
      Global.sourcesModel!.dispose();
      Global.sourcesModel = SourcesModel();
      await Global.sourcesModel!.init();
      expect(Global.sourcesModel!.getSource('quiet')!.hidden, isTrue);
      expect(Global.sourcesModel!.getSource('quiet')!.name, 'Renamed');
      await all.init();
      expect(all.iids, ['0']);
      await Global.sourcesModel!.updateSources();
      await all.init();
      expect(Global.sourcesModel!.getSource('quiet')!.hidden, isTrue);
      await Global.sourcesModel!.setHidden('quiet', false);
      expect(all.iids, ['1', '0']);
      expect(
        (await db.query(
          'sources',
          where: 'sid = ?',
          whereArgs: ['quiet'],
        )).single['hidden'],
        0,
      );
    },
  );

  test('All filters and search exclude hidden sources while source and group feeds include them', () async {
    await Global.sourcesModel!.setHidden('quiet', true);
    final all = Global.feedsModel!.all;
    final source = RSSFeed(sids: {'quiet'});
    final group = RSSFeed(sids: {'visible', 'quiet'});
    for (final filter in FilterType.values) {
      await all.setFilter(filter);
      await source.setFilter(filter);
      await group.setFilter(filter);
      await source.init();
      await group.init();
      final expected = filter == FilterType.All
          ? ['2', '0']
          : filter == FilterType.Unread
          ? ['0']
          : ['2'];
      expect(all.iids, expected);
      final storedItems = (await db.query(
        'items',
        orderBy: 'date DESC',
      )).map(RSSItem.fromMap);
      expect(all.iids, storedItems.where(all.testItem).map((item) => item.id));
      expect(
        source.iids,
        storedItems.where(source.testItem).map((item) => item.id),
      );
      expect(
        group.iids,
        storedItems.where(group.testItem).map((item) => item.id),
      );
      expect(source.iids, isNotEmpty);
      expect(group.iids.length, greaterThan(all.iids.length));
    }
    await all.setFilter(FilterType.All);
    await source.setFilter(FilterType.All);
    await all.performSearch('article 1');
    await source.performSearch('article 1');
    expect(all.iids, isEmpty);
    expect(source.iids, ['1']);
    expect(all.effectiveSourceIds, {'visible'});
    expect(group.effectiveSourceIds, {'visible', 'quiet'});
    expect(Global.sourcesModel!.getSource('quiet')!.unreadCount, 1);
  });

  test(
    'Synced hidden articles are stored and enter source feeds only',
    () async {
      await Global.feedsModel!.initSourcesFeed(['quiet']);
      await Global.sourcesModel!.setHidden('quiet', true);
      service.fetchedItems = [article(4, 'quiet'), article(5, 'visible')];
      await Global.itemsModel!.fetchItems();
      // Wait for source metadata persistence scheduled by fetchItems.
      await db.query('sources');
      expect(Global.feedsModel!.all.iids, ['5', '2', '0']);
      expect(Global.feedsModel!.source!.iids, ['4', '3', '1']);
      expect(Global.itemsModel!.getItem('4'), isNotNull);
      expect(
        (await db.query('items', where: 'iid = ?', whereArgs: ['4'])),
        hasLength(1),
      );
      expect(Global.sourcesModel!.getSource('quiet')!.unreadCount, 2);
    },
  );

  test('A hide refresh supersedes an in-flight initial load', () async {
    final delayed = _DelayedDatabase(db);
    Global.db = delayed;
    final pending = Global.feedsModel!.all.init();
    await delayed.captured.future;
    await Global.sourcesModel!.setHidden('quiet', true);
    delayed.release.complete();
    await pending;
    expect(Global.feedsModel!.all.iids, ['2', '0']);
    expect(Global.feedsModel!.all.loading, isFalse);
  });

  test('Pagination excludes hidden sources and discards an older page after toggling', () async {
    await db.delete('items');
    final batch = db.batch();
    for (var id = 0; id < 120; id++) {
      batch.insert(
        'items',
        article(id, id.isEven ? 'visible' : 'quiet').toMap(),
      );
    }
    await batch.commit(noResult: true);
    final all = Global.feedsModel!.all;
    await all.init();
    expect(all.iids, hasLength(50));
    final delayed = _DelayedDatabase(db);
    Global.db = delayed;
    final pending = all.loadMore();
    await delayed.captured.future;
    await Global.sourcesModel!.setHidden('quiet', true);
    delayed.release.complete();
    await pending;
    expect(all.iids, hasLength(50));
    await all.loadMore();
    expect(all.iids, [for (var id = 118; id >= 0; id -= 2) '$id']);
    expect(all.allLoaded, isTrue);
  });

  for (final before in [null, true, false]) {
    test('Feed bulk read excludes hidden sources (before: $before)', () async {
      await Global.sourcesModel!.setHidden('quiet', true);
      await Global.itemsModel!.markAllRead(
        Global.feedsModel!.all.effectiveSourceIds,
        date: before == null ? null : article(1, 'quiet').date,
        before: before ?? true,
      );
      expect(service.markedSources, [
        {'visible'},
      ]);
      expect(Global.itemsModel!.getItem('1')!.hasRead, isFalse);
      expect(Global.sourcesModel!.getSource('quiet')!.unreadCount, 1);
      final visible = (await db.query(
        'items',
        where: 'iid = ?',
        whereArgs: ['0'],
      )).single;
      expect(visible['hasRead'], before == false ? 0 : 1);
    });
  }

  test('An all-hidden feed is empty and bulk read is a no-op; subscriptions can still mark all', () async {
    await Global.sourcesModel!.setHidden('quiet', true);
    await Global.sourcesModel!.setHidden('visible', true);
    final all = Global.feedsModel!.all;
    for (final filter in FilterType.values) {
      await all.setFilter(filter);
      expect(all.iids, isEmpty);
      expect(all.allLoaded, isTrue);
    }
    final before = await db.query('items');
    await Global.itemsModel!.markAllRead(all.effectiveSourceIds);
    expect(service.markedSources, isEmpty);
    expect(await db.query('items'), before);
    await Global.itemsModel!.markAllRead(
      Global.sourcesModel!.getSources().map((source) => source.id).toSet(),
    );
    expect(service.markedSources, [
      {'visible', 'quiet'},
    ]);
    expect(await db.query('items', where: 'hasRead = 0'), isEmpty);
  });
}

class _Service extends ServiceHandler {
  List<RSSItem> fetchedItems = [];
  final markedSources = <Set<String?>>[];

  @override
  Future<List<RSSItem>> fetchItems() async => fetchedItems;

  @override
  Future<Tuple2<List<RSSSource>?, Map<String?, List<String?>>>>
  getSources() async => Tuple2(
    [
      for (final id in ['visible', 'quiet'])
        RSSSource(id, 'https://example.com/$id', id),
    ],
    {
      'Group': ['visible', 'quiet'],
    },
  );

  @override
  Future<void> markAllRead(
    Set<String?> sids,
    DateTime? date,
    bool before,
  ) async {
    markedSources.add(Set.of(sids));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Hold one completed SQLite query so a settings refresh can overtake its result.
class _DelayedDatabase implements Database {
  _DelayedDatabase(this.delegate);
  final Database delegate;
  final captured = Completer<void>();
  final release = Completer<void>();
  bool delayNextQuery = true;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final rows = await delegate.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    if (table == 'items' && delayNextQuery) {
      delayNextQuery = false;
      captured.complete();
      await release.future;
    }
    return rows;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) => delegate.insert(
    table,
    values,
    nullColumnHack: nullColumnHack,
    conflictAlgorithm: conflictAlgorithm,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
