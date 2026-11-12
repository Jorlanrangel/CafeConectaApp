import 'package:cafeconecta_aplication/features/liquidacion/liquidacion_screen.dart';
import 'package:cafeconecta_aplication/features/ventas/ventas_screen.dart';
import 'package:cafeconecta_aplication/fincas/finca_model.dart';
import 'package:cafeconecta_aplication/fincas/finca_service.dart';
import 'package:cafeconecta_aplication/fincas/fincas_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import 'home_widgets.dart';
import '../recoleccion/recoleccion_screen.dart';
import '../recoleccion/ver_recoleccion_screen.dart';
import '../dashboard/estadisticas_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _userName = 'Usuario';

  List<FincaModel> _fincas = [];
  FincaModel? _fincaSeleccionada;

  int _totalLotes = 0;
  int _totalTrabajadores = 0;
  String _loteTop = '-';
  double _loteTopKilos = 0;
  double _totalKilosFinca = 0;
  int _totalRegistros = 0;
  List<Map<String, dynamic>> _actividadReciente = [];

  final List<StreamSubscription> _subs = [];
  StreamSubscription? _cosechasSub;
  StreamSubscription? _lotesSub;
  StreamSubscription? _trabajadoresSub;

  @override
  void initState() {
    super.initState();
    _cargarNombreUsuario();
    _escucharFincas();
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    _cosechasSub?.cancel();
    _lotesSub?.cancel();
    _trabajadoresSub?.cancel();
    super.dispose();
  }

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _cargarNombreUsuario() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_uid)
              .get();
      if (doc.exists && mounted) {
        setState(() => _userName = doc.data()?['nombre'] ?? 'Usuario');
      }
    } catch (_) {}
  }

  void _escucharFincas() {
    final sub = FincaService.obtenerFincas().listen((fincas) {
      if (!mounted) return;
      FincaModel? fincaActual;
      if (_fincaSeleccionada != null) {
        try {
          fincaActual = fincas.firstWhere(
            (f) => f.id == _fincaSeleccionada!.id,
          );
        } catch (_) {
          fincaActual = null;
        }
      }
      if (fincaActual == null && fincas.isNotEmpty) {
        fincaActual = fincas.first;
      }
      setState(() {
        _fincas = fincas;
        _fincaSeleccionada = fincaActual;
      });
      if (fincaActual != null) {
        _escucharDatosFinca(fincaActual);
      } else {
        setState(() {
          _totalLotes = 0;
          _totalTrabajadores = 0;
          _loteTop = '-';
          _loteTopKilos = 0;
          _totalKilosFinca = 0;
          _totalRegistros = 0;
          _actividadReciente = [];
        });
      }
    });
    _subs.add(sub);
  }

  void _escucharDatosFinca(FincaModel finca) {
    final db = FirebaseFirestore.instance;
    _lotesSub?.cancel();
    _cosechasSub?.cancel();
    _trabajadoresSub?.cancel();

    _lotesSub = db
        .collection('usuarios')
        .doc(_uid)
        .collection('fincas')
        .doc(finca.id)
        .collection('lotes')
        .snapshots()
        .listen((snap) {
          if (mounted) setState(() => _totalLotes = snap.docs.length);
        });

    _trabajadoresSub = db
        .collection('usuarios')
        .doc(_uid)
        .collection('trabajadores')
        .where('fincaId', isEqualTo: finca.id)
        .snapshots()
        .listen((snap) {
          if (mounted) setState(() => _totalTrabajadores = snap.docs.length);
        });

    _cosechasSub = db
        .collection('usuarios')
        .doc(_uid)
        .collection('cosechas')
        .where('fincaId', isEqualTo: finca.id)
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          final cosechas = snap.docs.map((doc) => doc.data()).toList();
          cosechas.sort((a, b) {
            final fa = DateTime.tryParse(a['fecha'] ?? '') ?? DateTime(2000);
            final fb = DateTime.tryParse(b['fecha'] ?? '') ?? DateTime(2000);
            return fb.compareTo(fa);
          });

          final totalKilos = cosechas.fold<double>(
            0,
            (sum, c) => sum + (c['kilos'] ?? 0).toDouble(),
          );

          final Map<String, double> kilosPorLote = {};
          final Map<String, String> nombrePorLote = {};
          for (final c in cosechas) {
            final loteId = c['loteId'] ?? '';
            kilosPorLote[loteId] =
                (kilosPorLote[loteId] ?? 0) + (c['kilos'] ?? 0).toDouble();
            nombrePorLote[loteId] = c['loteNombre'] ?? '';
          }
          String loteTop = '-';
          double loteTopKilos = 0;
          kilosPorLote.forEach((id, kilos) {
            if (kilos > loteTopKilos) {
              loteTopKilos = kilos;
              loteTop = nombrePorLote[id] ?? '-';
            }
          });

          final recientes =
              cosechas.take(5).map((c) {
                final fecha =
                    DateTime.tryParse(c['fecha'] ?? '') ?? DateTime.now();
                return {
                  'titulo': 'Recolección registrada',
                  'subtitulo':
                      '${c['trabajadorNombre']} · ${c['loteNombre']} · ${(c['kilos'] ?? 0).toStringAsFixed(1)} kg',
                  'fecha': fecha,
                };
              }).toList();

          setState(() {
            _totalKilosFinca = totalKilos;
            _totalRegistros = cosechas.length;
            _loteTop = loteTop;
            _loteTopKilos = loteTopKilos;
            _actividadReciente = recientes;
          });
        });
  }

  void _onFincaChanged(FincaModel? finca) {
    if (finca == null) return;
    setState(() {
      _fincaSeleccionada = finca;
      _totalLotes = 0;
      _totalTrabajadores = 0;
      _loteTop = '-';
      _loteTopKilos = 0;
      _totalKilosFinca = 0;
      _totalRegistros = 0;
      _actividadReciente = [];
    });
    _escucharDatosFinca(finca);
  }

  Future<void> _abrirPrecioCafe() async {
    final uri = Uri.parse(
      'https://federaciondecafeteros.org/wp-content/uploads/2026/03/precio_cafe.pdf',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la página de precios'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    }
  }

  // ── Páginas ─────────────────────────────────────────────────────────────────

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return _buildHomeBody();
      case 1:
        return const VentasScreen();
      case 2:
        return const FincasScreen();
      case 3:
        return const RecoleccionScreen();
      case 4:
        return const EstadisticasScreen();
      default:
        return _buildHomeBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      body: _getPage(_currentIndex),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Home body ────────────────────────────────────────────────────────────────

  Widget _buildHomeBody() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      drawer: _buildDrawer(),
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            shadowColor: Colors.black12,
            surfaceTintColor: Colors.white,
            leading: Builder(
              builder:
                  (ctx) => IconButton(
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: AppColors.text,
                      size: 26,
                    ),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
            ),
            title: RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Cafe',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: 'Conecta',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.text,
                  size: 26,
                ),
                onPressed: () {},
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Bienvenida ─────────────────────────────────────────
                  _buildGreetingSection(),
                  const SizedBox(height: 16),

                  // ── Selector finca ─────────────────────────────────────
                  _buildFincaSelector(),
                  const SizedBox(height: 20),

                  // ── Tarjetas resumen ───────────────────────────────────
                  _buildSummaryGrid(),
                  const SizedBox(height: 24),

                  // ── Acciones rápidas ───────────────────────────────────
                  _sectionTitle('Acciones rápidas', Icons.bolt_outlined),
                  const SizedBox(height: 14),
                  _buildActionButtons(),
                  const SizedBox(height: 24),

                  // ── Tarjeta Ver Ventas ─────────────────────────────────
                  _buildVerVentasCard(),
                  const SizedBox(height: 24),

                  // ── Actividad reciente ─────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle(
                        'Actividad reciente',
                        Icons.history_outlined,
                      ),
                      TextButton(
                        onPressed: () => setState(() => _currentIndex = 3),
                        child: const Text(
                          'Ver todo',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildRecentActivity(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bienvenida ──────────────────────────────────────────────────────────────

  Widget _buildGreetingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar con inicial
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bienvenido de nuevo',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco_outlined, color: Colors.white70, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Caficultor · Colombia',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Selector de finca ───────────────────────────────────────────────────────

  Widget _buildFincaSelector() {
    if (_fincas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.landscape_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sin fincas registradas',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Registra tu primera finca para comenzar',
                    style: TextStyle(color: AppColors.textLight, fontSize: 11),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 2),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Agregar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FincaModel>(
          value: _fincaSeleccionada,
          isExpanded: true,
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          hint: const Text('Selecciona una finca'),
          items:
              _fincas.map((finca) {
                return DropdownMenuItem<FincaModel>(
                  value: finca,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.landscape_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              finca.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.text,
                              ),
                            ),
                            Text(
                              '${finca.municipio}, ${finca.departamento}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          selectedItemBuilder: (context) {
            return _fincas.map((finca) {
              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.landscape_outlined,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        finca.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        '${finca.municipio}, ${finca.departamento}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }).toList();
          },
          onChanged: _onFincaChanged,
        ),
      ),
    );
  }

  // ── Grid resumen ────────────────────────────────────────────────────────────

  Widget _buildSummaryGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.scale_outlined,
                iconColor: AppColors.primary,
                iconBg: const Color(0xFFE8F5E9),
                title: 'Total recolectado',
                value: '${_totalKilosFinca.toStringAsFixed(1)} kg',
                subtitle: '$_totalRegistros registros',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.grass_outlined,
                iconColor: const Color(0xFF00838F),
                iconBg: const Color(0xFFE0F7FA),
                title: 'Lotes activos',
                value: '$_totalLotes',
                subtitle: _fincaSeleccionada?.nombre ?? '-',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                icon: Icons.people_outline,
                iconColor: const Color(0xFF1565C0),
                iconBg: const Color(0xFFE3F2FD),
                title: 'Trabajadores',
                value: '$_totalTrabajadores',
                subtitle: 'en esta finca',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                icon: Icons.emoji_events_outlined,
                iconColor: const Color(0xFFF57F17),
                iconBg: const Color(0xFFFFF8E1),
                title: 'Lote top',
                value: _loteTop,
                subtitle:
                    _loteTopKilos > 0
                        ? '${_loteTopKilos.toStringAsFixed(0)} kg total'
                        : 'Sin datos',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: iconColor.withOpacity(0.6),
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppColors.textLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Botones de acción ───────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionBtn(
                icon: Icons.shopping_basket_outlined,
                label: 'Registrar\nCosecha',
                color: AppColors.primary,
                bgColor: const Color(0xFFE8F5E9),
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionBtn(
                icon: Icons.bar_chart_outlined,
                label: 'Ver\nRecolección',
                color: const Color(0xFF00838F),
                bgColor: const Color(0xFFE0F7FA),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VerRecoleccionScreen(),
                      ),
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionBtn(
                icon: Icons.coffee_outlined,
                label: 'Ver precio\ndel café',
                color: const Color(0xFF5D4037),
                bgColor: const Color(0xFFEFEBE9),
                onTap: _abrirPrecioCafe,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionBtn(
                icon: Icons.receipt_long_outlined,
                label: 'Liquidación\ntrabajadores',
                color: const Color(0xFF1565C0),
                bgColor: const Color(0xFFE3F2FD),
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LiquidacionScreen(),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Abrir',
                  style: TextStyle(
                    color: color.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: color.withOpacity(0.6),
                  size: 13,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tarjeta Ver Ventas ──────────────────────────────────────────────────────

  Widget _buildVerVentasCard() {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 1),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFC62828), Color(0xFFE53935)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.sell_outlined,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ver Ventas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Consulta y registra las ventas de tu café',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Abrir',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.secondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actividad reciente ──────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    if (_actividadReciente.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_outlined,
                  color: AppColors.primary.withOpacity(0.4),
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sin actividad reciente',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Las recolecciones registradas aparecerán aquí',
                style: TextStyle(color: AppColors.textLight, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children:
            _actividadReciente.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final fecha = item['fecha'] as DateTime;
              final meses = [
                'ene',
                'feb',
                'mar',
                'abr',
                'may',
                'jun',
                'jul',
                'ago',
                'sep',
                'oct',
                'nov',
                'dic',
              ];
              final timeStr =
                  '${fecha.day} ${meses[fecha.month - 1]}, ${_pad(fecha.hour)}:${_pad(fecha.minute)}';
              final isLast = i == _actividadReciente.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shopping_basket_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['titulo'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['subtitulo'] ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(height: 1, indent: 70, endIndent: 16),
                ],
              );
            }).toList(),
      ),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  // ── Drawer ──────────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Caficultor · Colombia',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _drawerItem(Icons.home_outlined, 'Inicio', () {
            Navigator.pop(context);
            setState(() => _currentIndex = 0);
          }),
          _drawerItem(Icons.landscape_outlined, 'Mis Fincas', () {
            Navigator.pop(context);
            setState(() => _currentIndex = 2);
          }),
          _drawerItem(Icons.shopping_basket_outlined, 'Recolección', () {
            Navigator.pop(context);
            setState(() => _currentIndex = 3);
          }),
          _drawerItem(Icons.bar_chart_outlined, 'Ver Recolección', () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VerRecoleccionScreen()),
            );
          }),
          _drawerItem(Icons.sell_outlined, 'Ventas', () {
            Navigator.pop(context);
            setState(() => _currentIndex = 1);
          }),
          _drawerItem(Icons.coffee_outlined, 'Precio del Café', () {
            Navigator.pop(context);
            _abrirPrecioCafe();
          }),
          _drawerItem(Icons.receipt_long_outlined, 'Liquidación', () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LiquidacionScreen()),
            );
          }),
          const Divider(),
          _drawerItem(Icons.logout, 'Cerrar sesión', () {
            Navigator.pop(context);
          }, color: AppColors.secondary),
        ],
      ),
    );
  }

  ListTile _drawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.text, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? AppColors.text,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  // ── Bottom Navigation ───────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sell_outlined),
            activeIcon: Icon(Icons.sell),
            label: 'Ventas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.landscape_outlined),
            activeIcon: Icon(Icons.landscape),
            label: 'Fincas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_basket_outlined),
            activeIcon: Icon(Icons.shopping_basket),
            label: 'Recolección',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Estadísticas',
          ),
        ],
      ),
    );
  }

  Widget _buildPageWrapper(String title, IconData icon, Color color) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: color.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Próximamente',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
