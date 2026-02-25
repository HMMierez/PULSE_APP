import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:confetti/confetti.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/**
 * PULSE-CORE: Transaction Mode
 * Controls whether the keypad registers an Expense or an Income.
 */
enum TransactionMode { expense, income }

/**
 * PULSE-CORE: Localization Strings
 * Bilingual support: es_ES (default) and en_US.
 * Selected and stored in UserSettings.language.
 */
class AppStrings {
  final String langCode;
  const AppStrings._(this.langCode);

  static const es = AppStrings._('es');
  static const en = AppStrings._('en');

  // ── Home
  String get currentBalance => langCode == 'en' ? 'CURRENT BALANCE' : 'BALANCE ACTUAL';
  String get financialPulse => langCode == 'en' ? 'FINANCIAL PULSE' : 'PULSO FINANCIERO';
  String get expenseMode    => langCode == 'en' ? 'EXPENSE' : 'GASTO';
  String get incomeMode     => langCode == 'en' ? 'INCOME' : 'INGRESO';

  // ── Goals
  String get goals     => langCode == 'en' ? 'GOALS' : 'METAS';
  String get addGoal   => langCode == 'en' ? 'Add goal' : 'Agregar meta';

  // ── Profile
  String get profile        => langCode == 'en' ? 'PROFILE'          : 'PERFIL';
  String get name           => langCode == 'en' ? 'NAME'             : 'NOMBRE';
  String get monthlyBudget  => langCode == 'en' ? 'MONTHLY BUDGET'   : 'PRESUPUESTO MENSUAL';
  String get currency       => langCode == 'en' ? 'CURRENCY'         : 'MONEDA';
  String get language       => langCode == 'en' ? 'LANGUAGE'         : 'IDIOMA';
  String get save           => langCode == 'en' ? 'SAVE'             : 'GUARDAR';
  String get logout         => langCode == 'en' ? 'SIGN OUT'         : 'CERRAR SESIÓN';
  String get profileSaved   => langCode == 'en' ? 'Profile saved ✓'  : 'Perfil guardado ✓';

  // ── Commitments
  String get commitments    => langCode == 'en' ? 'COMMITMENTS'      : 'COMPROMISOS';
  String get addCommitment  => langCode == 'en' ? 'Add commitment'   : 'Agregar compromiso';
  String get noCommitments  => langCode == 'en'
      ? 'No fixed expenses yet.\nAdd your rent, phone, subscriptions…'
      : 'Aún no hay gastos fijos.\nAgregá tu alquiler, teléfono, suscripciones…';

  // ── AI - Invitation mode (no income registered)
  String invitationMode(String name) {
    final n = name.isNotEmpty ? name : (langCode == 'en' ? 'you' : 'vos');
    return langCode == 'en'
        ? '$n, add your salary to unlock your real health score.'
        : '$n, registrá tu sueldo para calcular tu salud real.';
  }
}

/**
 * PULSE-CORE: Weekly Scan Result
 * Container for the Data Scanner output sent to Pulse-Brain.
 * Contains ONLY anonymous/non-sensitive data: amounts, categories, and dates.
 */
class WeeklyScanResult {
  final Map<String, double> byCategory;  // e.g. { "Comida": 200.0, "Transporte": 75.0 }
  final Map<String, double> byDay;       // e.g. { "Martes": 150.0, "Viernes": 125.0 }
  final double totalWeekly;              // Total gastado en 7 días

  const WeeklyScanResult({
    required this.byCategory,
    required this.byDay,
    required this.totalWeekly,
  });

  bool get isEmpty => byCategory.isEmpty;

  @override
  String toString() => 
    'WeeklyScan(total: \$${totalWeekly.toStringAsFixed(0)}, '
    'categorías: $byCategory, '
    'días: $byDay)';
}

/**
 * PULSE-CORE: User Settings Data Model
 * Mirrors the User_Settings Firestore collection.
 */
class UserSettings {
  final String displayName;
  final String currency;
  final double monthlyBudget;
  final bool isPremium;
  final String language; // 'es' | 'en'

  const UserSettings({
    this.displayName = '',
    this.currency = 'ARS',
    this.monthlyBudget = 0,
    this.isPremium = false,
    this.language = 'es',
  });

  factory UserSettings.fromFirestore(Map<String, dynamic> data) {
    return UserSettings(
      displayName:   data['displayName'] ?? '',
      currency:      data['currency'] ?? 'ARS',
      monthlyBudget: (data['monthlyBudget'] as num?)?.toDouble() ?? 0,
      isPremium:     data['isPremium'] ?? false,
      language:      data['language'] ?? 'es',
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName':   displayName,
    'currency':      currency,
    'monthlyBudget': monthlyBudget,
    'isPremium':     isPremium,
    'language':      language,
  };

  bool get hasBudget => monthlyBudget > 0;
  String get firstName => displayName.split(' ').first;
  AppStrings get strings => language == 'en' ? AppStrings.en : AppStrings.es;
}

/**
 * PULSE-CORE: User Settings Service
 * Manages global user profile stored in Firestore User_Settings collection.
 */
class UserSettingsService {
  static const _col = 'User_Settings';

  static Future<UserSettings> load(String uid) async {
    final doc = await FirebaseFirestore.instance.collection(_col).doc(uid).get();
    if (doc.exists) return UserSettings.fromFirestore(doc.data()!);
    return const UserSettings();
  }

  static Future<void> save(String uid, UserSettings settings) async {
    await FirebaseFirestore.instance
        .collection(_col)
        .doc(uid)
        .set(settings.toMap(), SetOptions(merge: true));
  }

  static Stream<UserSettings> stream(String uid) {
    return FirebaseFirestore.instance
        .collection(_col)
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists
            ? UserSettings.fromFirestore(snap.data()!)
            : const UserSettings());
  }
}


/**
 * PULSE - Application Main Entry Point
 *
 * DESIGN PRINCIPLES (2026):
 * 1. Ultra-minimalism: No unnecessary borders or buttons.
 * 2. Visual Hierarchy: Balance → Health → Categorization.
 * 3. Fluidity: All state changes trigger visual feedback.
 *
 * COMPONENTS:
 * - Pulse-Visual: UI/UX and Glassmorphism.
 * - Pulse-Core: Infrastructure, Firestore, state management.
 * - Pulse-Brain: AI Health Score and pattern recognition.
 */

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAye5GMq-cMTo5b4rsizx72jszmxX75RZU",
        authDomain: "pulse-app-2026-unique123.firebaseapp.com",
        projectId: "pulse-app-2026-unique123",
        storageBucket: "pulse-app-2026-unique123.firebasestorage.app",
        messagingSenderId: "986715824354",
        appId: "1:986715824354:web:8925c8b40ee59a1327bebb",
      ),
    );
    runApp(const PulseApp());
  } catch (e) {
    // PULSE-CORE: Fail-safe rendering for diagnostics
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'PULSE Boot Error: $e',
              style: const TextStyle(color: Color(0xFF39FF14), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
  }
}

class PulseApp extends StatelessWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PULSE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // Carbon Black
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/**
 * PULSE-CORE: Security Gate
 * Manages the transition between Welcome and Home based on Auth state.
 */
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF39FF14)),
            ),
          );
        }
        
        if (snapshot.hasData) {
          return const MainPage();
        }

        return const WelcomeScreen();
      },
    );
  }
}

/**
 * PULSE-VISUAL: Main Navigation
 * Horizontal swipe navigation: Home ↔ Goals ↔ Profile
 */
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      children: [
        const HomeScreen(),
        const GoalsScreen(),
        const ProfileScreen(),
      ],
    );
  }
}

/**
 * PULSE-VISUAL: Welcome Screen
 * Features a hypnotizing breathing pulse logo.
 */
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _glowIntensity;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowIntensity = Tween<double>(begin: 10.0, end: 35.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    // PULSE-CORE: In a real environment, this triggers the Google Auth popup.
    // For now, we use a placeholder or direct provider call if configured.
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(googleProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // THE LIVING PULSE: Breathing animation
            AnimatedBuilder(
              animation: _glowIntensity,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF39FF14).withOpacity(0.3),
                        blurRadius: _glowIntensity.value,
                        spreadRadius: _glowIntensity.value / 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.show_chart,
                    color: Color(0xFF39FF14),
                    size: 80,
                  ),
                );
              },
            ),
            const SizedBox(height: 60),
            Text(
              'PULSE',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
            ),
            Text(
              'TU RITMO FINANCIERO',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.4),
                fontSize: 10,
                letterSpacing: 4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 100),
            // GOOGLE SIGN IN: Glassmorphism button
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: GestureDetector(
                  onTap: _signInWithGoogle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFF39FF14).withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.login, color: Color(0xFF39FF14), size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'ENTRAR CON GOOGLE',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Key used to trigger animations in the HealthCircle child from the parent.
  final GlobalKey<_HealthCircleState> _healthCircleKey = GlobalKey<_HealthCircleState>();

  // PULSE-CORE: Internal state management
  String _amount  = '0';
  TransactionMode _txMode = TransactionMode.expense;
  String _aiAdvice    = 'Buscando patrones críticos...';
  bool   _isAnalyzing = false;

  // PULSE-VISUAL: Dynamic accent color based on transaction mode
  static const _neon    = Color(0xFF39FF14); // Expense: neon green
  static const _emerald = Color(0xFF00B37E); // Income:  emerald
  Color get _accent => _txMode == TransactionMode.income ? _emerald : _neon;

  // Income source labels (used in SmartCategories when income mode)
  static const _incomeSources = ['Salario', 'Freelance', 'Inversión', 'Bono', 'Otros'];

  void _onKeyTap(String key) {
    setState(() {
      if (key == 'delete') {
        _amount = _amount.length > 1 ? _amount.substring(0, _amount.length - 1) : '0';
      } else if (key != 'next') {
        _amount = _amount == '0' ? key : (_amount.length < 9 ? _amount + key : _amount);
      }
    });
  }

  /// Routes the transaction to the correct Firestore collection based on [_txMode].
  void _processTransaction(String category) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final double amountValue = double.tryParse(_amount) ?? 0;
    if (amountValue <= 0) return;

    if (_txMode == TransactionMode.income) {
      // PULSE-CORE: Persist income to Incomes collection
      FirebaseFirestore.instance.collection('Incomes').add({
        'userId':    user.uid,
        'amount':    amountValue,
        'source':    category,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      // PULSE-CORE: Persist expense to Money_Flow collection
      FirebaseFirestore.instance.collection('Money_Flow').add({
        'userId':    user.uid,
        'amount':    amountValue,
        'category':  category,
        'timestamp': FieldValue.serverTimestamp(),
        'type':      'expense',
      });
    }

    setState(() => _amount = '0');
    _healthCircleKey.currentState?._handleTap();
  }

  void _deleteTransaction(String docId) {
    FirebaseFirestore.instance.collection('Money_Flow').doc(docId).delete();
  }

  @override
  void initState() {
    super.initState();
    _triggerMentor();
  }

  Future<void> _triggerMentor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // PULSE-CORE: Cargar perfil del usuario primero
      final settings = await UserSettingsService.load(user.uid);

      // Sin presupuesto definido, Pulse-Brain pide configurarlo
      if (!settings.hasBudget) {
        final name = settings.firstName.isNotEmpty ? settings.firstName : '';
        setState(() {
          _aiAdvice = name.isNotEmpty
              ? '$name, necesito tu presupuesto en el Perfil para medir tu salud.'
              : 'Configura tu presupuesto mensual en el Perfil para empezar.';
          _isAnalyzing = false;
        });
        return;
      }

      // PULSE-CORE: Data Scanner - Envía reporte semanal a Pulse-Brain
      final scan = await _getWeeklySummary(user.uid);
      if (scan.byCategory.isNotEmpty) {
        await _generateAIAdvice(scan, settings);
      } else {
        setState(() {
          _aiAdvice = settings.firstName.isNotEmpty
              ? '${settings.firstName}, aún no hay datos esta semana.'
              : 'Aún no hay suficientes datos para un patrón.';
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      setState(() {
        _aiAdvice = 'Error al conectar con Brain.';
        _isAnalyzing = false;
      });
    }
  }

  // PULSE-CORE: Data Scanner
  // Recupera y agrupa los últimos 7 días de gastos por categoría y día.
  // Solo procesa montos, categorías y fechas. No accede a datos sensibles.
  Future<WeeklyScanResult> _getWeeklySummary(String uid) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final snapshot = await FirebaseFirestore.instance
        .collection('Money_Flow')
        .where('userId', isEqualTo: uid)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('timestamp', descending: false)
        .get();

    final Map<String, double> byCategory = {};
    final Map<String, double> byDay = {};
    double totalWeekly = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String cat = data['category'] ?? 'Otros';
      final double amt = (data['amount'] as num).toDouble();
      final Timestamp ts = data['timestamp'] as Timestamp;
      final DateTime dt = ts.toDate();
      final String dayKey = _dayName(dt.weekday);

      byCategory[cat] = (byCategory[cat] ?? 0) + amt;
      byDay[dayKey] = (byDay[dayKey] ?? 0) + amt;
      totalWeekly += amt;
    }

    return WeeklyScanResult(
      byCategory: byCategory,
      byDay: byDay,
      totalWeekly: totalWeekly,
    );
  }

  String _dayName(int weekday) {
    const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return days[(weekday - 1).clamp(0, 6)];
  }

  Future<void> _generateAIAdvice(WeeklyScanResult scan, UserSettings settings) async {
    // PULSE-BRAIN: Gemini 1.5 Flash - Tactical Advisor (personalized)
    const apiKey = 'AIzaSyAye5GMq-cMTo5b4rsizx72jszmxX75RZU';
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

    final uid  = FirebaseAuth.instance.currentUser!.uid;
    final name = settings.firstName.isNotEmpty ? settings.firstName : 'usuario';
    final strings = settings.strings;

    // PULSE-CORE: Fetch totals from Incomes and Fixed_Expenses
    double totalIncomes = 0;
    double totalFixed   = 0;
    try {
      final incSnap = await FirebaseFirestore.instance
          .collection('Incomes')
          .where('userId', isEqualTo: uid)
          .get();
      for (var d in incSnap.docs) {
        totalIncomes += ((d.data())['amount'] as num?)?.toDouble() ?? 0;
      }
      final fixSnap = await FirebaseFirestore.instance
          .collection('Fixed_Expenses')
          .where('userId', isEqualTo: uid)
          .where('isActive', isEqualTo: true)
          .get();
      for (var d in fixSnap.docs) {
        totalFixed += ((d.data())['amount'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {}

    // PULSE-BRAIN: Invitation Mode – user has no income registered
    if (totalIncomes <= 0) {
      setState(() {
        _aiAdvice = strings.invitationMode(name);
        _isAnalyzing = false;
      });
      return;
    }

    final budget      = settings.monthlyBudget;
    final spent       = scan.totalWeekly;
    final weeklyBudget = budget > 0 ? (budget / 4) : (totalIncomes / 4);
    final remaining   = weeklyBudget - spent;
    final healthScore = ((totalIncomes - (totalFixed + scan.totalWeekly)) / totalIncomes * 100)
        .clamp(0, 100);

    final prompt = """
    Eres Pulse-Brain, el asesor financiero personal de $name.
    Comienza siempre mencionando su nombre ($name) de forma breve y natural.

    REPORTE FINANCIERO REAL:
    - INGRESOS TOTALES: \$${totalIncomes.toStringAsFixed(0)}
    - GASTOS FIJOS ACTIVOS: \$${totalFixed.toStringAsFixed(0)}
    - GASTOS DIARIOS ESTA SEMANA: \$${spent.toStringAsFixed(0)}
    - MARGEN RESTANTE: \$${remaining.toStringAsFixed(0)}
    - PULSO FINANCIERO: ${healthScore.toStringAsFixed(0)}%
    - POR CATEGORÍA: ${scan.byCategory}
    - POR DÍA: ${scan.byDay}

    Tu misión:
    1. Saluda brevemente a $name (2-3 palabras máx con su nombre).
    2. Detecta UN patrón crítico usando DATOS REALES (no genérico).
    3. Da un consejo de EXACTAMENTE máx 20 palabras total (incluyendo el saludo).
    4. Tono: directo, preciso, sin adornos.

    Formato: '$name, [observación concreta + consejo accionable].'
    """;

    final content  = [Content.text(prompt)];
    final response = await model.generateContent(content);

    setState(() {
      _aiAdvice    = response.text?.trim() ?? 'Sigue así, $name, vas por buen camino.';
      _isAnalyzing = false;
    });
  }

  String _formatAmount(String raw) {
    if (raw == '0') return '\$0.00';
    final double value = double.tryParse(raw) ?? 0;
    return '\$${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}.00';
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _txMode == TransactionMode.income;
    return AnimatedTheme(
      duration: const Duration(milliseconds: 350),
      data: Theme.of(context),
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top - 420,
                    ),
                    child: IntrinsicHeight(
                      // PULSE-CORE: Real-time Health Score from 3 collections
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Money_Flow')
                            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                            .snapshots(),
                        builder: (context, expSnap) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('Incomes')
                                .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                                .snapshots(),
                            builder: (context, incSnap) {
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('Fixed_Expenses')
                                    .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                                    .where('isActive', isEqualTo: true)
                                    .snapshots(),
                                builder: (context, fixSnap) {
                                  double totalExpenses = 0;
                                  double totalIncomes  = 0;
                                  double totalFixed    = 0;

                                  if (expSnap.hasData) {
                                    for (var d in expSnap.data!.docs) {
                                      totalExpenses += ((d.data() as Map<String, dynamic>)['amount'] as num?)?.toDouble() ?? 0;
                                    }
                                  }
                                  if (incSnap.hasData) {
                                    for (var d in incSnap.data!.docs) {
                                      totalIncomes += ((d.data() as Map<String, dynamic>)['amount'] as num?)?.toDouble() ?? 0;
                                    }
                                  }
                                  if (fixSnap.hasData) {
                                    for (var d in fixSnap.data!.docs) {
                                      totalFixed += ((d.data() as Map<String, dynamic>)['amount'] as num?)?.toDouble() ?? 0;
                                    }
                                  }

                                  // PULSE-BRAIN: S = (I - (F + D)) / I × 100
                                  double dynamicScore;
                                  if (totalIncomes <= 0) {
                                    dynamicScore = 0;
                                  } else {
                                    dynamicScore = ((totalIncomes - (totalFixed + totalExpenses)) / totalIncomes * 100).clamp(0, 100);
                                  }

                                  final double screenHeight = MediaQuery.of(context).size.height;
                                  final bool isSmallScreen  = screenHeight < 700;
                                  final double circleSize   = isSmallScreen ? 170 : 200;

                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24.0,
                                      vertical: isSmallScreen ? 12.0 : 20.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // ── Header: label + amount + logo ─────────────────────
                                        Padding(
                                          padding: const EdgeInsets.only(top: 10.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  AnimatedDefaultTextStyle(
                                                    duration: const Duration(milliseconds: 300),
                                                    style: GoogleFonts.inter(
                                                      color: _accent.withOpacity(0.6),
                                                      fontSize: 10,
                                                      letterSpacing: 2,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    child: Text(isIncome ? 'INGRESO' : 'PULSO FINANCIERO'),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  AnimatedDefaultTextStyle(
                                                    duration: const Duration(milliseconds: 300),
                                                    style: GoogleFonts.inter(
                                                      color: _amount != '0' ? _accent : Colors.white,
                                                      fontSize: isSmallScreen ? 36 : 48,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: -1,
                                                    ),
                                                    child: Text(_formatAmount(_amount)),
                                                  ),
                                                ],
                                              ),
                                              const _GlowingPulseLogo(),
                                            ],
                                          ),
                                        ),
                                        SizedBox(height: isSmallScreen ? 12 : 20),
                                        // ── Health Circle ──────────────────────────────────────
                                        Center(
                                          child: HealthCircle(
                                            key: _healthCircleKey,
                                            score: dynamicScore,
                                            size: circleSize,
                                          ),
                                        ),
                                        // ── Live Pulse Advice ──────────────────────────────────
                                        LivePulseAdviceCard(
                                          advice: _aiAdvice,
                                          isAnalyzing: _isAnalyzing,
                                        ),
                                        SizedBox(height: isSmallScreen ? 12 : 20),
                                        TransactionHistory(onDelete: _deleteTransaction),
                                        // ── Smart Categories (context-aware) ──────────────────
                                        if (_amount != '0')
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: isIncome
                                                ? _IncomeSourcePicker(
                                                    accent: _accent,
                                                    sources: _incomeSources,
                                                    onTap: _processTransaction,
                                                  )
                                                : SmartCategories(
                                                    onCategoryTap: _processTransaction,
                                                  ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // ── TOGGLE: GASTO | INGRESO ────────────────────────────────────
              _TransactionToggle(
                mode: _txMode,
                onChanged: (m) => setState(() {
                  _txMode = m;
                  _amount = '0';
                }),
              ),
              // ── KEYPAD ───────────────────────────────────────────────────
              GlassmorphismKeypad(onKeyTap: _onKeyTap),
            ],
          ),
        ),
      ),
    );
  }
}

// PULSE-VISUAL: Shared UI Metadata removed (moved to local state)

/**
 * Smart Categories Widget
 * Displays 4 core categories and 1 AI-suggested category.
 */
class SmartCategories extends StatelessWidget {
  final Function(String) onCategoryTap;

  const SmartCategories({super.key, required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // PULSE-BRAIN SUGGESTION: Dynamic prediction
        _CategoryButton(
          icon: Icons.auto_awesome_outlined,
          label: "Sugerido",
          isAI: true,
          size: isSmallScreen ? 46 : 54,
          onTap: () => onCategoryTap("AI"),
        ),
        SizedBox(width: isSmallScreen ? 8 : 12),
        _CategoryButton(
          icon: Icons.restaurant_outlined,
          label: "Comida",
          size: isSmallScreen ? 46 : 54,
          onTap: () => onCategoryTap("Comida"),
        ),
        _CategoryButton(
          icon: Icons.directions_car_outlined,
          label: "Transporte",
          size: isSmallScreen ? 46 : 54,
          onTap: () => onCategoryTap("Transporte"),
        ),
        _CategoryButton(
          icon: Icons.confirmation_number_outlined,
          label: "Ocio",
          size: isSmallScreen ? 46 : 54,
          onTap: () => onCategoryTap("Ocio"),
        ),
        _CategoryButton(
          icon: Icons.more_horiz_outlined,
          label: "Otros",
          size: isSmallScreen ? 46 : 54,
          onTap: () => onCategoryTap("Otros"),
        ),
      ],
    );
  }
}

/**
 * Individual Category Button with glow effects.
 */
class _CategoryButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isAI;
  final double size;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.icon,
    required this.label,
    this.isAI = false,
    this.size = 54,
    required this.onTap,
  });

  @override
  State<_CategoryButton> createState() => _CategoryButtonState();
}

class _CategoryButtonState extends State<_CategoryButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0.0);
        widget.onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _glow,
            builder: (context, child) {
              return Container(
                width: widget.size,
                height: widget.size,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isAI 
                      ? const Color(0xFF39FF14).withOpacity(0.5) 
                      : Colors.white.withOpacity(0.1 + (_glow.value * 0.4)),
                    width: 1,
                  ),
                  boxShadow: [
                    if (_glow.value > 0)
                      BoxShadow(
                        color: const Color(0xFF39FF14).withOpacity(0.3 * _glow.value),
                        blurRadius: 10,
                      )
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: widget.isAI || _glow.value > 0.5 ? const Color(0xFF39FF14) : Colors.white.withOpacity(0.7),
                  size: widget.size * 0.4,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.3),
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/**
 * Visual Branding: The Glowing Pulse Logo.
 */
class _GlowingPulseLogo extends StatelessWidget {
  const _GlowingPulseLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF39FF14).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.show_chart,
        color: Color(0xFF39FF14),
        size: 28,
      ),
    );
  }
}

/**
 * UI Component: Glassmorphism Keypad.
 * Uses BackdropFilter to achieve the frosted glass effect.
 */
class GlassmorphismKeypad extends StatelessWidget {
  final Function(String) onKeyTap;

  const GlassmorphismKeypad({super.key, required this.onKeyTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRow(["1", "2", "3"]),
              _buildRow(["4", "5", "6"]),
              _buildRow(["7", "8", "9"]),
              _buildRow(["delete", "0", "next"]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) => KeypadButton(label: key, onTap: () => onKeyTap(key))).toList(),
      ),
    );
  }
}

class KeypadButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const KeypadButton({super.key, required this.label, required this.onTap});

  @override
  State<KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<KeypadButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isNext = widget.label == "next";
    final bool isDelete = widget.label == "delete";

    final bool isSmallScreen = MediaQuery.of(context).size.height < 700;
    final double btnSize = isSmallScreen ? 55 : 70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(btnSize / 2),
        splashColor: const Color(0xFF39FF14).withOpacity(0.2),
        highlightColor: const Color(0xFF39FF14).withOpacity(0.1),
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: btnSize,
              height: btnSize,
              decoration: BoxDecoration(
                color: isNext 
                    ? const Color(0xFF39FF14).withOpacity(0.8)
                    : Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _buildLabel(isDelete, isNext, isSmallScreen),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(bool isDelete, bool isNext, bool isSmall) {
    final double iconSize = isSmall ? 18 : 22;
    if (isDelete) return Icon(Icons.backspace_outlined, color: Colors.white, size: iconSize);
    if (isNext) return Icon(Icons.arrow_forward_rounded, color: Colors.black, size: isSmall ? 22 : 28);
    return Text(
      widget.label,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: isSmall ? 18 : 24,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

/**
 * Health Circle Component (The Body)
 * Animated arc representing the health score with dynamic colors.
 */
class HealthCircle extends StatefulWidget {
  final double score;
  final double size;

  const HealthCircle({super.key, required this.score, this.size = 200});

  @override
  State<HealthCircle> createState() => _HealthCircleState();
}

class _HealthCircleState extends State<HealthCircle> with TickerProviderStateMixin {
  late AnimationController _drawController;
  late AnimationController _pulseController;
  late Animation<double> _drawAnimation;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _drawAnimation = Tween<double>(begin: 0.0, end: widget.score / 100).animate(
      CurvedAnimation(parent: _drawController, curve: Curves.easeOutQuart),
    );

    _pulseScale = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.05), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.05, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _drawController.forward();
  }

  @override
  void dispose() {
    _drawController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /**
   * Triggers the "Heartbeat" scale pulse effect.
   */
  void _handleTap() {
    _pulseController.forward(from: 0.0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Análisis de Pulse-Brain: Tus finanzas están en ritmo óptimo.'),
        backgroundColor: const Color(0xFF131313),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _pulseScale,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _HealthCirclePainter(progress: widget.score / 100),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.score.toInt().toString(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: widget.size * 0.32,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                  Text(
                    'SALUD ACTUAL',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: widget.size * 0.05,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TransactionHistory extends StatelessWidget {
  final Function(String) onDelete;
  const TransactionHistory({super.key, required this.onDelete});

  IconData _getIcon(String cat) {
    switch(cat) {
      case 'Comida': return Icons.restaurant;
      case 'Transporte': return Icons.directions_car;
      case 'Ocio': return Icons.confirmation_number;
      default: return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Money_Flow')
          .where('userId', isEqualTo: user?.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Dismissible(
              key: Key(docs[index].id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => onDelete(docs[index].id),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
              child: ListTile(
                leading: Icon(_getIcon(data['category']), color: const Color(0xFF39FF14), size: 18),
                title: Text(data['category'].toString().toUpperCase(), style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
                trailing: Text('-\$${data['amount']}', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }
}

/**
 * Custom Painter for the Health Arc.
 */
class _HealthCirclePainter extends CustomPainter {
  final double progress;

  _HealthCirclePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 1.0;

    // Outer Background Track (Faint White)
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Dynamic Arc (Neon Progress)
    final Color color = _getColor(progress * 100);
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    // Glow Layer (Blur effect for neon feel)
    final glowPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -3.14159 / 2; 
    final sweepAngle = 2 * 3.14159 * progress;

    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  /**
   * Color transition logic:
   * Green (>80) -> Yellow/Lime (>50) -> Orange (>30) -> Red (<30)
   */
  Color _getColor(double score) {
    if (score > 80) return const Color(0xFF39FF14);
    if (score > 50) return const Color(0xFFD4FF00);
    if (score > 30) return const Color(0xFFFFCC00);
    return const Color(0xFFFF0033);
  }

  @override
  bool shouldRepaint(covariant _HealthCirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
/**
 * PULSE-VISUAL: Goals Screen
 * Displays saving goals with progress bars.
 */
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<double> _getCurrentHealthScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 85.0;

    final snapshot = await FirebaseFirestore.instance
        .collection('Money_Flow')
        .where('userId', isEqualTo: user.uid)
        .get();

    double totalExpenses = 0;
    for (var doc in snapshot.docs) {
      totalExpenses += (doc.data())['amount'] ?? 0.0;
    }
    
    const double budget = 5000.0;
    return ((budget - totalExpenses) / budget * 100).clamp(0, 100);
  }

  void _showAddGoal(BuildContext context) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF131313),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'NUEVA META',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: '¿Qué quieres lograr?',
                labelStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF39FF14))),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: targetController,
              decoration: InputDecoration(
                labelText: 'Monto objetivo',
                labelStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF39FF14))),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white24, fontSize: 10)),
          ),
          TextButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && titleController.text.isNotEmpty) {
                final target = double.tryParse(targetController.text) ?? 0.0;
                
                // Check if it's the first goal
                final goalsSnapshot = await FirebaseFirestore.instance
                    .collection('User_Goals')
                    .where('userId', isEqualTo: user.uid)
                    .get();
                
                final bool isFirstGoal = goalsSnapshot.docs.isEmpty;

                await FirebaseFirestore.instance.collection('User_Goals').add({
                  'userId': user.uid,
                  'title': titleController.text,
                  'target': target,
                  'current': 0.0,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (isFirstGoal) {
                  _confettiController.play();
                  // Create Welcome Insight
                  final score = await _getCurrentHealthScore();
                  await FirebaseFirestore.instance.collection('User_Insights').add({
                    'userId': user.uid,
                    'message': 'Meta ${titleController.text} activada. Con tu salud actual al ${score.toInt()}%, estás en la zona verde para lograrlo.',
                    'timestamp': FieldValue.serverTimestamp(),
                    'isWelcome': true,
                  });
                }

                if (context.mounted) Navigator.pop(dialogContext);
              }
            },
            child: const Text('CREAR', style: TextStyle(color: Color(0xFF39FF14), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF121212),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddGoal(context),
            backgroundColor: const Color(0xFF39FF14),
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.black, size: 28),
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MIS METAS',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 30),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('User_Goals')
                          .where('userId', isEqualTo: user?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final goals = snapshot.data!.docs;

                        if (goals.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.flag_outlined, color: Colors.white.withOpacity(0.05), size: 100),
                                const SizedBox(height: 20),
                                Text(
                                  'SIN METAS TODAVÍA',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.1),
                                    letterSpacing: 2,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: goals.length,
                          itemBuilder: (context, index) {
                            final data = goals[index].data() as Map<String, dynamic>;
                            final double current = (data['current'] is int) 
                                ? (data['current'] as int).toDouble() 
                                : (data['current'] ?? 0.0);
                            final double target = (data['target'] is int) 
                                ? (data['target'] as int).toDouble() 
                                : (data['target'] ?? 1000.0);
                            final double progress = (current / target).clamp(0.0, 1.0);

                            return GoalCard(
                              title: data['title'] ?? 'Meta',
                              current: current,
                              target: target,
                              progress: progress,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  // PULSE-BRAIN: Dynamic Gemini Insight Area
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('User_Insights')
                        .where('userId', isEqualTo: user?.uid)
                        .orderBy('timestamp', descending: true)
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      String aiMessage = 'ANÁLISIS BRAIN: Tu dinero necesita un propósito. Define tu primera meta aquí abajo.';
                      bool hasInsight = false;

                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                        aiMessage = 'ANÁLISIS BRAIN: ${data['message']}';
                        hasInsight = true;
                      }

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF39FF14).withOpacity(hasInsight ? 0.4 : 0.2)
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasInsight ? Icons.auto_awesome : Icons.lightbulb_outline, 
                              color: const Color(0xFF39FF14), 
                              size: 24
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                aiMessage,
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xFF39FF14), // Neon Green
              Colors.white,
              Color(0xFF2ECC71),
            ],
            numberOfParticles: 20,
            gravity: 0.1,
          ),
        ),
      ],
    );
  }
}

class GoalCard extends StatelessWidget {
  final String title;
  final double current;
  final double target;
  final double progress;

  const GoalCard({
    super.key,
    required this.title,
    required this.current,
    required this.target,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.inter(
                  color: const Color(0xFF39FF14),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '\$${current.toInt()}',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                ' / \$${target.toInt()}',
                style: GoogleFonts.inter(color: Colors.white24),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // PULSE-VISUAL: Neon Progress Bar
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF39FF14),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF39FF14).withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/**
 * PULSE-VISUAL: LivePulseAdviceCard
 * Premium glassmorphism AI advisor widget.
 * - BackdropFilter blur para efecto cristal real
 * - Borde neon de 0.5px con pulso animado durante la carga
 * - Efecto 'máquina de escribir' al revelar el consejo de IA
 */
class LivePulseAdviceCard extends StatefulWidget {
  final String advice;
  final bool isAnalyzing;

  const LivePulseAdviceCard({
    super.key,
    required this.advice,
    required this.isAnalyzing,
  });

  @override
  State<LivePulseAdviceCard> createState() => _LivePulseAdviceCardState();
}

class _LivePulseAdviceCardState extends State<LivePulseAdviceCard>
    with TickerProviderStateMixin {

  // Controller para el pulso del borde durante la carga
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Controller para el efecto typewriter del texto
  late AnimationController _typeController;
  late Animation<int> _typeAnim;

  String _displayedAdvice = '';
  String _previousAdvice = '';

  @override
  void initState() {
    super.initState();

    // Pulso suave del borde (0.8s, loop)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.15, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Typewriter: 1 caracter cada 18ms
    _typeController = AnimationController(
      duration: const Duration(milliseconds: 1),
      vsync: this,
    );
    _typeAnim = IntTween(begin: 0, end: 0).animate(_typeController);
    _typeController.addListener(() {
      setState(() {
        _displayedAdvice = _previousAdvice.substring(
          0,
          _typeAnim.value.clamp(0, _previousAdvice.length),
        );
      });
    });
  }

  @override
  void didUpdateWidget(LivePulseAdviceCard old) {
    super.didUpdateWidget(old);
    // Cuando llega el consejo nuevo, lanzar typewriter
    if (!widget.isAnalyzing && widget.advice != old.advice && widget.advice.isNotEmpty) {
      _startTypewriter(widget.advice);
    }
  }

  void _startTypewriter(String text) {
    _previousAdvice = text;
    final duration = Duration(milliseconds: text.length * 22);
    _typeController.stop();
    _typeController.duration = duration;
    _typeAnim = IntTween(begin: 0, end: text.length).animate(
      CurvedAnimation(parent: _typeController, curve: Curves.linear),
    );
    _typeController.forward(from: 0);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neonGreen = const Color(0xFF39FF14);

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        final borderOpacity = widget.isAnalyzing ? _pulseAnim.value : 0.35;
        final glowOpacity  = widget.isAnalyzing ? _pulseAnim.value * 0.4 : 0.07;

        return Container(
          margin: const EdgeInsets.only(top: 14, bottom: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: neonGreen.withOpacity(glowOpacity),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: neonGreen.withOpacity(borderOpacity),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icono / spinner
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: widget.isAnalyzing
                          ? CircularProgressIndicator(
                              strokeWidth: 1.2,
                              color: neonGreen.withOpacity(0.85),
                            )
                          : Icon(
                              Icons.auto_awesome_rounded,
                              color: neonGreen.withOpacity(0.85),
                              size: 14,
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Texto con typewriter
                    Expanded(
                      child: widget.isAnalyzing
                          ? Text(
                              'Pulse-Brain analizando patrones...',
                              style: GoogleFonts.inter(
                                color: neonGreen.withOpacity(0.45),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                            )
                          : Text(
                              _displayedAdvice,
                              style: GoogleFonts.inter(
                                color: neonGreen.withOpacity(0.92),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/**
 * PULSE-VISUAL: Language Chip
 * Small selectable pill for the language selector in ProfileScreen.
 */
class _LangChip extends StatelessWidget {
  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  static const _neon = Color(0xFF39FF14);

  const _LangChip({
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _neon.withOpacity(0.5) : Colors.white.withOpacity(0.08),
            width: 0.5,
          ),
          color: selected ? _neon.withOpacity(0.08) : Colors.transparent,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? _neon.withOpacity(0.9) : Colors.white.withOpacity(0.3),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/**
 * PULSE-VISUAL: Profile Screen (Identity Hub)
 * Displays and edits user profile: avatar, name, budget, currency.
 * Pulse-Core: Reads/writes to Firestore User_Settings collection.
 */
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController    = TextEditingController();
  final _budgetController  = TextEditingController();
  UserSettings _settings   = const UserSettings();
  bool _loading            = true;
  bool _saving             = false;

  static const _neon = Color(0xFF39FF14);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final s = await UserSettingsService.load(uid);
    setState(() {
      _settings = s;
      _nameController.text   = s.displayName;
      _budgetController.text = s.monthlyBudget > 0
          ? s.monthlyBudget.toStringAsFixed(0)
          : '';
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);

    final updated = UserSettings(
      displayName:   _nameController.text.trim(),
      currency:      _settings.currency,
      monthlyBudget: double.tryParse(_budgetController.text) ?? 0,
      isPremium:     _settings.isPremium,
      language:      _settings.language,
    );

    await UserSettingsService.save(uid, updated);
    setState(() {
      _settings = updated;
      _saving   = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Perfil guardado ✓',
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
          backgroundColor: _neon,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  String get _initials {
    final n = _settings.displayName.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF39FF14))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header ──────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PERFIL',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w600,
                      )),
                  if (_settings.isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: _neon.withOpacity(0.4), width: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('PREMIUM',
                          style: GoogleFonts.inter(
                            color: _neon.withOpacity(0.85),
                            fontSize: 9,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                ],
              ),
              const SizedBox(height: 36),

              // ── Avatar circular con borde neón ───────────────────────────
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow exterior
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _neon.withOpacity(0.15),
                            blurRadius: 24,
                            spreadRadius: 4,
                          )
                        ],
                      ),
                    ),
                    // Borde neón fino
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _neon.withOpacity(0.5), width: 0.8),
                        color: const Color(0xFF1E1E1E),
                      ),
                      child: Center(
                        child: FirebaseAuth.instance.currentUser?.photoURL != null
                            ? ClipOval(
                                child: Image.network(
                                  FirebaseAuth.instance.currentUser!.photoURL!,
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                _initials,
                                style: GoogleFonts.inter(
                                  color: _neon,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ── Campos minimalistas ───────────────────────────────────────
              _MinimalField(
                label: 'NOMBRE',
                controller: _nameController,
                hint: 'Tu nombre completo',
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 28),
              _MinimalField(
                label: 'PRESUPUESTO MENSUAL',
                controller: _budgetController,
                hint: '0',
                prefix: '\$  ',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 28),

              // Moneda (fija, no editable por ahora)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONEDA',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 9,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(_settings.currency,
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          )),
                      const SizedBox(width: 8),
                      Text('(más opciones pronto)',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.2),
                            fontSize: 10,
                          )),
                    ],
                  ),
                  Divider(color: Colors.white.withOpacity(0.08), height: 1),
                ],
              ),
              const SizedBox(height: 28),

              // ── Selector de Idioma ───────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IDIOMA',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 9,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _LangChip(
                        label: 'Español',
                        code: 'es',
                        selected: _settings.language == 'es',
                        onTap: () => setState(() {
                          _settings = UserSettings(
                            displayName:   _settings.displayName,
                            currency:      _settings.currency,
                            monthlyBudget: _settings.monthlyBudget,
                            isPremium:     _settings.isPremium,
                            language:      'es',
                          );
                        }),
                      ),
                      const SizedBox(width: 10),
                      _LangChip(
                        label: 'English',
                        code: 'en',
                        selected: _settings.language == 'en',
                        onTap: () => setState(() {
                          _settings = UserSettings(
                            displayName:   _settings.displayName,
                            currency:      _settings.currency,
                            monthlyBudget: _settings.monthlyBudget,
                            isPremium:     _settings.isPremium,
                            language:      'en',
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(color: Colors.white.withOpacity(0.08), height: 1),
                ],
              ),
              const SizedBox(height: 44),

              // ── Botón Guardar ────────────────────────────────────────────
              GestureDetector(
                onTap: _saving ? null : _saveProfile,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: _neon.withOpacity(0.6), width: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    color: _neon.withOpacity(_saving ? 0.03 : 0.07),
                    boxShadow: [
                      BoxShadow(
                        color: _neon.withOpacity(0.06),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _saving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: _neon.withOpacity(0.8),
                            ),
                          )
                        : Text('GUARDAR',
                            style: GoogleFonts.inter(
                              color: _neon.withOpacity(0.9),
                              fontSize: 11,
                              letterSpacing: 2.5,
                              fontWeight: FontWeight.w700,
                            )),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Cerrar Sesión ────────────────────────────────────────────
              GestureDetector(
                onTap: _logout,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('CERRAR SESIÓN',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/**
 * PULSE-VISUAL: Minimal Line Field
 * Borderless bottom-line style input for the Profile screen.
 */
class _MinimalField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String prefix;
  final TextInputType keyboardType;

  const _MinimalField({
    required this.label,
    required this.controller,
    required this.hint,
    this.prefix = '',
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.3),
              fontSize: 9,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 8),
        Row(
          children: [
            if (prefix.isNotEmpty)
              Text(prefix,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF39FF14).withOpacity(0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  )),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                cursorColor: const Color(0xFF39FF14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Divider(color: Colors.white.withOpacity(0.1), height: 1),
      ],
    );
  }
}

/**
 * PULSE-VISUAL: Transaction Mode Toggle
 * Glassmorphism pill toggle above the keypad: [ GASTO | INGRESO ]
 * Neon Green for expense, Emerald for income.
 */
class _TransactionToggle extends StatelessWidget {
  final TransactionMode mode;
  final ValueChanged<TransactionMode> onChanged;

  static const _neon    = Color(0xFF39FF14);
  static const _emerald = Color(0xFF00B37E);

  const _TransactionToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isIncome = mode == TransactionMode.income;
    final accent   = isIncome ? _emerald : _neon;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: accent.withOpacity(0.2), width: 0.5),
            ),
            child: Row(
              children: [
                _Segment(
                  label: 'GASTO',
                  active: !isIncome,
                  accent: _neon,
                  onTap: () => onChanged(TransactionMode.expense),
                ),
                _Segment(
                  label: 'INGRESO',
                  active: isIncome,
                  accent: _emerald,
                  onTap: () => onChanged(TransactionMode.income),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: active ? accent.withOpacity(0.12) : Colors.transparent,
            border: active
                ? Border.all(color: accent.withOpacity(0.5), width: 0.8)
                : Border.all(color: Colors.transparent, width: 0.8),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: active ? accent : Colors.white.withOpacity(0.3),
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/**
 * PULSE-VISUAL: Income Source Picker
 * Emerald-themed chip row shown when in INCOME mode.
 */
class _IncomeSourcePicker extends StatelessWidget {
  final Color accent;
  final List<String> sources;
  final void Function(String) onTap;

  const _IncomeSourcePicker({
    required this.accent,
    required this.sources,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FUENTE DE INGRESO',
          style: GoogleFonts.inter(
            color: accent.withOpacity(0.5),
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sources.map((source) {
            return GestureDetector(
              onTap: () => onTap(source),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.4), width: 0.5),
                  color: accent.withOpacity(0.07),
                ),
                child: Text(
                  source,
                  style: GoogleFonts.inter(
                    color: accent.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/**
 * PULSE-VISUAL: Commitments Screen (Gastos Fijos)
 * List of monthly fixed expenses with an on/off switch.
 * Pulse-Core: Reads/writes to Fixed_Expenses Firestore collection.
 */
class CommitmentsScreen extends StatefulWidget {
  const CommitmentsScreen({super.key});

  @override
  State<CommitmentsScreen> createState() => _CommitmentsScreenState();
}

class _CommitmentsScreenState extends State<CommitmentsScreen> {
  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _adding = false;

  static const _neon    = Color(0xFF39FF14);
  static const _emerald = Color(0xFF00B37E);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('Fixed_Expenses')
      .where('userId', isEqualTo: _uid)
      .orderBy('timestamp', descending: false)
      .snapshots();

  Future<void> _addCommitment() async {
    final name   = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (name.isEmpty || amount <= 0 || _uid == null) return;

    await FirebaseFirestore.instance.collection('Fixed_Expenses').add({
      'userId':    _uid,
      'name':      name,
      'amount':    amount,
      'isActive':  true,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _nameCtrl.clear();
    _amountCtrl.clear();
    setState(() => _adding = false);
  }

  Future<void> _toggleActive(String docId, bool current) async {
    await FirebaseFirestore.instance
        .collection('Fixed_Expenses')
        .doc(docId)
        .update({'isActive': !current});
  }

  Future<void> _delete(String docId) async {
    await FirebaseFirestore.instance
        .collection('Fixed_Expenses')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'COMPROMISOS',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _adding = !_adding),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _adding
                              ? Colors.white.withOpacity(0.15)
                              : _neon.withOpacity(0.4),
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        color: _adding ? Colors.transparent : _neon.withOpacity(0.07),
                      ),
                      child: Text(
                        _adding ? 'CANCELAR' : '+ AGREGAR',
                        style: GoogleFonts.inter(
                          color: _adding
                              ? Colors.white.withOpacity(0.3)
                              : _neon.withOpacity(0.9),
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Gastos que salen cada mes',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Add Form ────────────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _adding
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _neon.withOpacity(0.15), width: 0.5),
                            ),
                            child: Column(
                              children: [
                                _MinimalField(
                                  label: 'NOMBRE',
                                  controller: _nameCtrl,
                                  hint: 'Alquiler, Netflix, Gym…',
                                ),
                                const SizedBox(height: 12),
                                _MinimalField(
                                  label: 'MONTO MENSUAL',
                                  controller: _amountCtrl,
                                  hint: '0',
                                  prefix: '\$  ',
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: _addCommitment,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: _neon.withOpacity(0.5), width: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                      color: _neon.withOpacity(0.08),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'GUARDAR',
                                        style: GoogleFonts.inter(
                                          color: _neon,
                                          fontSize: 11,
                                          letterSpacing: 2,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _stream,
                builder: (ctx, snap) {
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Aún no hay gastos fijos.\nAgregá tu alquiler, teléfono, suscripciones…',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 12,
                          height: 1.8,
                        ),
                      ),
                    );
                  }

                  double monthlyTotal = 0;
                  for (var d in snap.data!.docs) {
                    final data = d.data() as Map<String, dynamic>;
                    if (data['isActive'] == true) {
                      monthlyTotal += (data['amount'] as num?)?.toDouble() ?? 0;
                    }
                  }

                  return Column(
                    children: [
                      // Summary bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL ACTIVO / MES',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.25),
                                fontSize: 9,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              '\$${monthlyTotal.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                color: _emerald.withOpacity(0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        color: Colors.white.withOpacity(0.05),
                        height: 1,
                        indent: 24,
                        endIndent: 24,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: snap.data!.docs.length,
                          itemBuilder: (ctx, i) {
                            final doc  = snap.data!.docs[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final bool isActive = data['isActive'] ?? true;
                            final double amount = (data['amount'] as num?)?.toDouble() ?? 0;
                            final String name   = data['name'] ?? '';

                            return Dismissible(
                              key: Key(doc.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: Icon(Icons.delete_outline,
                                    color: Colors.red.withOpacity(0.6), size: 20),
                              ),
                              onDismissed: (_) => _delete(doc.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    // Color dot
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive
                                            ? _emerald.withOpacity(0.7)
                                            : Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GoogleFonts.inter(
                                              color: isActive
                                                  ? Colors.white.withOpacity(0.85)
                                                  : Colors.white.withOpacity(0.3),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '\$${amount.toStringAsFixed(0)} / mes',
                                            style: GoogleFonts.inter(
                                              color: Colors.white.withOpacity(0.25),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Toggle switch
                                    GestureDetector(
                                      onTap: () => _toggleActive(doc.id, isActive),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 42,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: isActive
                                              ? _emerald.withOpacity(0.2)
                                              : Colors.white.withOpacity(0.05),
                                          border: Border.all(
                                            color: isActive
                                                ? _emerald.withOpacity(0.5)
                                                : Colors.white.withOpacity(0.1),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            AnimatedPositioned(
                                              duration: const Duration(milliseconds: 200),
                                              left: isActive ? 20 : 2,
                                              top: 3,
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isActive ? _emerald : Colors.white.withOpacity(0.25),
                                                  boxShadow: isActive
                                                      ? [BoxShadow(
                                                          color: _emerald.withOpacity(0.4),
                                                          blurRadius: 6,
                                                        )]
                                                      : [],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
