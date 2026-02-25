import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/**
 * PULSE - Application Main Entry Point
 * 
 * DESIGN PRINCIPLES (2026):
 * 1. Ultra-minimalism: No unnecessary borders or buttons.
 * 2. Visual Hierarchy: Balance (Goal) -> Health (Health) -> Categorization (Action).
 * 3. Fluidity: All state changes must trigger visual feedback (animations).
 * 
 * COMPONENT ASSIGNMENTS:
 * - Pulse-Visual: UI/UX implementation and Glassmorphism.
 * - Pulse-Core: Infrastructure, Firestore logic, and state management.
 * - Pulse-Brain: AI Health Score calculation and pattern recognition.
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
          return const HomeScreen();
        }

        return const WelcomeScreen();
      },
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
  // PULSE-CORE: Internal state management
  String _amount = "0"; // Current input amount
  double _healthScore = 85; // Current HP (Pulse Score)

  /**
   * Handle numeric input from the custom keyboard.
   * Resets amount to '0' logic and prevents overflow.
   */
  void _onKeyTap(String key) {
    setState(() {
      if (key == "delete") {
        if (_amount.length > 1) {
          _amount = _amount.substring(0, _amount.length - 1);
        } else {
          _amount = "0";
        }
      } else if (key == "next") {
        // Pulse-Core: Placeholder for navigation or expansion
      } else {
        if (_amount == "0") {
          _amount = key;
        } else if (_amount.length < 9) {
          _amount += key;
        }
      }
    });
  }

  /**
   * Process transaction completion.
   * 1. Resets the UI amount.
   * 2. Simulates health score impact.
   * 3. Triggers visual heartbeat.
   * 
   * Future Integration (Pulse-Core): 
   * This function will call Firestore's Money_Flow collection.
   */
  void _processTransaction(String category) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final double amountValue = double.tryParse(_amount) ?? 0;
    if (amountValue <= 0) return;

    // PULSE-CORE: Persistencia Real en Firestore
    FirebaseFirestore.instance.collection('Money_Flow').add({
      'userId': user.uid,
      'amount': amountValue,
      'category': category,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'expense',
    });

    setState(() {
      _amount = "0";
      // Pulse-Brain: Actualización instantánea visual
      _healthScore = (_healthScore - 2).clamp(0, 100);
    });

    // Trigger visual heartbeat on the center circle
    _healthCircleKey.currentState?._handleTap();
  }

  void _deleteTransaction(String docId) {
    FirebaseFirestore.instance.collection('Money_Flow').doc(docId).delete();
    setState(() {
      // Pulse-Brain: Recalculate or just visual feedback
      _healthScore = (_healthScore + 2).clamp(0, 100);
    });
  }

  /**
   * Format raw string to financial representation (e.g. 12450 -> $12,450.00).
   */
  String _formatAmount(String raw) {
    if (raw == "0") return "\$0.00";
    final double value = double.tryParse(raw) ?? 0;
    return "\$${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}.00";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER: The Financial Snapshot
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BALANCE ACTUAL',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatAmount(_amount),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                        const _GlowingPulseLogo(), // PULSE-VISUAL: Branding identity
                      ],
                    ),
                    const Spacer(),
                    // CENTER: The Pulse (Health Score)
                    Center(
                      child: HealthCircle(key: _healthCircleKey, score: _healthScore),
                    ),
                    const Spacer(),
                    // ACTIONS: Smart Categories (Only visible with active amount)
                    if (_amount != "0")
                      SmartCategories(
                        onCategoryTap: _processTransaction,
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // INPUT: Glassmorphism Keypad
            GlassmorphismKeypad(onKeyTap: _onKeyTap),
          ],
        ),
      ),
    );
  }
}

// Key used to trigger animations in the HealthCircle child from the parent.
final GlobalKey<_HealthCircleState> _healthCircleKey = GlobalKey<_HealthCircleState>();

/**
 * Smart Categories Widget
 * Displays 4 core categories and 1 AI-suggested category.
 */
class SmartCategories extends StatelessWidget {
  final Function(String) onCategoryTap;

  const SmartCategories({super.key, required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // PULSE-BRAIN SUGGESTION: Dynamic prediction (e.g., Lunch, Coffee, Rent)
        _CategoryButton(
          icon: Icons.auto_awesome_outlined,
          label: "Sugerido",
          isAI: true,
          onTap: () => onCategoryTap("AI"),
        ),
        const SizedBox(width: 12),
        _CategoryButton(
          icon: Icons.restaurant_outlined,
          label: "Comida",
          onTap: () => onCategoryTap("Comida"),
        ),
        _CategoryButton(
          icon: Icons.directions_car_outlined,
          label: "Transporte",
          onTap: () => onCategoryTap("Transporte"),
        ),
        _CategoryButton(
          icon: Icons.confirmation_number_outlined,
          label: "Ocio",
          onTap: () => onCategoryTap("Ocio"),
        ),
        _CategoryButton(
          icon: Icons.more_horiz_outlined,
          label: "Otros",
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
  final VoidCallback onTap;

  const _CategoryButton({
    required this.icon,
    required this.label,
    this.isAI = false,
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
                width: 54,
                height: 54,
                margin: const EdgeInsets.symmetric(horizontal: 6),
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
                  size: 22,
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
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

    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0.0);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: isNext 
                  ? const Color(0xFF39FF14).withOpacity(0.8)
                  : Colors.white.withOpacity(0.05 + (_glowAnimation.value * 0.05)),
              shape: BoxShape.circle,
              boxShadow: [
                if (_glowAnimation.value > 0 && !isNext)
                  BoxShadow(
                    color: const Color(0xFF39FF14).withOpacity(0.2 * _glowAnimation.value),
                    blurRadius: 10,
                  )
              ],
            ),
            child: Center(
              child: _buildLabel(isDelete, isNext),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(bool isDelete, bool isNext) {
    if (isDelete) return const Icon(Icons.backspace_outlined, color: Colors.white, size: 22);
    if (isNext) return const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 28);
    return Text(
      widget.label,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 24,
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

  const HealthCircle({super.key, required this.score});

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
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _drawAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(200, 200),
                    painter: _HealthCirclePainter(progress: _drawAnimation.value),
                  );
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.score.toInt().toString(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                  Text(
                    'SALUD ACTUAL',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
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
