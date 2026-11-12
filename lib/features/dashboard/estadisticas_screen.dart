import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';

// ── Modelos de datos internos ─────────────────────────────────────────────────

class _Finca {
  final String id, nombre;
  _Finca({required this.id, required this.nombre});
}

class _StatData {
  // Cosechas
  double totalKilosSemana = 0;
  Map<String, double> kilosPorLote = {};
  Map<String, Map<int, double>> kilosPorLotePorDia = {}; // lote -> dia -> kilos
  Map<int, double> kilosPorDia = {}; // 0=lun..6=dom
  String loteMasProductivo = '-';
  double kilosLoteMasProductivo = 0;
  // Trabajadores
  String trabajadorMasProductivo = '-';
  double kilosTrabajadorTop = 0;
  // Ventas
  double totalVentasSemana = 0;
  int numVentas = 0;
  Map<String, double> ventasPorTipo = {};
  Map<int, double> ventasPorDia = {};
  double precioPromedio = 0;
  // Mensajes IA
  List<String> mensajes = [];
}

// ── Pantalla principal ────────────────────────────────────────────────────────

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  List<_Finca> _fincas = [];
  _Finca? _fincaSel;
  bool _loadingFincas = true;
  bool _loadingData = false;

  _StatData _data = _StatData();

  // Rango de fechas - esta semana por defecto
  late DateTime _desde;
  late DateTime _hasta;

  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static const List<String> _dias = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  static const Map<String, Color> _coloresTipo = {
    'Café Bueno': Color(0xFF2E7D32),
    'Pasilla': Color(0xFF1565C0),
    'Raspa': Color(0xFF6D4C41),
  };

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _initSemana();
    _cargarFincas();
  }

  void _initSemana() {
    final now = DateTime.now();
    final lunes = now.subtract(Duration(days: now.weekday - 1));
    _desde = DateTime(lunes.year, lunes.month, lunes.day);
    _hasta = _desde.add(const Duration(days: 6, hours: 23, minutes: 59));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Carga de datos ────────────────────────────────────────────────────────

  Future<void> _cargarFincas() async {
    _db
        .collection('usuarios')
        .doc(_uid)
        .collection('fincas')
        .orderBy('nombre')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          setState(() {
            _fincas =
                snap.docs
                    .map((d) => _Finca(id: d.id, nombre: d['nombre'] ?? ''))
                    .toList();
            _loadingFincas = false;
            if (_fincas.isNotEmpty && _fincaSel == null) {
              _fincaSel = _fincas.first;
              _cargarEstadisticas();
            }
          });
        });
  }

  Future<void> _cargarEstadisticas() async {
    if (_fincaSel == null) return;
    setState(() => _loadingData = true);
    _animCtrl.reset();

    final data = _StatData();

    try {
      await Future.wait([_procesarCosechas(data), _procesarVentas(data)]);
      _generarMensajes(data);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _data = data;
        _loadingData = false;
      });
      _animCtrl.forward();
    }
  }

  Future<void> _procesarCosechas(_StatData data) async {
    final snap =
        await _db
            .collection('usuarios')
            .doc(_uid)
            .collection('cosechas')
            .where('fincaId', isEqualTo: _fincaSel!.id)
            .get();

    for (final doc in snap.docs) {
      final d = doc.data();
      final fecha = DateTime.tryParse(d['fecha'] ?? '');
      if (fecha == null) continue;
      if (fecha.isBefore(_desde) || fecha.isAfter(_hasta)) continue;

      final kilos = (d['kilos'] ?? 0).toDouble();
      final lote = d['loteNombre'] ?? 'Sin lote';
      final trabajador = d['trabajadorNombre'] ?? '';
      final dia = fecha.weekday - 1; // 0=lun

      data.totalKilosSemana += kilos;
      data.kilosPorLote[lote] = (data.kilosPorLote[lote] ?? 0) + kilos;
      data.kilosPorDia[dia] = (data.kilosPorDia[dia] ?? 0) + kilos;

      data.kilosPorLotePorDia.putIfAbsent(lote, () => {});
      data.kilosPorLotePorDia[lote]![dia] =
          (data.kilosPorLotePorDia[lote]![dia] ?? 0) + kilos;

      // Top trabajador
      if (kilos > data.kilosTrabajadorTop && trabajador.isNotEmpty) {
        data.kilosTrabajadorTop = kilos;
        data.trabajadorMasProductivo = trabajador;
      }
    }

    // Lote más productivo
    if (data.kilosPorLote.isNotEmpty) {
      final top = data.kilosPorLote.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      data.loteMasProductivo = top.key;
      data.kilosLoteMasProductivo = top.value;
    }
  }

  Future<void> _procesarVentas(_StatData data) async {
    final snap =
        await _db
            .collection('usuarios')
            .doc(_uid)
            .collection('ventas')
            .where('fincaId', isEqualTo: _fincaSel!.id)
            .get();

    double sumPrecios = 0;
    int countPrecios = 0;

    for (final doc in snap.docs) {
      final d = doc.data();
      final fecha = DateTime.tryParse(d['fecha'] ?? '');
      if (fecha == null) continue;
      if (fecha.isBefore(_desde) || fecha.isAfter(_hasta)) continue;

      final total = (d['totalPagar'] ?? 0).toDouble();
      final dia = fecha.weekday - 1;

      data.totalVentasSemana += total;
      data.numVentas++;
      data.ventasPorDia[dia] = (data.ventasPorDia[dia] ?? 0) + total;

      // Items por tipo
      final items = d['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final tipo = item['tipoCafe'] ?? '';
        final subtotal = (item['subtotal'] ?? 0).toDouble();
        final precio = (item['precioPorLata'] ?? 0).toDouble();
        data.ventasPorTipo[tipo] = (data.ventasPorTipo[tipo] ?? 0) + subtotal;
        if (precio > 0) {
          sumPrecios += precio;
          countPrecios++;
        }
      }
    }

    data.precioPromedio = countPrecios > 0 ? sumPrecios / countPrecios : 0;
  }

  void _generarMensajes(_StatData data) {
    final msgs = <String>[];
    if (data.loteMasProductivo != '-') {
      msgs.add(
        '🏆 El lote "${data.loteMasProductivo}" fue el más productivo '
        'con ${data.kilosLoteMasProductivo.toStringAsFixed(1)} kg esta semana.',
      );
    }
    if (data.totalVentasSemana > 0) {
      msgs.add(
        '💰 Las ventas totales de la semana suman '
        '${_formatCOP(data.totalVentasSemana)}.',
      );
    }
    if (data.ventasPorTipo.isNotEmpty) {
      final topTipo = data.ventasPorTipo.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      final total = data.ventasPorTipo.values.fold(0.0, (s, v) => s + v);
      final pct =
          total > 0 ? (topTipo.value / total * 100).toStringAsFixed(0) : '0';
      msgs.add('☕ El ${topTipo.key} representa el $pct% de las ventas.');
    }
    if (data.trabajadorMasProductivo != '-') {
      msgs.add(
        '👷 ${data.trabajadorMasProductivo} fue el trabajador más '
        'productivo con ${data.kilosTrabajadorTop.toStringAsFixed(1)} kg.',
      );
    }
    if (msgs.isEmpty) {
      msgs.add(
        '📊 No hay suficientes datos para esta semana. '
        'Registra cosechas y ventas para ver estadísticas.',
      );
    }
    data.mensajes = msgs;
  }

  // ── Selector de fechas ────────────────────────────────────────────────────

  Future<void> _seleccionarRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
      builder:
          (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
    );
    if (rango != null && mounted) {
      setState(() {
        _desde = rango.start;
        _hasta = DateTime(
          rango.end.year,
          rango.end.month,
          rango.end.day,
          23,
          59,
          59,
        );
      });
      _cargarEstadisticas();
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      body:
          _loadingFincas
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : _fincas.isEmpty
              ? _buildSinFincas()
              : CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child:
                        _loadingData
                            ? const Padding(
                              padding: EdgeInsets.only(top: 80),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                            : FadeTransition(
                              opacity: _fadeAnim,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  30,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 16),
                                    _buildMensajesIA(),
                                    const SizedBox(height: 20),
                                    _buildIndicadoresPrincipales(),
                                    const SizedBox(height: 20),
                                    _buildResumenCards(),
                                    const SizedBox(height: 20),
                                    _buildSectionTitle(
                                      'Ventas por tipo de café',
                                      Icons.pie_chart_outline,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildPieChart(),
                                    const SizedBox(height: 20),
                                    _buildSectionTitle(
                                      'Ventas totales semanales',
                                      Icons.show_chart,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildVentasLineChart(),
                                    const SizedBox(height: 20),
                                    _buildSectionTitle(
                                      'Recolección semanal por lote',
                                      Icons.grass_outlined,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildRecoleccionLineChart(),
                                  ],
                                ),
                              ),
                            ),
                  ),
                ],
              ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      automaticallyImplyLeading: false,
      expandedHeight: 160,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Estadísticas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Resumen general de producción y ventas',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Selector de finca
                  Expanded(
                    child:
                        _fincas.length == 1
                            ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _fincaSel?.nombre ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            )
                            : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<_Finca>(
                                  value: _fincaSel,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2E7D32),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  items:
                                      _fincas
                                          .map(
                                            (f) => DropdownMenuItem(
                                              value: f,
                                              child: Text(
                                                f.nombre,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (f) {
                                    setState(() => _fincaSel = f);
                                    _cargarEstadisticas();
                                  },
                                ),
                              ),
                            ),
                  ),
                  const SizedBox(width: 8),
                  // Botón rango fechas
                  GestureDetector(
                    onTap: _seleccionarRango,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.date_range_outlined,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_desde.day}/${_desde.month} - '
                            '${_hasta.day}/${_hasta.month}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

  // ── Mensajes IA ────────────────────────────────────────────────────────────

  Widget _buildMensajesIA() {
    if (_data.mensajes.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.lightbulb_outline,
                color: AppColors.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Inteligencia de datos',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            Text(
              'Desliza para descartar',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textLight.withOpacity(0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SwipeCards(mensajes: _data.mensajes),
      ],
    );
  }
  // ── Indicadores principales ───────────────────────────────────────────────

  Widget _buildIndicadoresPrincipales() {
    return Row(
      children: [
        Expanded(
          child: _TopCard(
            icon: Icons.emoji_events_outlined,
            iconColor: const Color(0xFFF57F17),
            iconBg: const Color(0xFFFFF8E1),
            titulo: 'Lote top',
            valor: _data.loteMasProductivo,
            subtitulo:
                _data.kilosLoteMasProductivo > 0
                    ? '${_data.kilosLoteMasProductivo.toStringAsFixed(1)} kg'
                    : 'Sin datos',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TopCard(
            icon: Icons.star_outline_rounded,
            iconColor: const Color(0xFF1565C0),
            iconBg: const Color(0xFFE3F2FD),
            titulo: 'Trabajador top',
            valor: _data.trabajadorMasProductivo,
            subtitulo:
                _data.kilosTrabajadorTop > 0
                    ? '${_data.kilosTrabajadorTop.toStringAsFixed(1)} kg'
                    : 'Sin datos',
          ),
        ),
      ],
    );
  }

  // ── Resumen cards ─────────────────────────────────────────────────────────

  Widget _buildResumenCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _ResumenCard(
          icon: Icons.scale_outlined,
          titulo: 'Recolección semana',
          valor: '${_data.totalKilosSemana.toStringAsFixed(1)} kg',
          color: AppColors.primary,
          bg: const Color(0xFFE8F5E9),
        ),
        _ResumenCard(
          icon: Icons.attach_money_outlined,
          titulo: 'Ventas semana',
          valor: _formatCOP(_data.totalVentasSemana),
          color: AppColors.secondary,
          bg: const Color(0xFFFFEBEE),
        ),
        _ResumenCard(
          icon: Icons.coffee_outlined,
          titulo: 'Precio promedio',
          valor:
              _data.precioPromedio > 0
                  ? '${_formatCOP(_data.precioPromedio)}/lata'
                  : 'Sin datos',
          color: const Color(0xFF6D4C41),
          bg: const Color(0xFFEFEBE9),
        ),
        _ResumenCard(
          icon: Icons.receipt_outlined,
          titulo: 'Núm. de ventas',
          valor: '${_data.numVentas}',
          color: const Color(0xFF1565C0),
          bg: const Color(0xFFE3F2FD),
        ),
      ],
    );
  }

  // ── Gráfica de torta: Ventas por tipo ────────────────────────────────────

  Widget _buildPieChart() {
    final tipos = _data.ventasPorTipo;
    if (tipos.isEmpty) return _buildEmpty('Sin ventas registradas');

    final total = tipos.values.fold(0.0, (s, v) => s + v);
    final sections =
        tipos.entries.map((e) {
          final pct = total > 0 ? e.value / total * 100 : 0.0;
          final color = _coloresTipo[e.key] ?? AppColors.primary;
          return PieChartSectionData(
            value: e.value,
            color: color,
            title: '${pct.toStringAsFixed(0)}%',
            radius: 70,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: pct < 8 ? null : null,
          );
        }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 44,
                sectionsSpace: 3,
                pieTouchData: PieTouchData(enabled: true),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Leyenda
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children:
                tipos.entries.map((e) {
                  final color = _coloresTipo[e.key] ?? AppColors.primary;
                  final pct =
                      total > 0
                          ? (e.value / total * 100).toStringAsFixed(1)
                          : '0';
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${e.key} ($pct%)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Gráfica de línea: Ventas semanales ───────────────────────────────────

  Widget _buildVentasLineChart() {
    final ventas = _data.ventasPorDia;
    final maxVal =
        ventas.values.isEmpty
            ? 1000.0
            : ventas.values.reduce((a, b) => a > b ? a : b) * 1.3;

    final spots = List.generate(7, (i) => FlSpot(i.toDouble(), ventas[i] ?? 0));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: _cardDeco(shadowColor: AppColors.secondary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ingresos diarios (COP)',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              Text(
                _formatCOP(_data.totalVentasSemana),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxVal,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine:
                      (v) => FlLine(
                        color: Colors.grey.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget:
                          (v, _) => Text(
                            v >= 1000000
                                ? '${(v / 1000000).toStringAsFixed(1)}M'
                                : v >= 1000
                                ? '${(v / 1000).toStringAsFixed(0)}k'
                                : v.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textLight,
                            ),
                          ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= 7) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _dias[i],
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textLight,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.secondary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter:
                          (s, _, __, ___) => FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.secondary,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondary.withOpacity(0.18),
                          AppColors.secondary.withOpacity(0.01),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gráfica de líneas múltiple: Recolección por lote ────────────────────

  Widget _buildRecoleccionLineChart() {
    final lotes = _data.kilosPorLotePorDia;
    if (lotes.isEmpty) return _buildEmpty('Sin recolecciones registradas');

    // Colores para cada lote
    final coloresLote = [
      AppColors.primary,
      const Color(0xFF1565C0),
      const Color(0xFFF57F17),
      const Color(0xFF6D4C41),
      const Color(0xFF6A1B9A),
      const Color(0xFF00838F),
    ];

    final loteKeys = lotes.keys.toList();
    double maxY = 10;
    for (final lote in lotes.values) {
      for (final v in lote.values) {
        if (v > maxY) maxY = v;
      }
    }
    maxY *= 1.3;

    final barras =
        loteKeys.asMap().entries.map((entry) {
          final idx = entry.key;
          final lote = entry.value;
          final color = coloresLote[idx % coloresLote.length];
          final spots = List.generate(
            7,
            (i) => FlSpot(i.toDouble(), lotes[lote]?[i] ?? 0),
          );
          return LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter:
                  (s, _, __, ___) => FlDotCirclePainter(
                    radius: 3.5,
                    color: color,
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.05),
            ),
          );
        }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total: ${_data.totalKilosSemana.toStringAsFixed(1)} kg',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine:
                      (v) => FlLine(
                        color: Colors.grey.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget:
                          (v, _) => Text(
                            v >= 1000
                                ? '${(v / 1000).toStringAsFixed(1)}k'
                                : v.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textLight,
                            ),
                          ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= 7) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _dias[i],
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textLight,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: barras,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Leyenda de lotes
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children:
                loteKeys.asMap().entries.map((e) {
                  final color = coloresLote[e.key % coloresLote.length];
                  final kg = _data.kilosPorLote[e.value] ?? 0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 3,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${e.value} (${kg.toStringAsFixed(1)} kg)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(String msg) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _cardDeco(),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 48,
              color: AppColors.primary.withOpacity(0.2),
            ),
            const SizedBox(height: 12),
            Text(
              msg,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinFincas() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.landscape_outlined,
            size: 72,
            color: AppColors.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No tienes fincas registradas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Registra una finca para ver estadísticas',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco({Color? shadowColor}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: (shadowColor ?? Colors.black).withOpacity(0.06),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

// ── Widgets reutilizables ─────────────────────────────────────────────────────

class _TopCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String titulo, valor, subtitulo;

  const _TopCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.titulo,
    required this.valor,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            valor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: iconColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final IconData icon;
  final String titulo, valor;
  final Color color, bg;

  const _ResumenCard({
    required this.icon,
    required this.titulo,
    required this.valor,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            titulo,
            style: const TextStyle(fontSize: 10, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

String _formatCOP(double v) {
  if (v == 0) return '\$0';
  final str = v.toStringAsFixed(0);
  final buf = StringBuffer('\$');
  int c = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    if (c > 0 && c % 3 == 0) buf.write('.');
    buf.write(str[i]);
    c++;
  }
  return buf.toString().split('').reversed.join('');
}

class _SwipeCards extends StatefulWidget {
  final List<String> mensajes;
  const _SwipeCards({required this.mensajes});

  @override
  State<_SwipeCards> createState() => _SwipeCardsState();
}

class _SwipeCardsState extends State<_SwipeCards>
    with TickerProviderStateMixin {
  late List<String> _cards;
  late AnimationController _swipeCtrl;
  late Animation<Offset> _swipeAnim;
  late Animation<double> _fadeAnim;
  Offset _dragOffset = Offset.zero;
  bool _swiping = false;

  final _iconos = [
    Icons.emoji_events_outlined,
    Icons.attach_money_outlined,
    Icons.coffee_outlined,
    Icons.person_outline,
    Icons.bar_chart_outlined,
  ];

  final _colores = [
    const Color(0xFFF57F17),
    AppColors.secondary,
    const Color(0xFF6D4C41),
    const Color(0xFF1565C0),
    AppColors.primary,
  ];

  final _bgs = [
    const Color(0xFFFFF8E1),
    const Color(0xFFFFEBEE),
    const Color(0xFFEFEBE9),
    const Color(0xFFE3F2FD),
    const Color(0xFFE8F5E9),
  ];

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.mensajes);
    _swipeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swipeAnim = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_swipeCtrl);
    _fadeAnim = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _swipeCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_swiping) return;
    setState(() => _dragOffset += Offset(d.delta.dx, d.delta.dy * 0.3));
  }

  void _onDragEnd(DragEndDetails d) async {
    if (_swiping || _cards.isEmpty) return;
    final vx = d.velocity.pixelsPerSecond.dx;
    final shouldDismiss = _dragOffset.dx.abs() > 80 || vx.abs() > 400;

    if (shouldDismiss) {
      _swiping = true;
      final dir = (_dragOffset.dx > 0 || vx > 0) ? 1.0 : -1.0;
      _swipeAnim = Tween<Offset>(
        begin: _dragOffset,
        end: Offset(dir * 400, _dragOffset.dy),
      ).animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOut));

      await _swipeCtrl.forward();
      if (mounted) {
        setState(() {
          _cards.removeAt(0);
          _dragOffset = Offset.zero;
          _swiping = false;
        });
        _swipeCtrl.reset();
      }
    } else {
      // Volver al centro
      _swipeAnim = Tween<Offset>(
        begin: _dragOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.elasticOut));
      await _swipeCtrl.forward();
      if (mounted) {
        setState(() => _dragOffset = Offset.zero);
        _swipeCtrl.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.primary.withOpacity(0.4),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                '¡Revisaste todos los insights!',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight.withOpacity(0.7),
                ),
              ),
              TextButton(
                onPressed:
                    () => setState(() => _cards = List.from(widget.mensajes)),
                child: const Text(
                  'Ver de nuevo',
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cartas de fondo (máx 3)
          for (int i = _cards.length - 1; i >= 1; i--) ...[
            if (i <= 3)
              _buildCard(
                i,
                offset: Offset(0, (i * -6).toDouble()),
                scale: 1.0 - (i * 0.04),
                isDraggable: false,
              ),
          ],

          // Carta del frente (draggable)
          AnimatedBuilder(
            animation: _swipeCtrl,
            builder: (_, __) {
              final offset = _swiping ? _swipeAnim.value : _dragOffset;
              final angle = offset.dx / 600;
              final opacity =
                  _swiping
                      ? _fadeAnim.value
                      : 1.0 - (_dragOffset.dx.abs() / 300).clamp(0.0, 0.5);

              return Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: angle,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: GestureDetector(
                      onPanUpdate: _onDragUpdate,
                      onPanEnd: _onDragEnd,
                      child: _buildCard(
                        0,
                        offset: Offset.zero,
                        scale: 1.0,
                        isDraggable: true,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Indicador de dirección al arrastrar
          if (_dragOffset.dx.abs() > 40 && !_swiping)
            Positioned(
              top: 16,
              left: _dragOffset.dx > 0 ? null : 16,
              right: _dragOffset.dx > 0 ? 16 : null,
              child: AnimatedOpacity(
                opacity: (_dragOffset.dx.abs() / 100).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 100),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _dragOffset.dx > 0
                            ? AppColors.primary
                            : AppColors.secondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _dragOffset.dx > 0 ? '✓ OK' : '✕ Skip',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(
    int idx, {
    required Offset offset,
    required double scale,
    required bool isDraggable,
  }) {
    if (idx >= _cards.length) return const SizedBox();
    final color = _colores[idx % _colores.length];
    final bg = _bgs[idx % _bgs.length];
    final icon = _iconos[idx % _iconos.length];

    return Transform.translate(
      offset: offset,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: double.infinity,
          height: 130,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isDraggable ? 0.2 : 0.08),
                blurRadius: isDraggable ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _cards[idx],
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isDraggable) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.swipe,
                            size: 12,
                            color: AppColors.textLight.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_cards.length} insights',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textLight.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
