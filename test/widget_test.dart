// ==============================================
// SAFESPACE - Application Flutter Complète
// Version avec Splash Screen et couleurs attrayantes
// ==============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:page_transition/page_transition.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Hive pour le stockage local
  await Hive.initFlutter();
  Hive.registerAdapter(MoodEntryAdapter());
  Hive.registerAdapter(MoodTypeAdapter());

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

@HiveType(typeId: 0)
enum MoodType {
  @HiveField(0)
  happy,
  @HiveField(1)
  calm,
  @HiveField(2)
  neutral,
  @HiveField(3)
  sad,
  @HiveField(4)
  stressed,
}

@HiveType(typeId: 1)
class MoodEntry {
  @HiveField(0)
  final MoodType mood;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final String? note;

  @HiveField(3)
  final double? intensity;

  MoodEntry({
    required this.mood,
    required this.date,
    this.note,
    this.intensity,
  });
}

@HiveType(typeId: 2)
class JournalEntry {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final MoodType? mood;

  JournalEntry({
    required this.id,
    required this.date,
    required this.content,
    this.mood,
  });
}

// Adapters Hive
class MoodTypeAdapter extends TypeAdapter<MoodType> {
  @override
  final typeId = 0;

  @override
  MoodType read(BinaryReader reader) {
    return MoodType.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, MoodType obj) {
    writer.writeByte(obj.index);
  }
}

class MoodEntryAdapter extends TypeAdapter<MoodEntry> {
  @override
  final typeId = 1;

  @override
  MoodEntry read(BinaryReader reader) {
    return MoodEntry(
      mood: MoodType.values[reader.readByte()],
      date: DateTime.parse(reader.readString()),
      note: reader.readString(),
      intensity: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, MoodEntry obj) {
    writer.writeByte(obj.mood.index);
    writer.writeString(obj.date.toIso8601String());
    writer.writeString(obj.note ?? '');
    writer.writeDouble(obj.intensity ?? 0.5);
  }
}

// ==============================================
// 2. GESTION D'ÉTAT
// ==============================================

class AppState extends ChangeNotifier {
  List<MoodEntry> _moodEntries = [];
  List<JournalEntry> _journalEntries = [];
  bool _darkMode = false;

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

  String get todaysAffirmation {
    final now = DateTime.now();
    final index = now.day % _affirmations.length;
    return _affirmations[index];
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

  // Charger les données depuis Hive
  Future<void> loadData() async {
    final moodBox = await Hive.openBox<MoodEntry>('moods');
    final journalBox = await Hive.openBox<JournalEntry>('journal');

    _moodEntries = moodBox.values.toList();
    _journalEntries = journalBox.values.toList();

    // Charger le thème
    final prefsBox = await Hive.openBox('preferences');
    _darkMode = prefsBox.get('darkMode', defaultValue: false);

    notifyListeners();
  }

  // Ajouter une humeur
  Future<void> addMoodEntry(MoodEntry entry) async {
    final box = await Hive.openBox<MoodEntry>('moods');
    await box.put(entry.date.toIso8601String(), entry);
    _moodEntries = box.values.toList();
    notifyListeners();
  }

  // Ajouter une entrée de journal
  Future<void> addJournalEntry(JournalEntry entry) async {
    final box = await Hive.openBox<JournalEntry>('journal');
    await box.put(entry.id, entry);
    _journalEntries = box.values.toList();
    notifyListeners();
  }

  // Supprimer une entrée de journal
  Future<void> deleteJournalEntry(String id) async {
    final box = await Hive.openBox<JournalEntry>('journal');
    await box.delete(id);
    _journalEntries = box.values.toList();
    notifyListeners();
  }

  // Basculer le mode sombre
  Future<void> toggleDarkMode() async {
    _darkMode = !_darkMode;
    final box = await Hive.openBox('preferences');
    await box.put('darkMode', _darkMode);
    notifyListeners();
  }

  // Statistiques
  Map<MoodType, int> getMoodFrequency() {
    final frequency = <MoodType, int>{};
    for (var mood in MoodType.values) {
      frequency[mood] = _moodEntries.where((e) => e.mood == mood).length;
    }
    return frequency;
  }

  MoodType? getMostFrequentMood() {
    final frequency = getMoodFrequency();
    if (frequency.isEmpty) return null;
    return frequency.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  int get checkInDays => _moodEntries.length;

  List<MoodEntry> getLastWeekEntries() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _moodEntries.where((e) => e.date.isAfter(weekAgo)).toList();
  }
}

// ==============================================
// 3. THÈME ET COULEURS ATTRACTIVES
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
  static const Color darkSurface = Color(0xFF1E2438);
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

ThemeData getLightTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      background: AppColors.background,
      surface: AppColors.surface,
      onBackground: AppColors.text,
      onSurface: AppColors.text,
      error: Colors.red,
      primaryContainer: AppColors.primary.withOpacity(0.1),
    ),
    fontFamily: 'Inter',
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
      iconTheme: IconThemeData(color: AppColors.primary),
    ),
    cardTheme: ThemeData.light().cardTheme.copyWith(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.surface,
      shadowColor: AppColors.primary.withOpacity(0.2),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
        elevation: 2,
        shadowColor: AppColors.primary.withOpacity(0.3),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: AppColors.textLight),
      labelStyle: TextStyle(color: AppColors.text),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
        fontFamily: 'Inter',
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
        fontFamily: 'Inter',
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.text,
        fontFamily: 'Inter',
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.text,
        fontFamily: 'Inter',
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        fontFamily: 'Inter',
      ),
    ),
  );
}

ThemeData getDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.darkPrimary,
      secondary: AppColors.darkSecondary,
      background: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      onBackground: AppColors.darkText,
      onSurface: AppColors.darkText,
      primaryContainer: AppColors.darkPrimary.withOpacity(0.2),
    ),
    fontFamily: 'Inter',
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.darkText,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
      iconTheme: IconThemeData(color: AppColors.darkPrimary),
    ),
    cardTheme: ThemeData.dark().cardTheme.copyWith(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.darkSurface,
      shadowColor: Colors.black.withOpacity(0.4),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.darkPrimary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
        elevation: 3,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface.withOpacity(0.8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.darkPrimary.withOpacity(0.4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.darkPrimary.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.darkPrimary, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: AppColors.darkTextLight),
      labelStyle: TextStyle(color: AppColors.darkText),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
        fontFamily: 'Inter',
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
        fontFamily: 'Inter',
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.darkText,
        fontFamily: 'Inter',
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.darkText,
        fontFamily: 'Inter',
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        fontFamily: 'Inter',
      ),
    ),
  );
}

// ==============================================
// 4. ÉCRAN SPLASH
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
              // Utilisez votre icône t.png ici
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
                  child: Image.asset(
                    'assets/icon.png', // Votre icône t.png
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(height: 30),
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
              SizedBox(height: 10),
              Text(
                'Prenez soin de votre esprit',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.text.withOpacity(0.8),
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 50),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
              SizedBox(height: 30),
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
// 5. WIDGETS DE BASE
// ==============================================

class MoodSelector extends StatefulWidget {
  final Function(MoodType, String?) onMoodSelected;

  const MoodSelector({super.key, required this.onMoodSelected});

  @override
  State<MoodSelector> createState() => _MoodSelectorState();
}

class _MoodSelectorState extends State<MoodSelector> {
  final TextEditingController _noteController = TextEditingController();
  MoodType? _selectedMood;

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
                offset: Offset(0, 4),
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
              'Enregistrer mon état',
              style: TextStyle(
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
        duration: Duration(milliseconds: 300),
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
            Icon(Icons.favorite, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'Merci d\'avoir pris ce moment pour toi 💙',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 3),
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
// 6. ÉCRAN D'ACCUEIL
// ==============================================

class HomeScreen extends StatefulWidget {
  final AppState appState;

  const HomeScreen({super.key, required this.appState});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final todaysMood = widget.appState.todaysMood;
    final affirmation = widget.appState.todaysAffirmation;

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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/icon.png',
                          fit: BoxFit.contain,
                          width: 30,
                          height: 30,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
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
                _buildPositiveMessage(affirmation, colors),

                const SizedBox(height: 32),

                // Accès rapide aux autres fonctionnalités
                _buildQuickAccess(context),

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
                SizedBox(width: 12),
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
                SizedBox(width: 16),
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
                    SizedBox(width: 12),
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
              onPressed: () {
                // Permettre de changer l'humeur
                widget.appState.notifyListeners();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.surface,
                foregroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: colors.primary.withOpacity(0.3)),
              ),
              child: Text(
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
                SizedBox(width: 12),
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
                    // Nouvelle affirmation
                    widget.appState.notifyListeners();
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

  Widget _buildQuickAccess(BuildContext context) {
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
        SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _buildQuickAccessItem(
              context,
              Icons.book_outlined,
              'Journal',
              AppColors.info,
              () {
                // Naviguer vers le journal
                // Dans la navigation principale, cela sera géré
              },
            ),
            _buildQuickAccessItem(
              context,
              Icons.self_improvement_outlined,
              'Respiration',
              AppColors.secondary,
              () {
                // Naviguer vers la respiration
              },
            ),
            _buildQuickAccessItem(
              context,
              Icons.insights_outlined,
              'Statistiques',
              AppColors.success,
              () {
                // Naviguer vers les statistiques
              },
            ),
            _buildQuickAccessItem(
              context,
              Icons.help_outline,
              'Aide',
              AppColors.warning,
              () {
                // Naviguer vers l'aide
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessItem(
    BuildContext context,
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
            SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
                fontFamily: 'Inter',
              ),
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
              SizedBox(width: 8),
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
          SizedBox(height: 12),
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
// 7. ÉCRAN DE JOURNAL (Simplifié pour l'espace)
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
    setState(() {});
  }

  void _saveEntry() {
    if (_journalController.text.trim().isNotEmpty) {
      final entry = JournalEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        content: _journalController.text,
        mood: widget.appState.todaysMood?.mood,
      );

      widget.appState.addJournalEntry(entry);
      _journalController.clear();
      _focusNode.unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
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
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _deleteEntry(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Supprimer cette entrée ?',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        content: Text(
          'Cette action ne peut pas être annulée.',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(fontFamily: 'Inter')),
          ),
          TextButton(
            onPressed: () {
              widget.appState.deleteJournalEntry(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Entrée supprimée'),
                  backgroundColor: AppColors.love,
                ),
              );
            },
            child: Text(
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
        title: Text(
          'Journal personnel',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_journalController.text.isNotEmpty)
            IconButton(onPressed: _saveEntry, icon: Icon(Icons.save)),
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
                  offset: Offset(0, 2),
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
              child: Icon(Icons.save),
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
          SizedBox(height: 20),
          Text(
            'Votre journal est vide',
            style: TextStyle(
              fontSize: 20,
              color: colors.onBackground.withOpacity(0.5),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
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
            offset: Offset(0, 2),
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
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.moodColors[entry.mood]!.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getMoodIcon(entry.mood!),
                          color: AppColors.moodColors[entry.mood],
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _getMoodLabel(entry.mood!),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.moodColors[entry.mood],
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              entry.content,
              style: TextStyle(
                fontSize: 14,
                color: colors.onBackground,
                height: 1.6,
                fontFamily: 'Inter',
              ),
            ),
            SizedBox(height: 12),
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
// 8. ÉCRAN DE RESPIRATION (Simplifié)
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
        title: Text(
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
            padding: EdgeInsets.all(20),
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
                          stops: [0.5, 1.0],
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

                SizedBox(height: 48),

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
                SizedBox(height: 8),
                Text(
                  'Inspirez • Retenez • Expirez',
                  style: TextStyle(
                    fontSize: 18,
                    color: colors.onBackground.withOpacity(0.8),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),

                SizedBox(height: 48),

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

                SizedBox(height: 40),

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
                        offset: Offset(0, 5),
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
                      style: TextStyle(
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

                SizedBox(height: 40),

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
                      SizedBox(height: 12),
                      Text(
                        'Conseils',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.onBackground,
                          fontFamily: 'Inter',
                        ),
                      ),
                      SizedBox(height: 12),
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
// 9. ÉCRAN DE STATISTIQUES (Simplifié)
// ==============================================

class StatsScreen extends StatefulWidget {
  final AppState appState;

  const StatsScreen({super.key, required this.appState});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final checkInDays = widget.appState.checkInDays;
    final mostFrequentMood = widget.appState.getMostFrequentMood();
    final frequency = widget.appState.getMoodFrequency();
    final lastWeekEntries = widget.appState.getLastWeekEntries();

    return Scaffold(
      appBar: AppBar(
        title: Text(
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
                          mostFrequentMood != null
                              ? _getMoodLabel(mostFrequentMood!)
                              : '-',
                          Icons.insights,
                          AppColors.success,
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
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

            SizedBox(height: 32),

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
            SizedBox(height: 16),
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
                    final count = frequency[mood] ?? 0;
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

            SizedBox(height: 32),

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
            SizedBox(height: 16),
            lastWeekEntries.isEmpty
                ? Container(
                    padding: EdgeInsets.all(40),
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
                        SizedBox(height: 20),
                        Text(
                          'Pas assez de données',
                          style: TextStyle(
                            fontSize: 18,
                            color: colors.onBackground.withOpacity(0.5),
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
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
                        children: lastWeekEntries.reversed.map((entry) {
                          return _buildWeekEntry(entry, colors);
                        }).toList(),
                      ),
                    ),
                  ),

            SizedBox(height: 40),
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
        SizedBox(height: 12),
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
          SizedBox(width: 16),
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
          SizedBox(width: 12),
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
          SizedBox(width: 12),
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
          SizedBox(width: 12),
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
          SizedBox(width: 12),
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
// 10. ÉCRAN DE PARAMÈTRES (Simplifié)
// ==============================================

class SettingsScreen extends StatelessWidget {
  final AppState appState;
  final VoidCallback onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.appState,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
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
                      SizedBox(width: 12),
                      Text(
                        'Personnalisation',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.onBackground,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
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

          SizedBox(height: 20),

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
                      SizedBox(width: 12),
                      Text(
                        'À propos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.onBackground,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
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
                    subtitle: Text(
                      '1.0.0',
                      style: TextStyle(
                        color: colors.onBackground.withOpacity(0.6),
                        fontFamily: 'Inter',
                      ),
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
                    subtitle: Text(
                      'Toutes les données sont stockées localement',
                      style: TextStyle(
                        color: colors.onBackground.withOpacity(0.6),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

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
                      SizedBox(width: 12),
                      Text(
                        'Ressources',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.onBackground,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
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
                    subtitle: Text(
                      '3114 - Numéro national de prévention du suicide',
                      style: TextStyle(
                        color: colors.onBackground.withOpacity(0.6),
                        fontFamily: 'Inter',
                      ),
                    ),
                    onTap: () => _showEmergencyDialog(context),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

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
                SizedBox(height: 16),
                Text(
                  'Avertissement important',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.error,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 12),
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

          SizedBox(height: 40),
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
            _buildEmergencyNumber(context, '3114', 'Prévention du suicide'),
            SizedBox(height: 16),
            _buildEmergencyNumber(context, '15', 'SAMU'),
            SizedBox(height: 16),
            _buildEmergencyNumber(context, '112', 'Urgences européennes'),
            SizedBox(height: 20),
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
            child: Text(
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
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.red,
            fontFamily: 'Inter',
          ),
        ),
        SizedBox(height: 4),
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
}

// ==============================================
// 11. NAVIGATION PRINCIPALE
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
    widget.appState.loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: _getScreen(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          boxShadow: [
            BoxShadow(
              color: colors.primary.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: colors.onBackground.withOpacity(0.6),
          selectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
          unselectedLabelStyle: TextStyle(fontSize: 11, fontFamily: 'Inter'),
          showUnselectedLabels: true,
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
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
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.home, size: 26),
              ),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
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
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.book, size: 26),
              ),
              label: 'Journal',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
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
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.self_improvement, size: 26),
              ),
              label: 'Respiration',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
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
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.insights, size: 26),
              ),
              label: 'Statistiques',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
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
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.settings, size: 26),
              ),
              label: 'Paramètres',
            ),
          ],
        ),
      ),
    );
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return HomeScreen(appState: widget.appState);
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
        return HomeScreen(appState: widget.appState);
    }
  }
}

// ==============================================
// 12. APPLICATION PRINCIPALE
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
    await Future.delayed(Duration(seconds: 2));
    await _appState.loadData();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeSpace',
      theme: getLightTheme(),
      darkTheme: getDarkTheme(),
      themeMode: _appState.darkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: _isLoading
          ? SplashScreen()
          : AnimatedSplashScreen(
              splash: SplashScreen(),
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
