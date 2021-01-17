import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

abstract class DatabaseHelper {
  static final _dbName = "frlite.db";
  static final _dbVersion = 1;

  static Database _database;

  static Future<Database> getDatabase() async {
    if (_database != null) return _database;
    String path = join(await getDatabasesPath(), _dbName);
    _database = await openDatabase(path, version:_dbVersion, onCreate: _onCreate);
    return _database;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sources (
        sid TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        iconUrl TEXT,
        name TEXT NOT NULL,
        openTarget INTEGER NOT NULL,
        latest INTEGER NOT NULL,
        lastTitle INTEGER NOT NULL
      );
    ''');
    await db.execute('''
    CREATE TABLE items (
        iid TEXT PRIMARY KEY,
        source TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT NOT NULL,
        date INTEGER NOT NULL,
        content TEXT NOT NULL,
        snippet TEXT NOT NULL,
        hasRead INTEGER NOT NULL,
        starred INTEGER NOT NULL,
        creator TEXT,
        thumb TEXT
      );
    ''');
    await db.execute("CREATE INDEX itemsDate ON items (date DESC);");
  }
}