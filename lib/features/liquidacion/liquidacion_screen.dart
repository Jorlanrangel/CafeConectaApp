import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';

// ── Modelos locales (importa los tuyos si ya existen) ────────────────────────

class _Finca {
  final String id, nombre, municipio, departamento;
  _Finca({
    required this.id,
    required this.nombre,
    required this.municipio,
    required this.departamento,
  });
}

class _Trabajador {
  final String id, nombre, fincaId, fincaNombre;
  _Trabajador({
    required this.id,
    required this.nombre,
    required this.fincaId,
    required this.fincaNombre,
  });
}

class _Cosecha {
  final String id, trabajadorId, loteNombre, fincaId;
  final double kilos;
  final DateTime fecha;
  _Cosecha({
    required this.id,
    required this.trabajadorId,
    required this.loteNombre,
    required this.fincaId,
    required this.kilos,
    required this.fecha,
  });
}

// ── Pantalla principal ────────────────────────────────────────────────────────

class LiquidacionScreen extends StatefulWidget {
  const LiquidacionScreen({super.key});

  @override
  State<LiquidacionScreen> createState() => _LiquidacionScreenState();
}

class _LiquidacionScreenState extends State<LiquidacionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final _precioCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<_Finca> _fincas = [];
  List<_Trabajador> _trabajadores = [];
  List<_Cosecha> _cosechas = [];

  _Finca? _fincaSel;
  _Trabajador? _trabajadorSel;

  bool _loadingFincas = true;
  bool _loadingTrabajadores = false;
  bool _loadingCosechas = false;
  bool _liquidando = false;

  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // Totales calculados
  double get _totalKilos => _cosechas.fold(0, (sum, c) => sum + c.kilos);

  double get _precioPorKg =>
      double.tryParse(_precioCtrl.text.trim().replaceAll(',', '.')) ?? 0;

  double get _totalPagar => _totalKilos * _precioPorKg;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
    _cargarFincas();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

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
                    .map(
                      (d) => _Finca(
                        id: d.id,
                        nombre: d['nombre'] ?? '',
                        municipio: d['municipio'] ?? '',
                        departamento: d['departamento'] ?? '',
                      ),
                    )
                    .toList();
            _loadingFincas = false;
          });
        });
  }

  void _onFincaChanged(_Finca? finca) {
    setState(() {
      _fincaSel = finca;
      _trabajadorSel = null;
      _trabajadores = [];
      _cosechas = [];
      _precioCtrl.clear();
    });
    if (finca != null) _cargarTrabajadores(finca.id);
  }

  void _cargarTrabajadores(String fincaId) {
    setState(() => _loadingTrabajadores = true);
    _db
        .collection('usuarios')
        .doc(_uid)
        .collection('trabajadores')
        .where('fincaId', isEqualTo: fincaId)
        .orderBy('nombre')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          setState(() {
            _trabajadores =
                snap.docs
                    .map(
                      (d) => _Trabajador(
                        id: d.id,
                        nombre: d['nombre'] ?? '',
                        fincaId: d['fincaId'] ?? '',
                        fincaNombre: d['fincaNombre'] ?? '',
                      ),
                    )
                    .toList();
            _loadingTrabajadores = false;
          });
        });
  }

  void _onTrabajadorChanged(_Trabajador? t) {
    setState(() {
      _trabajadorSel = t;
      _cosechas = [];
      _precioCtrl.clear();
    });
    if (t != null && _fincaSel != null) {
      _cargarCosechas(t.id, _fincaSel!.id);
    }
  }

  void _cargarCosechas(String trabajadorId, String fincaId) {
    setState(() => _loadingCosechas = true);
    _db
        .collection('usuarios')
        .doc(_uid)
        .collection('cosechas')
        .where('trabajadorId', isEqualTo: trabajadorId)
        .where('fincaId', isEqualTo: fincaId)
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          final lista =
              snap.docs
                  .map(
                    (d) => _Cosecha(
                      id: d.id,
                      trabajadorId: d['trabajadorId'] ?? '',
                      loteNombre: d['loteNombre'] ?? '',
                      fincaId: d['fincaId'] ?? '',
                      kilos: (d['kilos'] ?? 0).toDouble(),
                      fecha:
                          DateTime.tryParse(d['fecha'] ?? '') ?? DateTime.now(),
                    ),
                  )
                  .toList();
          lista.sort((a, b) => b.fecha.compareTo(a.fecha));
          setState(() {
            _cosechas = lista;
            _loadingCosechas = false;
          });
        });
  }

  // ── Liquidar ────────────────────────────────────────────────────────────────

  Future<void> _liquidar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cosechas.isEmpty) {
      _snack('Este trabajador no tiene kilos registrados', error: true);
      return;
    }

    // Mostrar resumen antes de confirmar
    final confirmar = await _mostrarResumen();
    if (confirmar != true) return;

    setState(() => _liquidando = true);
    try {
      // Guardar registro de liquidación en Firestore
      await _db
          .collection('usuarios')
          .doc(_uid)
          .collection('liquidaciones')
          .add({
            'trabajadorId': _trabajadorSel!.id,
            'trabajadorNombre': _trabajadorSel!.nombre,
            'fincaId': _fincaSel!.id,
            'fincaNombre': _fincaSel!.nombre,
            'totalKilos': _totalKilos,
            'precioPorKg': _precioPorKg,
            'totalPagar': _totalPagar,
            'registros': _cosechas.length,
            'fecha': DateTime.now().toIso8601String(),
          });

      // Eliminar todos los registros de cosecha del trabajador en esta finca
      final batch = _db.batch();
      for (final c in _cosechas) {
        batch.delete(
          _db.collection('usuarios').doc(_uid).collection('cosechas').doc(c.id),
        );
      }
      await batch.commit();

      if (mounted) {
        _mostrarExito();
      }
    } catch (e) {
      _snack('Error al liquidar: $e', error: true);
    } finally {
      if (mounted) setState(() => _liquidando = false);
    }
  }

  // ── Diálogo resumen ──────────────────────────────────────────────────────────

  Future<bool?> _mostrarResumen() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Resumen de liquidación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Datos
                  _resumenRow(
                    Icons.person_outline,
                    'Trabajador',
                    _trabajadorSel!.nombre,
                  ),
                  _resumenRow(
                    Icons.landscape_outlined,
                    'Finca',
                    _fincaSel!.nombre,
                  ),
                  _resumenRow(
                    Icons.scale_outlined,
                    'Total kilos',
                    '${_totalKilos.toStringAsFixed(2)} kg',
                  ),
                  _resumenRow(
                    Icons.attach_money_outlined,
                    'Precio por kg',
                    _formatCOP(_precioPorKg),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(),
                  ),

                  // Total a pagar (destacado)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TOTAL A PAGAR',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatCOP(_totalPagar),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_cosechas.length} registros · ${_totalKilos.toStringAsFixed(2)} kg',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.secondary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Al finalizar, los kilos de este trabajador se pondrán en 0.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botones
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text(
                          'Confirmar y liquidar',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: AppColors.textLight),
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

  // ── Pantalla de éxito ────────────────────────────────────────────────────────

  void _mostrarExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Checkmark animado
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '¡Liquidación exitosa!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_trabajadorSel?.nombre ?? ''} ha sido liquidado correctamente.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Monto pagado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Monto pagado',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCOP(_totalPagar),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_totalKilos.toStringAsFixed(2)} kg · '
                          '${_formatCOP(_precioPorKg)}/kg',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botón finalizar
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // cierra diálogo
                      // Resetear selecciones
                      setState(() {
                        _fincaSel = null;
                        _trabajadorSel = null;
                        _trabajadores = [];
                        _cosechas = [];
                        _precioCtrl.clear();
                      });
                    },
                    icon: const Icon(Icons.home_outlined, size: 20),
                    label: const Text(
                      'Finalizar',
                      style: TextStyle(fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
          'Liquidación',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────
                _buildHeader(),
                const SizedBox(height: 24),

                // ── Paso 1: Seleccionar finca ──────────────────────────
                _stepLabel(
                  '1',
                  'Selecciona la finca',
                  Icons.landscape_outlined,
                ),
                const SizedBox(height: 12),
                _buildCard(
                  children: [
                    _loadingFincas
                        ? const _LoadingRow(texto: 'Cargando fincas...')
                        : _fincas.isEmpty
                        ? const _EmptyRow(texto: 'No tienes fincas registradas')
                        : _buildDropdownFinca(),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Paso 2: Seleccionar trabajador ─────────────────────
                _stepLabel(
                  '2',
                  'Selecciona el trabajador',
                  Icons.people_outline,
                ),
                const SizedBox(height: 12),
                _buildCard(
                  children: [
                    _fincaSel == null
                        ? const _EmptyRow(texto: 'Primero selecciona una finca')
                        : _loadingTrabajadores
                        ? const _LoadingRow(texto: 'Cargando trabajadores...')
                        : _trabajadores.isEmpty
                        ? const _EmptyRow(
                          texto: 'No hay trabajadores en esta finca',
                        )
                        : _buildDropdownTrabajador(),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Paso 3: Kilos recolectados ──────────────────────────
                if (_trabajadorSel != null) ...[
                  _stepLabel('3', 'Kilos recolectados', Icons.scale_outlined),
                  const SizedBox(height: 12),
                  _buildCard(
                    children: [
                      _loadingCosechas
                          ? const _LoadingRow(texto: 'Cargando registros...')
                          : _cosechas.isEmpty
                          ? const _EmptyRow(
                            texto: 'Este trabajador no tiene kilos registrados',
                          )
                          : _buildResumenKilos(),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Paso 4: Precio por kg ───────────────────────────────
                if (_trabajadorSel != null && _cosechas.isNotEmpty) ...[
                  _stepLabel(
                    '4',
                    'Precio por kilogramo',
                    Icons.attach_money_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildCard(
                    children: [
                      TextFormField(
                        controller: _precioCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                          LengthLimitingTextInputFormatter(10),
                        ],
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'Precio por kg de café',
                          hintText: '0',
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          suffixText: 'COP',
                          suffixStyle: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.attach_money_outlined,
                            color: AppColors.primary,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF7F9F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.error,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa el precio por kg';
                          }
                          final val = double.tryParse(v.trim());
                          if (val == null || val <= 0) {
                            return 'Ingresa un precio válido mayor a 0';
                          }
                          return null;
                        },
                      ),

                      // Preview del total en tiempo real
                      if (_precioPorKg > 0) ...[
                        const SizedBox(height: 16),
                        _buildPreviewTotal(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Botón liquidar ─────────────────────────────────
                  _liquidando
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                      : ElevatedButton.icon(
                        onPressed: _liquidar,
                        icon: const Icon(Icons.receipt_long_outlined, size: 22),
                        label: const Text(
                          'Liquidar trabajador',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: const Color(0xFF1565C0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets internos ─────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
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
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liquidación de Trabajadores',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Selecciona la finca y el trabajador para calcular el pago por los kilos recolectados',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFinca() {
    return DropdownButtonFormField<_Finca>(
      value: _fincaSel,
      isExpanded: true,
      decoration: _dropDeco('Finca', Icons.landscape_outlined),
      hint: const Text(
        'Selecciona una finca',
        style: TextStyle(fontSize: 14, color: AppColors.textLight),
      ),
      items:
          _fincas
              .map(
                (f) => DropdownMenuItem(
                  value: f,
                  child: Text(
                    '${f.nombre} · ${f.municipio}',
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              )
              .toList(),
      onChanged: _onFincaChanged,
      menuMaxHeight: 300,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildDropdownTrabajador() {
    return DropdownButtonFormField<_Trabajador>(
      value: _trabajadorSel,
      isExpanded: true,
      decoration: _dropDeco('Trabajador', Icons.person_outline),
      hint: const Text(
        'Selecciona un trabajador',
        style: TextStyle(fontSize: 14, color: AppColors.textLight),
      ),
      items:
          _trabajadores
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary.withOpacity(0.12),
                        child: Text(
                          t.nombre[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        t.nombre,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
      onChanged: _onTrabajadorChanged,
      menuMaxHeight: 300,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildResumenKilos() {
    return Column(
      children: [
        // Total kilos grande
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.scale_outlined,
                color: AppColors.primary,
                size: 30,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total kilos recolectados',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                  Text(
                    '${_totalKilos.toStringAsFixed(2)} kg',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_cosechas.length} reg.',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Lista de registros resumida
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _cosechas.length,
            itemBuilder: (_, i) {
              final c = _cosechas[i];
              final fecha = c.fecha;
              final fechaStr = '${fecha.day}/${fecha.month}/${fecha.year}';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.grass_outlined,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.loteNombre,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    Text(
                      fechaStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${c.kilos.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTotal() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kilos',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${_totalKilos.toStringAsFixed(2)} kg',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Precio/kg',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                _formatCOP(_precioPorKg),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Colors.white24),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL A PAGAR',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                _formatCOP(_totalPagar),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _stepLabel(String num, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF1565C0),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: const Color(0xFF1565C0), size: 18),
        const SizedBox(width: 8),
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

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  InputDecoration _dropDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
      filled: true,
      fillColor: const Color(0xFFF7F9F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _resumenRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCOP(double v) {
    final str = v.toStringAsFixed(0);
    final buffer = StringBuffer('\$');
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join('');
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: error ? AppColors.secondary : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _LoadingRow extends StatelessWidget {
  final String texto;
  const _LoadingRow({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(texto, style: const TextStyle(color: AppColors.textLight)),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String texto;
  const _EmptyRow({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textLight, size: 18),
          const SizedBox(width: 10),
          Text(
            texto,
            style: const TextStyle(color: AppColors.textLight, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
