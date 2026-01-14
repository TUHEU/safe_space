// ==============================================
// SAFESPACE - APP STATE MANAGEMENT
// ==============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

// Re-define MoodType here for this file
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

class AppState extends ChangeNotifier {
  List<MoodEntry> _moodEntries = [];
  List<JournalEntry> _journalEntries = [];
  bool _darkMode = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<MoodEntry> get moodEntries => _moodEntries;
  List<JournalEntry> get journalEntries => _journalEntries;
  bool get darkMode => _darkMode;

  // Positive affirmations
  static final List<String> _affirmations = [
    'Tu fais de ton mieux, et c\'est suffisant.',
    'Ce que tu ressens est valide.',
    'Prendre soin de soi n\'est pas un luxe, c\'est une nécessité.',
    'Chaque petit pas compte.',
    'Tu n\'es pas seul(e) dans ce que tu traverses.',
    'La paix commence par une seule respiration.',
    'Tu as le droit de prendre du temps pour toi.',
    'Les émotions sont comme les nuages : elles passent.',
    'Aujourd\'hui est un nouveau départ.',
    'Tu es plus fort(e) que tu ne le penses.',
    'Respire. Tout va bien se passer.',
    'Ton bien-être est important.',
  ];

  String getRandomAffirmation() {
    final random = DateTime.now().millisecondsSinceEpoch % _affirmations.length;
    return _affirmations[random];
  }

  MoodEntry? get todaysMood {
    final today = DateTime.now();
    for (var entry in _moodEntries) {
      if (entry.date.year == today.year &&
          entry.date.month == today.month &&
          entry.date.day == today.day) {
        return entry;
      }
    }
    return null;
  }

  int get checkInDays => _moodEntries.length;

  // Load data from database
  Future<void> loadData() async {
    try {
      _moodEntries = await _dbHelper.getAllMoods();
      _journalEntries = await _dbHelper.getAllJournals();

      final darkModeStr = await _dbHelper.getPreference('darkMode');
      _darkMode = darkModeStr == 'true';

      notifyListeners();
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  // Add mood entry
  Future<void> addMoodEntry(MoodEntry entry) async {
    try {
      await _dbHelper.insertMood(entry);
      _moodEntries = await _dbHelper.getAllMoods();
      notifyListeners();
    } catch (e) {
      print('Error adding mood entry: $e');
    }
  }

  // Update today's mood
  Future<void> updateTodaysMood(MoodEntry newEntry) async {
    try {
      final today = DateTime.now();
      await _dbHelper.deleteMoodsByDate(today);
      await _dbHelper.insertMood(newEntry);
      _moodEntries = await _dbHelper.getAllMoods();
      notifyListeners();
    } catch (e) {
      print('Error updating mood: $e');
    }
  }

  // Journal operations
  Future<void> addJournalEntry(JournalEntry entry) async {
    try {
      await _dbHelper.insertJournal(entry);
      _journalEntries = await _dbHelper.getAllJournals();
      notifyListeners();
    } catch (e) {
      print('Error adding journal entry: $e');
    }
  }

  Future<void> deleteJournalEntry(String id) async {
    try {
      await _dbHelper.deleteJournal(id);
      _journalEntries = await _dbHelper.getAllJournals();
      notifyListeners();
    } catch (e) {
      print('Error deleting journal entry: $e');
    }
  }

  // Theme toggle
  Future<void> toggleDarkMode() async {
    _darkMode = !_darkMode;
    try {
      await _dbHelper.setPreference('darkMode', _darkMode.toString());
      notifyListeners();
    } catch (e) {
      print('Error toggling dark mode: $e');
    }
  }

  // Statistics
  Future<Map<MoodType, int>> getMoodFrequency() async {
    return await _dbHelper.getMoodFrequency();
  }

  Future<MoodType?> getMostFrequentMood() async {
    final frequency = await getMoodFrequency();
    if (frequency.isEmpty) return null;

    final entries = frequency.entries.toList();
    MoodType? mostFrequent;
    int maxCount = 0;

    for (var entry in entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostFrequent = entry.key;
      }
    }

    return mostFrequent;
  }

  Future<List<MoodEntry>> getLastWeekEntries() async {
    return await _dbHelper.getMoodsLast7Days();
  }

  // Clear all data (for development/testing)
  Future<void> clearAllData() async {
    try {
      final db = await _dbHelper.database;
      await db.delete('moods');
      await db.delete('journal');
      _moodEntries = [];
      _journalEntries = [];
      notifyListeners();
    } catch (e) {
      print('Error clearing data: $e');
    }
  }
}

// DatabaseHelper class needed for this file
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
}
