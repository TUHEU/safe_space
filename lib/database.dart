// ==============================================
// SAFESPACE - DATABASE HELPER
// ==============================================

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

// Note: models.dart needs to be included via main.dart or imported separately
// For this structure, we'll define MoodType here temporarily
enum MoodType { happy, calm, neutral, sad, stressed }

class MoodEntry {
  int? id;
  final MoodType mood;
  final DateTime date;
  final String? note;
  final double? intensity;

  MoodEntry({
    this.id,
    required this.mood,
    required this.date,
    this.note,
    this.intensity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mood': mood.index,
      'date': date.toIso8601String(),
      'note': note,
      'intensity': intensity ?? 0.5,
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'],
      mood: MoodType.values[map['mood']],
      date: DateTime.parse(map['date']),
      note: map['note'],
      intensity: map['intensity'],
    );
  }
}

class JournalEntry {
  final String id;
  final DateTime date;
  final String content;
  final MoodType? mood;

  JournalEntry({
    required this.id,
    required this.date,
    required this.content,
    this.mood,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'content': content,
      'mood': mood?.index,
    };
  }

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'],
      date: DateTime.parse(map['date']),
      content: map['content'],
      mood: map['mood'] != null ? MoodType.values[map['mood']] : null,
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, 'safespace.db');

    return await openDatabase(dbPath, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE moods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mood INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        intensity REAL DEFAULT 0.5
      )
    ''');

    await db.execute('''
      CREATE TABLE journal (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        content TEXT NOT NULL,
        mood INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE preferences (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.insert('preferences', {'key': 'darkMode', 'value': 'false'});
  }

  // Mood methods
  Future<int> insertMood(MoodEntry mood) async {
    final db = await database;
    return await db.insert('moods', mood.toMap());
  }

  Future<List<MoodEntry>> getAllMoods() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('moods');
    return List.generate(maps.length, (i) => MoodEntry.fromMap(maps[i]));
  }

  Future<List<MoodEntry>> getMoodsLast7Days() async {
    final db = await database;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final List<Map<String, dynamic>> maps = await db.query(
      'moods',
      where: 'date >= ?',
      whereArgs: [weekAgo.toIso8601String()],
    );
    return List.generate(maps.length, (i) => MoodEntry.fromMap(maps[i]));
  }

  Future<int> deleteMoodsByDate(DateTime date) async {
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();
    return await db.delete(
      'moods',
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
    );
  }

  // Journal methods
  Future<int> insertJournal(JournalEntry entry) async {
    final db = await database;
    return await db.insert('journal', entry.toMap());
  }

  Future<List<JournalEntry>> getAllJournals() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('journal');
    return List.generate(maps.length, (i) => JournalEntry.fromMap(maps[i]));
  }

  Future<int> deleteJournal(String id) async {
    final db = await database;
    return await db.delete('journal', where: 'id = ?', whereArgs: [id]);
  }

  // Preferences methods
  Future<void> setPreference(String key, String value) async {
    final db = await database;
    await db.insert('preferences', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getPreference(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'preferences',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  // Statistics methods
  Future<Map<MoodType, int>> getMoodFrequency() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT mood, COUNT(*) as count 
      FROM moods 
      GROUP BY mood
    ''');

    final frequency = <MoodType, int>{};
    for (var mood in MoodType.values) {
      frequency[mood] = 0;
    }

    for (var row in result) {
      final mood = MoodType.values[row['mood'] as int];
      frequency[mood] = row['count'] as int;
    }

    return frequency;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
