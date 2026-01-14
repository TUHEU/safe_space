// ==============================================
// SAFESPACE - DATA MODELS
// ==============================================

import 'dart:convert';

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

  String toJson() => json.encode(toMap());

  factory MoodEntry.fromJson(String source) =>
      MoodEntry.fromMap(json.decode(source));
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

  String toJson() => json.encode(toMap());

  factory JournalEntry.fromJson(String source) =>
      JournalEntry.fromMap(json.decode(source));
}

// Helper functions for MoodType
extension MoodTypeExtension on MoodType {
  String get label {
    switch (this) {
      case MoodType.happy:
        return 'Heureux';
      case MoodType.calm:
        return 'Calme';
      case MoodType.neutral:
        return 'Neutre';
      case MoodType.sad:
        return 'Triste';
      case MoodType.stressed:
        return 'Stressé';
    }
  }

  String get fullLabel {
    switch (this) {
      case MoodType.happy:
        return 'Heureux(se)';
      case MoodType.calm:
        return 'Calme';
      case MoodType.neutral:
        return 'Neutre';
      case MoodType.sad:
        return 'Triste';
      case MoodType.stressed:
        return 'Stressé(e)';
    }
  }
}
