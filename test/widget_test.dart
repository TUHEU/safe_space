// ==============================================
// SAFESPACE - Application Flutter Complète
// Version avec Splash Screen et couleurs attrayantes
// Tous les boutons fonctionnels
// Base de données SQLite
// ==============================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:page_transition/page_transition.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SafeSpaceApp());
}

// ==============================================
// 1. MODÈLES DE DONNÉES
// ==============================================

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

// ==============================================
// 2. BASE DE DONNÉES SQLite
// ==============================================

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
    final dbPath = p.join(
      databasesPath,
      'safespace.db',
    ); // Changed variable name to avoid conflict

    return await openDatabase(dbPath, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table des humeurs
    await db.execute('''
      CREATE TABLE moods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mood INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        intensity REAL DEFAULT 0.5
      )
    ''');

    // Table du journal
    await db.execute('''
      CREATE TABLE journal (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        content TEXT NOT NULL,
        mood INTEGER
      )
    ''');

    // Table des préférences
    await db.execute('''
      CREATE TABLE preferences (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Insérer la valeur par défaut pour le mode sombre
    await db.insert('preferences', {'key': 'darkMode', 'value': 'false'});
  }

  // Méthodes pour les humeurs
  Future<int> insertMood(MoodEntry mood) async {
    final db = await database;
    return await db.insert('moods', mood.toMap());
  }

  Future<List<MoodEntry>> getAllMoods() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('moods');
    return List.generate(maps.length, (i) => MoodEntry.fromMap(maps[i]));
  }

  Future<List<MoodEntry>> getMoodsByDate(DateTime date) async {
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();
    final List<Map<String, dynamic>> maps = await db.query(
      'moods',
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'],
    );
    return List.generate(maps.length, (i) => MoodEntry.fromMap(maps[i]));
  }

  Future<int> updateMood(MoodEntry mood) async {
    final db = await database;
    return await db.update(
      'moods',
      mood.toMap(),
      where: 'id = ?',
      whereArgs: [mood.id],
    );
  }

  Future<int> deleteMood(int id) async {
    final db = await database;
    return await db.delete('moods', where: 'id = ?', whereArgs: [id]);
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

  // Méthodes pour le journal
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

  // Méthodes pour les préférences
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

  // Statistiques
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

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

// ==============================================
// 3. GESTION D'ÉTAT
// ==============================================

class AppState extends ChangeNotifier {
  List<MoodEntry> _moodEntries = [];
  List<JournalEntry> _journalEntries = [];
  bool _darkMode = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<MoodEntry> get moodEntries => _moodEntries;
  List<JournalEntry> get journalEntries => _journalEntries;
  bool get darkMode => _darkMode;

  // Affirmations positives
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

  // Charger les données depuis SQLite
  Future<void> loadData() async {
    try {
      _moodEntries = await _dbHelper.getAllMoods();
      _journalEntries = await _dbHelper.getAllJournals();

      // Charger le thème
      final darkModeStr = await _dbHelper.getPreference('darkMode');
      _darkMode = darkModeStr == 'true';

      notifyListeners();
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  // Ajouter une humeur
  Future<void> addMoodEntry(MoodEntry entry) async {
    try {
      await _dbHelper.insertMood(entry);
      _moodEntries = await _dbHelper.getAllMoods();
      notifyListeners();
    } catch (e) {
      print('Error adding mood entry: $e');
    }
  }

  // Mettre à jour l'humeur du jour
  Future<void> updateTodaysMood(MoodEntry newEntry) async {
    try {
      final today = DateTime.now();

      // Supprimer les anciennes entrées du jour
      await _dbHelper.deleteMoodsByDate(today);

      // Ajouter la nouvelle entrée
      await _dbHelper.insertMood(newEntry);
      _moodEntries = await _dbHelper.getAllMoods();
      notifyListeners();
    } catch (e) {
      print('Error updating mood: $e');
    }
  }

  // Ajouter une entrée de journal
  Future<void> addJournalEntry(JournalEntry entry) async {
    try {
      await _dbHelper.insertJournal(entry);
      _journalEntries = await _dbHelper.getAllJournals();
      notifyListeners();
    } catch (e) {
      print('Error adding journal entry: $e');
    }
  }

  // Supprimer une entrée de journal
  Future<void> deleteJournalEntry(String id) async {
    try {
      await _dbHelper.deleteJournal(id);
      _journalEntries = await _dbHelper.getAllJournals();
      notifyListeners();
    } catch (e) {
      print('Error deleting journal entry: $e');
    }
  }

  // Basculer le mode sombre
  Future<void> toggleDarkMode() async {
    _darkMode = !_darkMode;
    try {
      await _dbHelper.setPreference('darkMode', _darkMode.toString());
      notifyListeners();
    } catch (e) {
      print('Error toggling dark mode: $e');
    }
  }

  // Statistiques
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

  int get checkInDays => _moodEntries.length;

  Future<List<MoodEntry>> getLastWeekEntries() async {
    return await _dbHelper.getMoodsLast7Days();
  }
}

// ==============================================
// 4. THÈME ET COULEURS ATTRACTIVES
// ==============================================

class AppColors {
  // Nouvelle palette de couleurs plus attrayante
  static const Color primary = Color(0xFF7B9DFF);
  static const Color secondary = Color(0xFF9FD8FF);
  static const Color accent = Color(0xFFFFE7A0);
  static const Color background = Color(0xFFF0F7FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF2C3E50);
  static const Color textLight = Color(0xFF7F8C8D);

  // Couleurs pour les éléments spéciaux
  static const Color gradientStart = Color(0xFFA8E6CF);
  static const Color gradientEnd = Color(0xFFDCEDC1);
  static const Color success = Color(0xFF4CD964);
  static const Color warning = Color(0xFFFF9500);
  static const Color info = Color(0xFF5AC8FA);
  static const Color love = Color(0xFFFF6B8B);

  // Mode sombre avec couleurs harmonieuses
  static const Color darkPrimary = Color(0xFF8A8AFF);
  static const Color darkSecondary = Color(0xFFA6B5FF);
  static const Color darkAccent = Color(0xFFFFD166);
  static const Color darkBackground = Color(0xFF121826);
  static const Color darkSurface = Color(0xFF1E2438); // Correction de la casse
  static const Color darkText = Color(0xFFE8F4F8);
  static const Color darkTextLight = Color(0xFFB0BEC5);

  // Couleurs par humeur - plus vibrantes
  static Map<MoodType, Color> get moodColors => {
    MoodType.happy: const Color(0xFFFFD166),
    MoodType.calm: const Color(0xFF7B9DFF),
    MoodType.neutral: const Color(0xFF95A5A6),
    MoodType.sad: const Color(0xFF3498DB),
    MoodType.stressed: const Color(0xFFFF6B8B),
  };

  // Gradients pour différentes parties de l'app
  static LinearGradient get mainGradient => LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get cardGradient => LinearGradient(
    colors: [surface.withOpacity(0.9), accent.withOpacity(0.1)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get buttonGradient => LinearGradient(
    colors: [primary, Color(0xFF5D7FFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

// ==============================================
// 5. ÉCRAN SPLASH
// ==============================================

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.mainGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.white.withOpacity(0.9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Icon(
                    Icons.psychology_outlined,
                    size: 60,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'SafeSpace',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  fontFamily: 'Inter',
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Prenez soin de votre esprit',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.text.withOpacity(0.8),
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 50),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
              const SizedBox(height: 30),
              Text(
                'Chargement...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.text.withOpacity(0.6),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================
// 6. WIDGETS DE BASE
// ==============================================

class MoodSelector extends StatefulWidget {
  final Function(MoodType, String?) onMoodSelected;
  final MoodType? initialMood;
  final String? initialNote;

  const MoodSelector({
    super.key,
    required this.onMoodSelected,
    this.initialMood,
    this.initialNote,
  });

  @override
  State<MoodSelector> createState() => _MoodSelectorState();
}

class _MoodSelectorState extends State<MoodSelector> {
  final TextEditingController _noteController = TextEditingController();
  MoodType? _selectedMood;

  @override
  void initState() {
    super.initState();
    _selectedMood = widget.initialMood;
    if (widget.initialNote != null && widget.initialNote!.isNotEmpty) {
      _noteController.text = widget.initialNote!;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final moodTypes = MoodType.values;

    return Column(
      children: [
        // Sélection d'humeur
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: moodTypes.length,
          itemBuilder: (context, index) {
            final mood = moodTypes[index];
            return _buildMoodButton(mood, colors);
          },
        ),

        const SizedBox(height: 32),

        // Note optionnelle
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            hintText: 'Ajouter une petite note (optionnel)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.all(20),
            filled: true,
            fillColor: colors.surface,
          ),
          maxLines: 4,
          style: TextStyle(
            fontSize: 16,
            color: colors.onBackground,
            fontFamily: 'Inter',
          ),
        ),

        const SizedBox(height: 24),

        // Bouton de validation
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _selectedMood != null ? _saveMood : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              widget.initialMood != null
                  ? 'Mettre à jour'
                  : 'Enregistrer mon état',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodButton(MoodType mood, ColorScheme colors) {
    final isSelected = _selectedMood == mood;
    final moodColor = AppColors.moodColors[mood]!;

    return GestureDetector(
      onTap: () => setState(() => _selectedMood = mood),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [moodColor, moodColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : moodColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? moodColor : colors.outline.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: moodColor.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getMoodIcon(mood),
              size: 36,
              color: isSelected ? Colors.white : moodColor,
            ),
            const SizedBox(height: 8),
            Text(
              _getMoodLabel(mood),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : colors.onBackground,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveMood() {
    widget.onMoodSelected(
      _selectedMood!,
      _noteController.text.isNotEmpty ? _noteController.text : null,
    );

    _noteController.clear();
    setState(() => _selectedMood = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              widget.initialMood != null
                  ? 'Humeur mise à jour 💙'
                  : 'Merci d\'avoir pris ce moment pour toi 💙',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  IconData _getMoodIcon(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return Icons.sentiment_very_satisfied;
      case MoodType.calm:
        return Icons.sentiment_satisfied;
      case MoodType.neutral:
        return Icons.sentiment_neutral;
      case MoodType.sad:
        return Icons.sentiment_dissatisfied;
      case MoodType.stressed:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  String _getMoodLabel(MoodType mood) {
    switch (mood) {
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
}

// ==============================================
// 7. ÉCRAN D'ACCUEIL
// ==============================================

class HomeScreen extends StatefulWidget {
  final AppState appState;
  final Function(int) onNavigate;

  const HomeScreen({
    super.key,
    required this.appState,
    required this.onNavigate,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentAffirmation = '';

  @override
  void initState() {
    super.initState();
    _currentAffirmation = widget.appState.getRandomAffirmation();
    widget.appState.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    setState(() {});
  }

  void _updateMood() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Modifier mon humeur',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 20),
              MoodSelector(
                onMoodSelected: (mood, note) {
                  final entry = MoodEntry(
                    mood: mood,
                    date: DateTime.now(),
                    note: note,
                    intensity: 0.5,
                  );
                  widget.appState.updateTodaysMood(entry);
                  Navigator.pop(context);
                },
                initialMood: widget.appState.todaysMood?.mood,
                initialNote: widget.appState.todaysMood?.note,
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final todaysMood = widget.appState.todaysMood;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec icône
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: AppColors.buttonGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.psychology_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour 👋',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.onBackground,
                                  fontFamily: 'Inter',
                                ),
                          ),
                          Text(
                            'Comment te sens-tu aujourd\'hui ?',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.onBackground.withOpacity(0.7),
                                  fontFamily: 'Inter',
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Check-in du jour
                if (todaysMood == null)
                  _buildDailyCheckIn(colors)
                else
                  _buildTodaySummary(todaysMood, colors),

                const SizedBox(height: 32),

                // Message positif
                _buildPositiveMessage(_currentAffirmation, colors),

                const SizedBox(height: 32),

                // Accès rapide aux autres fonctionnalités
                _buildQuickAccess(),

                const SizedBox(height: 32),

                // Note éthique
                _buildEthicalNote(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyCheckIn(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primaryContainer ?? AppColors.primary.withOpacity(0.1),
            colors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_emotions_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Check-in quotidien',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.onBackground,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            MoodSelector(
              onMoodSelected: (mood, note) {
                final entry = MoodEntry(
                  mood: mood,
                  date: DateTime.now(),
                  note: note,
                  intensity: 0.5,
                );
                widget.appState.addMoodEntry(entry);
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Prends un moment pour toi, c\'est important 💫',
              style: TextStyle(
                fontSize: 14,
                color: colors.onBackground.withOpacity(0.6),
                fontStyle: FontStyle.italic,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySummary(MoodEntry mood, ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.moodColors[mood.mood]!.withOpacity(0.2),
            colors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.moodColors[mood.mood]!.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.moodColors[mood.mood]!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      _getMoodIcon(mood.mood),
                      size: 36,
                      color: AppColors.moodColors[mood.mood],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aujourd\'hui',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onBackground.withOpacity(0.7),
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        _getMoodText(mood.mood),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: colors.onBackground,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        'Check-in enregistré ✅',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (mood.note != null && mood.note!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.primary.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.note_alt_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        mood.note!,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onBackground,
                          fontFamily: 'Inter',
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _updateMood,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.surface,
                foregroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: colors.primary.withOpacity(0.3)),
              ),
              child: const Text(
                'Modifier mon humeur',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositiveMessage(String affirmation, ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.3),
            AppColors.secondary.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.love.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppColors.love,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Petit rappel du jour 💭',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.onBackground,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              affirmation,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: colors.onBackground,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentAffirmation = widget.appState
                          .getRandomAffirmation();
                    });
                  },
                  icon: Icon(Icons.refresh, color: AppColors.primary),
                  tooltip: 'Nouveau message',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccess() {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Accès rapide',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.onBackground,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildQuickAccessItem(
              Icons.book_outlined,
              'Journal',
              AppColors.info,
              () => widget.onNavigate(1),
            ),
            _buildQuickAccessItem(
              Icons.self_improvement_outlined,
              'Respiration',
              AppColors.secondary,
              () => widget.onNavigate(2),
            ),
            _buildQuickAccessItem(
              Icons.insights_outlined,
              'Statistiques',
              AppColors.success,
              () => widget.onNavigate(3),
            ),
            _buildQuickAccessItem(
              Icons.help_outline,
              'Aide & Urgences',
              AppColors.warning,
              () => _showEmergencyDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(child: Icon(icon, color: color, size: 28)),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEthicalNote(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.error.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: colors.error.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Important',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.error,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '⚠️ Cette application ne remplace pas un professionnel de santé. '
            'En cas de besoin urgent, contactez le 3114.',
            style: TextStyle(
              fontSize: 12,
              color: colors.onBackground.withOpacity(0.7),
              fontStyle: FontStyle.italic,
              fontFamily: 'Inter',
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Numéros d\'urgence',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEmergencyNumber('3114', 'Prévention du suicide'),
            const SizedBox(height: 16),
            _buildEmergencyNumber('15', 'SAMU'),
            const SizedBox(height: 16),
            _buildEmergencyNumber('112', 'Urgences européennes'),
            const SizedBox(height: 20),
            Text(
              'Ces services sont disponibles 24h/24 et 7j/7.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.6),
                fontFamily: 'Inter',
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fermer',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyNumber(String number, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.red,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  IconData _getMoodIcon(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return Icons.sentiment_very_satisfied;
      case MoodType.calm:
        return Icons.sentiment_satisfied;
      case MoodType.neutral:
        return Icons.sentiment_neutral;
      case MoodType.sad:
        return Icons.sentiment_dissatisfied;
      case MoodType.stressed:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  String _getMoodText(MoodType mood) {
    switch (mood) {
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

// ==============================================
// 8. ÉCRAN DE JOURNAL
// ==============================================

class JournalScreen extends StatefulWidget {
  final AppState appState;

  const JournalScreen({super.key, required this.appState});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final TextEditingController _journalController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_refresh);
    _journalController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _saveEntry() {
    if (_journalController.text.trim().isNotEmpty) {
      final entry = JournalEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        content: _journalController.text.trim(),
        mood: widget.appState.todaysMood?.mood,
      );

      widget.appState.addJournalEntry(entry);
      _journalController.clear();
      _focusNode.unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Entrée sauvegardée 📝',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _deleteEntry(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Supprimer cette entrée ?',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        content: const Text(
          'Cette action ne peut pas être annulée.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(fontFamily: 'Inter')),
          ),
          TextButton(
            onPressed: () {
              widget.appState.deleteJournalEntry(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entrée supprimée'),
                  backgroundColor: AppColors.love,
                ),
              );
            },
            child: const Text(
              'Supprimer',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = widget.appState.journalEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Journal personnel',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_journalController.text.isNotEmpty)
            IconButton(
              onPressed: _saveEntry,
              icon: const Icon(Icons.save),
              tooltip: 'Sauvegarder',
            ),
        ],
      ),
      body: Column(
        children: [
          // Zone d'écriture
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                bottom: BorderSide(color: colors.outline.withOpacity(0.3)),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _journalController,
              focusNode: _focusNode,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Écrivez vos pensées ici...',
                hintStyle: TextStyle(
                  color: colors.onBackground.withOpacity(0.5),
                  fontFamily: 'Inter',
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: TextStyle(
                fontSize: 16,
                color: colors.onBackground,
                fontFamily: 'Inter',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Liste des entrées
          Expanded(
            child: entries.isEmpty
                ? _buildEmptyState(colors)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries.reversed.toList()[index];
                      return _buildJournalEntry(entry, colors);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _journalController.text.isNotEmpty
          ? FloatingActionButton(
              onPressed: _saveEntry,
              child: const Icon(Icons.save),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 80,
            color: colors.onBackground.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Votre journal est vide',
            style: TextStyle(
              fontSize: 20,
              color: colors.onBackground.withOpacity(0.5),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez à écrire vos pensées...',
            style: TextStyle(
              fontSize: 14,
              color: colors.onBackground.withOpacity(0.4),
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalEntry(JournalEntry entry, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(entry.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onBackground.withOpacity(0.6),
                    fontFamily: 'Inter',
                  ),
                ),
                if (entry.mood != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.moodColors[entry.mood!]!.withOpacity(
                        0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getMoodIcon(entry.mood!),
                          color: AppColors.moodColors[entry.mood!],
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getMoodLabel(entry.mood!),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.moodColors[entry.mood!],
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.content,
              style: TextStyle(
                fontSize: 14,
                color: colors.onBackground,
                height: 1.6,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: colors.onBackground.withOpacity(0.5),
                ),
                onPressed: () => _deleteEntry(entry.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(date.year, date.month, date.day);

    if (entryDay == today) {
      return 'Aujourd\'hui, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (entryDay == today.subtract(const Duration(days: 1))) {
      return 'Hier, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  IconData _getMoodIcon(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return Icons.sentiment_very_satisfied;
      case MoodType.calm:
        return Icons.sentiment_satisfied;
      case MoodType.neutral:
        return Icons.sentiment_neutral;
      case MoodType.sad:
        return Icons.sentiment_dissatisfied;
      case MoodType.stressed:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  String _getMoodLabel(MoodType mood) {
    switch (mood) {
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
}

// ==============================================
// 9. ÉCRAN DE RESPIRATION
// ==============================================

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final int _inhaleTime = 4;
  final int _holdTime = 4;
  final int _exhaleTime = 4;

  int _currentTime = 0;
  String _currentPhase = 'Inspirez';
  Timer? _timer;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startBreathing() {
    if (_isRunning) {
      _timer?.cancel();
      _isRunning = false;
      _currentTime = 0;
      _currentPhase = 'Inspirez';
      _controller.reverse();
      setState(() {});
      return;
    }

    _isRunning = true;
    _currentTime = 0;
    _currentPhase = 'Inspirez';
    _controller.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime++;

        if (_currentTime <= _inhaleTime) {
          _currentPhase = 'Inspirez';
          if (_currentTime == _inhaleTime) {
            _controller.reverse();
          }
        } else if (_currentTime <= _inhaleTime + _holdTime) {
          _currentPhase = 'Retenez';
        } else if (_currentTime <= _inhaleTime + _holdTime + _exhaleTime) {
          _currentPhase = 'Expirez';
          if (_currentTime == _inhaleTime + _holdTime + 1) {
            _controller.forward();
          }
        } else {
          _currentTime = 0;
          _currentPhase = 'Inspirez';
          _controller.forward();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Respiration calme',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              AppColors.secondary.withOpacity(0.3),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animation de cercle
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Container(
                      width: 250 * _animation.value,
                      height: 250 * _animation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.4),
                            AppColors.primary.withOpacity(0.1),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.8),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentPhase,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: colors.onBackground,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 48),

                // Instructions
                Text(
                  '4-4-4',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    fontFamily: 'Inter',
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inspirez • Retenez • Expirez',
                  style: TextStyle(
                    fontSize: 18,
                    color: colors.onBackground.withOpacity(0.8),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 48),

                // Timer
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$_currentTime s',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Bouton de contrôle
                Container(
                  width: 200,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _startBreathing,
                    icon: Icon(
                      _isRunning ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                    label: Text(
                      _isRunning ? 'Pause' : 'Commencer',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Conseils
                Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withOpacity(0.2),
                        AppColors.accent.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: AppColors.accent,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Conseils',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Trouvez un endroit calme\n'
                        '• Asseyez-vous confortablement\n'
                        '• Fermez les yeux si vous le souhaitez\n'
                        '• Suivez le rythme naturellement\n'
                        '• Répétez 5 à 10 cycles',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.8,
                          color: colors.onBackground.withOpacity(0.8),
                          fontFamily: 'Inter',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================
// 10. ÉCRAN DE STATISTIQUES
// ==============================================

class StatsScreen extends StatefulWidget {
  final AppState appState;

  const StatsScreen({super.key, required this.appState});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<MoodType, int> _moodFrequency = {};
  List<MoodEntry> _lastWeekEntries = [];
  MoodType? _mostFrequentMood;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_refresh);
    _loadStatistics();
  }

  @override
  void dispose() {
    widget.appState.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    _moodFrequency = await widget.appState.getMoodFrequency();
    _lastWeekEntries = await widget.appState.getLastWeekEntries();
    _mostFrequentMood = await widget.appState.getMostFrequentMood();
    if (mounted) {
      setState(() {});
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final checkInDays = widget.appState.checkInDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Statistiques',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
      backgroundColor: colors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Résumé
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.secondary.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          'Jours check-in',
                          checkInDays.toString(),
                          Icons.calendar_today,
                          AppColors.primary,
                        ),
                        _buildStatItem(
                          'Humeur dominante',
                          _mostFrequentMood != null
                              ? _getMoodLabel(_mostFrequentMood!)
                              : '-',
                          Icons.insights,
                          AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tu prends soin de toi depuis $checkInDays jours',
                      style: TextStyle(
                        fontSize: 16,
                        color: colors.onBackground.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Fréquence des humeurs
            Text(
              'Fréquence des humeurs',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.onBackground,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.1),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: MoodType.values.map((mood) {
                    final count = _moodFrequency[mood] ?? 0;
                    final total = checkInDays == 0 ? 1 : checkInDays;
                    final percentage = (count / total * 100).toInt();

                    return _buildMoodFrequencyRow(
                      mood,
                      count,
                      percentage,
                      colors,
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Dernière semaine
            Text(
              'Dernière semaine',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.onBackground,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 16),
            _lastWeekEntries.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.bar_chart_outlined,
                          size: 64,
                          color: colors.onBackground.withOpacity(0.3),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Pas assez de données',
                          style: TextStyle(
                            fontSize: 18,
                            color: colors.onBackground.withOpacity(0.5),
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Revenez après quelques check-in',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.onBackground.withOpacity(0.4),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withOpacity(0.1),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: _lastWeekEntries.reversed.map((entry) {
                          return _buildWeekEntry(entry, colors);
                        }).toList(),
                      ),
                    ),
                  ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(child: Icon(icon, color: color, size: 30)),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onBackground,
            fontFamily: 'Inter',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMoodFrequencyRow(
    MoodType mood,
    int count,
    int percentage,
    ColorScheme colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.moodColors[mood]!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                _getMoodIcon(mood),
                color: AppColors.moodColors[mood],
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _getMoodLabel(mood),
              style: TextStyle(
                fontSize: 16,
                color: colors.onBackground,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.onBackground,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 120,
            height: 8,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.moodColors[mood]!,
                      AppColors.moodColors[mood]!.withOpacity(0.7),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 12,
              color: colors.onBackground.withOpacity(0.6),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekEntry(MoodEntry entry, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            alignment: Alignment.center,
            child: Text(
              _getDayName(entry.date.weekday),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.onBackground.withOpacity(0.8),
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.moodColors[entry.mood]!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                _getMoodIcon(entry.mood),
                color: AppColors.moodColors[entry.mood],
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getMoodLabel(entry.mood),
              style: TextStyle(
                fontSize: 16,
                color: colors.onBackground,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${entry.date.day.toString().padLeft(2, '0')}/${entry.date.month.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 12,
              color: colors.onBackground.withOpacity(0.6),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Lun';
      case 2:
        return 'Mar';
      case 3:
        return 'Mer';
      case 4:
        return 'Jeu';
      case 5:
        return 'Ven';
      case 6:
        return 'Sam';
      case 7:
        return 'Dim';
      default:
        return '';
    }
  }

  String _getMoodLabel(MoodType mood) {
    switch (mood) {
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

  IconData _getMoodIcon(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return Icons.sentiment_very_satisfied;
      case MoodType.calm:
        return Icons.sentiment_satisfied;
      case MoodType.neutral:
        return Icons.sentiment_neutral;
      case MoodType.sad:
        return Icons.sentiment_dissatisfied;
      case MoodType.stressed:
        return Icons.sentiment_very_dissatisfied;
    }
  }
}

// ==============================================
// 11. ÉCRAN DE PARAMÈTRES
// ==============================================

class SettingsScreen extends StatelessWidget {
  final AppState appState;
  final VoidCallback onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.appState,
    required this.onThemeChanged,
  });

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Numéros d\'urgence',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEmergencyNumber(context, '3114', 'Prévention du suicide'),
            const SizedBox(height: 16),
            _buildEmergencyNumber(context, '15', 'SAMU'),
            const SizedBox(height: 16),
            _buildEmergencyNumber(context, '112', 'Urgences européennes'),
            const SizedBox(height: 20),
            Text(
              'Ces services sont disponibles 24h/24 et 7j/7.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onBackground.withOpacity(0.6),
                fontFamily: 'Inter',
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fermer',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyNumber(
    BuildContext context,
    String number,
    String description,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.red,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Paramètres',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
      backgroundColor: colors.background,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Section Personnalisation
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Personnalisation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: Text(
                      'Mode sombre',
                      style: TextStyle(
                        color: colors.onBackground,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Passer en thème sombre',
                      style: TextStyle(
                        color: colors.onBackground.withOpacity(0.6),
                        fontFamily: 'Inter',
                      ),
                    ),
                    value: appState.darkMode,
                    onChanged: (value) {
                      appState.toggleDarkMode();
                      onThemeChanged();
                    },
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: appState.darkMode
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          appState.darkMode
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: appState.darkMode
                              ? AppColors.primary
                              : AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section À propos
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'À propos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(Icons.info_outline, color: AppColors.info),
                      ),
                    ),
                    title: Text(
                      'Version',
                      style: TextStyle(
                        color: colors.onBackground,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      '1.0.0',
                      style: TextStyle(fontFamily: 'Inter'),
                    ),
                  ),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.privacy_tip_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      'Confidentialité',
                      style: TextStyle(
                        color: colors.onBackground,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'Toutes les données sont stockées localement',
                      style: TextStyle(fontFamily: 'Inter'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section Ressources
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: AppColors.warning,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Ressources',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.love.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.phone_in_talk_outlined,
                          color: AppColors.love,
                        ),
                      ),
                    ),
                    title: Text(
                      'Aide immédiate',
                      style: TextStyle(
                        color: colors.onBackground,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      '3114 - Numéro national de prévention du suicide',
                      style: TextStyle(fontFamily: 'Inter'),
                    ),
                    onTap: () => _showEmergencyDialog(context),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Avertissement éthique
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.error.withOpacity(0.1),
                  colors.error.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.error.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colors.error.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: colors.error,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Avertissement important',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.error,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cette application ne remplace pas un professionnel de santé. '
                  'En cas de détresse psychologique, consultez immédiatement un médecin ou un psychologue.',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onBackground.withOpacity(0.8),
                    fontFamily: 'Inter',
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ==============================================
// 12. NAVIGATION PRINCIPALE
// ==============================================

class MainNavigation extends StatefulWidget {
  final AppState appState;

  const MainNavigation({super.key, required this.appState});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await widget.appState.loadData();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onNavigateFromHome(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getScreen(_selectedIndex),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          appState: widget.appState,
          onNavigate: _onNavigateFromHome,
        );
      case 1:
        return JournalScreen(appState: widget.appState);
      case 2:
        return const BreathingScreen();
      case 3:
        return StatsScreen(appState: widget.appState);
      case 4:
        return SettingsScreen(
          appState: widget.appState,
          onThemeChanged: () => setState(() {}),
        );
      default:
        return HomeScreen(
          appState: widget.appState,
          onNavigate: _onNavigateFromHome,
        );
    }
  }

  Widget _buildBottomNavigationBar() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: colors.onBackground.withOpacity(0.6),
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontFamily: 'Inter',
        ),
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedIndex == 0
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.home_outlined,
                size: _selectedIndex == 0 ? 26 : 24,
              ),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.home, size: 26),
            ),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedIndex == 1
                    ? AppColors.info.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.book_outlined,
                size: _selectedIndex == 1 ? 26 : 24,
              ),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.book, size: 26),
            ),
            label: 'Journal',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedIndex == 2
                    ? AppColors.secondary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.self_improvement_outlined,
                size: _selectedIndex == 2 ? 26 : 24,
              ),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.self_improvement, size: 26),
            ),
            label: 'Respiration',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedIndex == 3
                    ? AppColors.success.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.insights_outlined,
                size: _selectedIndex == 3 ? 26 : 24,
              ),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.insights, size: 26),
            ),
            label: 'Statistiques',
          ),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _selectedIndex == 4
                    ? AppColors.accent.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings_outlined,
                size: _selectedIndex == 4 ? 26 : 24,
              ),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings, size: 26),
            ),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}

// ==============================================
// 13. APPLICATION PRINCIPALE
// ==============================================

class SafeSpaceApp extends StatefulWidget {
  const SafeSpaceApp({super.key});

  @override
  State<SafeSpaceApp> createState() => _SafeSpaceAppState();
}

class _SafeSpaceAppState extends State<SafeSpaceApp> {
  late AppState _appState;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialisation de la base de données
      final dbHelper = DatabaseHelper();
      await dbHelper.database; // Force l'initialisation

      await Future.delayed(const Duration(seconds: 2));
      await _appState.loadData();
    } catch (e) {
      print('Error initializing app: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeSpace',
      themeMode: _appState.darkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: _isLoading
          ? const SplashScreen()
          : AnimatedSplashScreen(
              splash: const SplashScreen(),
              nextScreen: MainNavigation(appState: _appState),
              splashIconSize: 250,
              duration: 3000,
              splashTransition: SplashTransition.fadeTransition,
              pageTransitionType: PageTransitionType.fade,
              backgroundColor: AppColors.background,
            ),
    );
  }
}
