import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/call_log_model.dart';

class CallLogDB {
  static final CallLogDB _i = CallLogDB._();
  CallLogDB._();
  factory CallLogDB() => _i;

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'call_logs.db'),
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE call_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            callId TEXT UNIQUE,
            peerId TEXT,
            peerName TEXT,
            peerAvatar TEXT,
            direction TEXT,
            type TEXT,
            status TEXT,
            startedAt INTEGER,
            endedAt INTEGER,
            durationSeconds INTEGER
          )
        ''');
        await db.execute('CREATE INDEX idx_callid ON call_logs(callId)');
        await db.execute('CREATE INDEX idx_started ON call_logs(startedAt DESC)');
      },
    );
    return _db!;
  }

  Future<int> upsertByCallId(CallLog log) async {
    final db = await _open();
    return db.insert(
      'call_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CallLog>> fetchAll() async {
    final db = await _open();
    final rows = await db.query(
      'call_logs',
      orderBy: 'startedAt DESC',
    );
    return rows.map(CallLog.fromMap).toList();
  }

  Future<void> delete(int id) async {
    final db = await _open();
    await db.delete('call_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await _open();
    await db.delete('call_logs');
  }
}
