// ==============================================
// SAFESPACE - APP STATE MANAGEMENT
// ==============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'models.dart';
import 'database.dart';

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
