import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/poem.dart';

/// 本地 SQLite 数据库：保存篇目与分句熟练/生疏标记
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'gushi_helper.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    // Linux 桌面平台需要 sqflite_common_ffi 初始化
    if (Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE poems (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            original_text TEXT NOT NULL,
            sentences TEXT NOT NULL,
            paragraphs TEXT NOT NULL DEFAULT '[]',
            practice_count INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sentence_marks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            poem_id INTEGER NOT NULL,
            sentence_index INTEGER NOT NULL,
            mark TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            UNIQUE(poem_id, sentence_index)
          )
        ''');
      },
    );
  }

  // ---------------- 篇目 ----------------

  Future<int> insertPoem(Poem poem) async {
    final db = await database;
    return db.insert('poems', poem.toMap()..remove('id'));
  }

  Future<List<Poem>> getAllPoems() async {
    final db = await database;
    final rows = await db.query('poems', orderBy: 'created_at DESC');
    final poems = rows.map(Poem.fromMap).toList();
    for (final poem in poems) {
      await _loadMarks(poem);
    }
    return poems;
  }

  Future<Poem?> getPoem(int id) async {
    final db = await database;
    final rows = await db.query('poems', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final poem = Poem.fromMap(rows.first);
    await _loadMarks(poem);
    return poem;
  }

  Future<void> updatePoem(Poem poem) async {
    final db = await database;
    await db.update('poems', poem.toMap(), where: 'id = ?', whereArgs: [poem.id]);
  }

  Future<void> deletePoem(int id) async {
    final db = await database;
    await db.delete('poems', where: 'id = ?', whereArgs: [id]);
    await db.delete('sentence_marks', where: 'poem_id = ?', whereArgs: [id]);
  }

  // ---------------- 分句标记 ----------------

  Future<void> _loadMarks(Poem poem) async {
    if (poem.id == null) return;
    final db = await database;
    final rows = await db.query(
      'sentence_marks',
      where: 'poem_id = ?',
      whereArgs: [poem.id],
    );
    poem.weakIndices.clear();
    poem.skilledIndices.clear();
    for (final row in rows) {
      final idx = row['sentence_index'] as int;
      if (row['mark'] == 'weak') {
        poem.weakIndices.add(idx);
      } else {
        poem.skilledIndices.add(idx);
      }
    }
  }

  /// 设置标记：mark 为 'skilled' | 'weak'，传 null 清除标记
  Future<void> setMark(int poemId, int sentenceIndex, String? mark) async {
    final db = await database;
    await db.delete(
      'sentence_marks',
      where: 'poem_id = ? AND sentence_index = ?',
      whereArgs: [poemId, sentenceIndex],
    );
    if (mark != null) {
      await db.insert('sentence_marks', {
        'poem_id': poemId,
        'sentence_index': sentenceIndex,
        'mark': mark,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
}
