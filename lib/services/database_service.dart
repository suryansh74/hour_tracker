import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/hour_entry.dart';

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'hour_tracker.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            color INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            hour INTEGER NOT NULL,
            categoryId INTEGER,
            note TEXT,
            loggedAt TEXT NOT NULL,
            snoozed INTEGER NOT NULL DEFAULT 0,
            UNIQUE(date, hour)
          )
        ''');
        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        // Seed default categories on first run.
        for (final cat in defaultCategories()) {
          await db.insert('categories', cat.toMap());
        }
      },
    );
  }

  // ---------------- Categories ----------------

  Future<List<TrackCategory>> getCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'id ASC');
    return rows.map((r) => TrackCategory.fromMap(r)).toList();
  }

  Future<int> insertCategory(TrackCategory category) async {
    final db = await database;
    return db.insert('categories', category.toMap());
  }

  Future<void> updateCategory(TrackCategory category) async {
    final db = await database;
    await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Entries ----------------

  /// Insert or overwrite the entry for a given date+hour.
  Future<void> upsertEntry(HourEntry entry) async {
    final db = await database;
    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HourEntry>> getEntriesForDate(String date) async {
    final db = await database;
    final rows = await db.query('entries', where: 'date = ?', whereArgs: [date]);
    return rows.map((r) => HourEntry.fromMap(r)).toList();
  }

  /// Inclusive date range, dates as 'yyyy-MM-dd', ascending.
  Future<List<HourEntry>> getEntriesForRange(String startDate, String endDate) async {
    final db = await database;
    final rows = await db.query(
      'entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC, hour ASC',
    );
    return rows.map((r) => HourEntry.fromMap(r)).toList();
  }

  Future<void> deleteEntry(String date, int hour) async {
    final db = await database;
    await db.delete('entries', where: 'date = ? AND hour = ?', whereArgs: [date, hour]);
  }

  /// Deletes every entry strictly before [cutoffDate] (yyyy-MM-dd). Used for
  /// optional long-term data retention cleanup.
  Future<int> deleteEntriesBefore(String cutoffDate) async {
    final db = await database;
    return db.delete('entries', where: 'date < ?', whereArgs: [cutoffDate]);
  }

  // ---------------- Settings (key-value) ----------------

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
