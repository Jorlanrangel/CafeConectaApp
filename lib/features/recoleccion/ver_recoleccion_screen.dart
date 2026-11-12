import 'package:cafeconecta_aplication/fincas/finca_model.dart';
import 'package:cafeconecta_aplication/fincas/finca_service.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'cosecha_model.dart';
import 'recoleccion_service.dart';

class VerRecoleccionScreen extends StatefulWidget {
  const VerRecoleccionScreen({super.key});

  @override
  State<VerRecoleccionScreen> createState() => _VerRecoleccionScreenState();
}

class _VerRecoleccionScreenState extends State<VerRecoleccionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _buscarCtrl = TextEditingController();
  String _query = '';

  List<FincaModel> _fincas = [];
  FincaModel? _fincaSeleccionada;
  bool _loadingFincas = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _cargarFincas();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _buscarCtrl.dispose();
    super.dispose();
  }

  void _cargarFincas() {
    FincaService.obtenerFincas().listen((fincas) {
      if (mounted) {
        setState(() {
          _fincas = fincas;
          _loadingFincas = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Ver Recolección',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Por trabajador'),
            Tab(icon: Icon(Icons.history_outlined), text: 'Historial'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Selector de finca ────────────────────────────────────────
          _buildFincaSelector(),

          // ── Contenido según finca ────────────────────────────────────
          Expanded(
            child:
                _fincaSeleccionada == null
                    ? _buildSinFinca()
                    : StreamBuilder<List<CosechaModel>>(
                      stream: RecoleccionService.obtenerCosechasPorFinca(
                        _fincaSeleccionada!.id!,
                      ),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          );
                        }
                        final cosechas = snap.data ?? [];
                        return TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _buildPorTrabajador(cosechas),
                            _buildHistorial(cosechas),
                          ],
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // ── Selector de finca ───────────────────────────────────────────────────────

  Widget _buildFincaSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
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
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child:
          _loadingFincas
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Cargando fincas...',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  ],
                ),
              )
              : _fincas.isEmpty
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.landscape_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'No tienes fincas registradas',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  ],
                ),
              )
              : DropdownButtonHideUnderline(
                child: DropdownButton<FincaModel>(
                  value: _fincaSeleccionada,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                  ),
                  hint: const Row(
                    children: [
                      Icon(
                        Icons.landscape_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Selecciona una finca',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  items:
                      _fincas.map((finca) {
                        return DropdownMenuItem<FincaModel>(
                          value: finca,
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.landscape_outlined,
                                  color: AppColors.primary,
                                  size: 17,
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
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.landscape_outlined,
                              color: AppColors.primary,
                              size: 17,
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
                  onChanged: (finca) {
                    setState(() {
                      _fincaSeleccionada = finca;
                      _query = '';
                      _buscarCtrl.clear();
                    });
                  },
                ),
              ),
    );
  }

  // ── Pantalla sin finca seleccionada ─────────────────────────────────────────

  Widget _buildSinFinca() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.landscape_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Selecciona una finca',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Elige una finca para ver los kilos recolectados y el historial de cosechas',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Pestaña 1: Por trabajador ───────────────────────────────────────────────

  Widget _buildPorTrabajador(List<CosechaModel> cosechas) {
    final Map<String, double> totales = {};
    final Map<String, String> nombres = {};
    final Map<String, List<CosechaModel>> registrosPorTrabajador = {};

    for (final c in cosechas) {
      totales[c.trabajadorId] = (totales[c.trabajadorId] ?? 0) + c.kilos;
      nombres[c.trabajadorId] = c.trabajadorNombre;
      registrosPorTrabajador.putIfAbsent(c.trabajadorId, () => []).add(c);
    }

    for (final key in registrosPorTrabajador.keys) {
      registrosPorTrabajador[key]!.sort((a, b) => b.fecha.compareTo(a.fecha));
    }

    final filtrados =
        totales.entries
            .where(
              (e) =>
                  nombres[e.key]!.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final totalGeneral = cosechas.fold<double>(0, (sum, c) => sum + c.kilos);

    if (cosechas.isEmpty) {
      return _buildVacio(
        'Sin recolecciones en esta finca',
        'Registra cosechas para verlas aquí',
        Icons.shopping_basket_outlined,
      );
    }

    return Column(
      children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _buscarCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Buscar trabajador...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon:
                  _query.isNotEmpty
                      ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppColors.textLight,
                        ),
                        onPressed: () {
                          _buscarCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                      : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),

        // Tarjeta total general
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.scale_outlined, color: Colors.white, size: 32),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fincaSeleccionada?.nombre ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${totalGeneral.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Registros',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '${cosechas.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Lista por trabajador
        Expanded(
          child:
              filtrados.isEmpty
                  ? _buildVacio('Sin resultados', '', Icons.search_off)
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) {
                      final entry = filtrados[i];
                      final nombre = nombres[entry.key]!;
                      final kilos = entry.value;
                      final registros = registrosPorTrabajador[entry.key] ?? [];
                      final porcentaje =
                          totalGeneral > 0 ? kilos / totalGeneral : 0.0;

                      return GestureDetector(
                        onTap:
                            () => _abrirDetalleTrabajador(
                              context,
                              nombre,
                              kilos,
                              registros,
                            ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
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
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.12,
                                ),
                                child: Text(
                                  nombre[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            nombre,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.text,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '${registros.length} reg.',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: porcentaje,
                                        backgroundColor: AppColors.primary
                                            .withOpacity(0.1),
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                              AppColors.primary,
                                            ),
                                        minHeight: 6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(porcentaje * 100).toStringAsFixed(1)}% · Toca para ver detalle',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${kilos.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const Text(
                                    'kg',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textLight,
                                    size: 18,
                                  ),
                                ],
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
  }

  // ── Detalle trabajador ──────────────────────────────────────────────────────

  void _abrirDetalleTrabajador(
    BuildContext context,
    String nombre,
    double totalKilos,
    List<CosechaModel> registros,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (_, scrollCtrl) => Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F4F3),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.primary
                                      .withOpacity(0.12),
                                  child: Text(
                                    nombre[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      Text(
                                        '${registros.length} registros · ${_fincaSeleccionada?.nombre ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1B5E20),
                                    Color(0xFF43A047),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.scale_outlined,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total recolectado',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${totalKilos.toStringAsFixed(1)} kg',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Row(
                              children: [
                                Icon(
                                  Icons.history_outlined,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Historial de recolecciones',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                      Expanded(
                        child:
                            registros.isEmpty
                                ? const Center(
                                  child: Text(
                                    'Sin registros',
                                    style: TextStyle(
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  controller: scrollCtrl,
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    24,
                                  ),
                                  itemCount: registros.length,
                                  itemBuilder:
                                      (_, i) => _buildRegistroItem(
                                        registros[i],
                                        i + 1,
                                      ),
                                ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildRegistroItem(CosechaModel c, int numero) {
    final fecha = c.fecha;
    final meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final fechaStr =
        '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
    final horaStr =
        '${_pad(fecha.hour)}:${_pad(fecha.minute)}:${_pad(fecha.second)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$numero',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.fincaNombre} › ${c.loteNombre}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      fechaStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 11,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      horaStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${c.kilos.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const Text(
                'kg',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pestaña 2: Historial ────────────────────────────────────────────────────

  Widget _buildHistorial(List<CosechaModel> cosechas) {
    if (cosechas.isEmpty) {
      return _buildVacio(
        'Sin historial en esta finca',
        'Las cosechas registradas aparecerán aquí',
        Icons.history_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: cosechas.length,
      itemBuilder: (_, i) {
        final c = cosechas[i];
        final fecha = c.fecha;
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
        final fechaStr = '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
        final horaStr =
            '${_pad(fecha.hour)}:${_pad(fecha.minute)}:${_pad(fecha.second)}';

        return Dismissible(
          key: Key(c.id!),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, color: Colors.white, size: 28),
                Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder:
                  (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('¿Eliminar registro?'),
                    content: const Text('Esta acción no se puede deshacer.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                        ),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
            );
          },
          onDismissed: (_) async {
            await RecoleccionService.eliminarCosecha(c.id!);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_basket_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.trabajadorNombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.fincaNombre} › ${c.loteNombre}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 11,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            fechaStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.access_time,
                            size: 11,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            horaStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${c.kilos.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _buildVacio(String titulo, String subtitulo, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.primary.withOpacity(0.25)),
          const SizedBox(height: 14),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          if (subtitulo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitulo,
              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
