import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotateCtrl;
  late AnimationController _scaleCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _exitCtrl;

  late Animation<double> _rotateAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _exitFade;
  late Animation<double> _exitScale;

  @override
  void initState() {
    super.initState();

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _rotateAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateCtrl, curve: Curves.easeInOut),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeOut),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeOut),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _scaleCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _rotateCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _fadeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    _exitCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _scaleCtrl.dispose();
    _fadeCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _scaleCtrl,
          _rotateCtrl,
          _fadeCtrl,
          _exitCtrl,
        ]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _exitFade,
            child: Transform.scale(
              scale: _exitScale.value,
              child: Stack(
                children: [
                  // Granos decorativos de fondo
                  ...List.generate(12, (i) {
                    final angle = (i / 12) * 2 * math.pi;
                    const radius = 140.0;
                    final cx = MediaQuery.of(context).size.width / 2 +
                        radius * math.cos(angle);
                    final cy = MediaQuery.of(context).size.height / 2 +
                        radius * math.sin(angle);
                    return Positioned(
                      left: cx - 10,
                      top: cy - 10,
                      child: Opacity(
                        opacity: 0.18,
                        child: Transform.rotate(
                          angle: angle + _rotateAnim.value,
                          child: const _CoffeeBean(size: 22, color: Colors.white),
                        ),
                      ),
                    );
                  }),

                  // Centro
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Grano principal mejorado
                        Transform.scale(
                          scale: _scaleAnim.value,
                          child: Transform.rotate(
                            angle: _rotateAnim.value,
                            child: _EnhancedCoffeeBeanWidget(
                              rotationValue: _rotateAnim.value,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Logo y texto
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: Column(
                            children: [
                              Image.asset(
                                'lib/features/fotos/Logo.png',
                                width: 220,
                                errorBuilder: (_, __, ___) => const Text(
                                  'CafeConecta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Tu cosecha, conectada al mundo',
                                style: TextStyle(
                                  color: Color(0xFFA5D6A7),
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 60),

                        FadeTransition(
                          opacity: _fadeAnim,
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.7),
                              ),
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Grano mejorado principal ───────────────────────────────────────────────

class _EnhancedCoffeeBeanWidget extends StatelessWidget {
  final double rotationValue;
  const _EnhancedCoffeeBeanWidget({required this.rotationValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 0.85,
          colors: [
            Color(0xFF6D4C41),
            Color(0xFF3E2723),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: const Color(0xFF8D6E63).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _EnhancedCoffeeBeanPainter(),
      ),
    );
  }
}

class _EnhancedCoffeeBeanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Cuerpo del grano ──────────────────────────────────────────────────
    final beanPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.3),
        radius: 0.7,
        colors: const [
          Color(0xFF8D6E63),
          Color(0xFF6D4C41),
          Color(0xFF4E342E),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.9,
        height: size.height * 0.65,
      ));

    final rx = size.width * 0.40;
    final ry = size.height * 0.27;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      beanPaint,
    );

    // ── Surco central (línea característica del grano) ────────────────────
    final groovePaint = Paint()
      ..color = const Color(0xFF2C1810)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.038
      ..strokeCap = StrokeCap.round;

    final groovePath = Path()
      ..moveTo(cx - rx * 0.88, cy)
      ..cubicTo(
        cx - rx * 0.28, cy - ry * 0.70,
        cx + rx * 0.28, cy - ry * 0.70,
        cx + rx * 0.88, cy,
      )
      ..moveTo(cx - rx * 0.88, cy)
      ..cubicTo(
        cx - rx * 0.28, cy + ry * 0.70,
        cx + rx * 0.28, cy + ry * 0.70,
        cx + rx * 0.88, cy,
      );

    canvas.drawPath(groovePath, groovePaint);

    // ── Líneas de textura secundarias ─────────────────────────────────────
    final texturePaint = Paint()
      ..color = const Color(0xFF5D4037).withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.018
      ..strokeCap = StrokeCap.round;

    // Textura superior
    final topTexture = Path()
      ..moveTo(cx - rx * 0.70, cy - ry * 0.35)
      ..cubicTo(
        cx - rx * 0.22, cy - ry * 0.88,
        cx + rx * 0.22, cy - ry * 0.88,
        cx + rx * 0.70, cy - ry * 0.35,
      );
    canvas.drawPath(topTexture, texturePaint);

    // Textura inferior
    final bottomTexture = Path()
      ..moveTo(cx - rx * 0.70, cy + ry * 0.35)
      ..cubicTo(
        cx - rx * 0.22, cy + ry * 0.88,
        cx + rx * 0.22, cy + ry * 0.88,
        cx + rx * 0.70, cy + ry * 0.35,
      );
    canvas.drawPath(bottomTexture, texturePaint);

    // ── Brillo principal ──────────────────────────────────────────────────
    final shinePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.5, -0.6),
        radius: 0.55,
        colors: [
          Colors.white.withOpacity(0.28),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(cx - rx * 0.22, cy - ry * 0.30),
        width: rx * 0.85,
        height: ry * 0.75,
      ));

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - rx * 0.22, cy - ry * 0.30),
        width: rx * 0.85,
        height: ry * 0.75,
      ),
      shinePaint,
    );

    // ── Punto de luz pequeño ──────────────────────────────────────────────
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - rx * 0.42, cy - ry * 0.48),
        width: rx * 0.28,
        height: ry * 0.26,
      ),
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(_EnhancedCoffeeBeanPainter old) => false;
}

// ─── Grano pequeño para el fondo decorativo ──────────────────────────────────

class _CoffeeBean extends StatelessWidget {
  final double size;
  final Color color;
  const _CoffeeBean({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CoffeeBeanPainter(color: color),
    );
  }
}

class _CoffeeBeanPainter extends CustomPainter {
  final Color color;
  const _CoffeeBeanPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.42;
    final ry = size.height * 0.28;

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      paint,
    );

    final path = Path()
      ..moveTo(cx - rx * 0.9, cy)
      ..cubicTo(cx - rx * 0.3, cy - ry * 0.6, cx + rx * 0.3,
          cy - ry * 0.6, cx + rx * 0.9, cy)
      ..moveTo(cx - rx * 0.9, cy)
      ..cubicTo(cx - rx * 0.3, cy + ry * 0.6, cx + rx * 0.3,
          cy + ry * 0.6, cx + rx * 0.9, cy);

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_CoffeeBeanPainter old) => old.color != color;
}