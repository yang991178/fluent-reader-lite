import 'dart:io';

import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/utils/db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Version 1 upgrades without losing articles or source preferences',
    () async {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfiNoIsolate;
      final directory = await Directory.systemTemp.createTemp(
        'frlite-upgrade-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await databaseFactory.setDatabasesPath(directory.path);
      final databasePath = path.join(directory.path, 'frlite.db');
      final legacy = await openDatabase(
        databasePath,
        version: 1,
        onCreate: (db, _) async {
          // The original schema, before source visibility was introduced.
          await db.execute('''CREATE TABLE sources (
        sid TEXT PRIMARY KEY, url TEXT NOT NULL, iconUrl TEXT,
        name TEXT NOT NULL, openTarget INTEGER NOT NULL,
        latest INTEGER NOT NULL, lastTitle INTEGER NOT NULL
      )''');
          await db.execute('''CREATE TABLE items (
        iid TEXT PRIMARY KEY, source TEXT NOT NULL, title TEXT NOT NULL,
        link TEXT NOT NULL, date INTEGER NOT NULL, content TEXT NOT NULL,
        snippet TEXT NOT NULL, hasRead INTEGER NOT NULL, starred INTEGER NOT NULL,
        creator TEXT, thumb TEXT
      )''');
        },
      );
      final source =
          RSSSource('original', 'https://example.com/feed', 'Custom name')
            ..openTarget = SourceOpenTarget.External
            ..iconUrl = 'https://example.com/custom.ico';
      final originalSource = source.toMap()..remove('hidden');
      await legacy.insert('sources', originalSource);
      await legacy.rawInsert('''INSERT INTO items
      (iid, source, title, link, date, content, snippet, hasRead, starred)
      VALUES ('article', 'original', 'Saved article', 'https://example.com/1',
      123, 'Body', 'Snippet', 0, 1)''');
      final originalItems = await legacy.query('items');
      await legacy.close();

      final upgraded = (await DatabaseHelper.getDatabase())!;
      expect(await upgraded.getVersion(), 2);
      expect(await upgraded.query('items'), originalItems);
      final rows = await upgraded.query('sources');
      expect(rows.single, {...originalSource, 'hidden': 0});
      final restored = RSSSource.fromMap(rows.single);
      expect(restored.hidden, isFalse);
      expect(restored.openTarget, SourceOpenTarget.External);
      expect(restored.iconUrl, source.iconUrl);
      restored.hidden = true;
      await upgraded.update('sources', restored.toMap());
      await upgraded.close();

      final reopened = await openDatabase(databasePath);
      addTearDown(reopened.close);
      expect(
        RSSSource.fromMap((await reopened.query('sources')).single).hidden,
        isTrue,
      );
      expect(await reopened.query('items'), originalItems);
    },
  );
}
