import 'package:cafeconecta_aplication/features/ventas/ventas_model.dart';
import 'package:cafeconecta_aplication/features/ventas/ventas_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';

// ── Modelo finca local ────────────────────────────────────────────────────────
class _Finca {
  final String id, nombre, municipio, departamento;
  _Finca({
    required this.id,
    required this.nombre,
    required this.municipio,
    required this.departamento,
  });
}

const List<String> _tiposCafe = ['Café Bueno', 'Pasilla', 'Raspa'];

const Map<String, Color> _coloresTipo = {
  'Café Bueno': Color(0xFF1B5E20),
  'Pasilla': Color(0xFF1565C0),
  'Raspa': Color(0xFF6D4C41),
};

const Map<String, Color> _bgTipo = {
  'Café Bueno': Color(0xFFE8F5E9),
  'Pasilla': Color(0xFFE3F2FD),
  'Raspa': Color(0xFFEFEBE9),
};

// ── Pantalla principal de Ventas ──────────────────────────────────────────────
class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Ventas de Café',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.secondary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.secondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Registrar venta'),
            Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Ver ventas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [_RegistrarVentaTab(), _VerVentasTab()],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — REGISTRAR VENTA
// ══════════════════════════════════════════════════════════════════════════════

class _RegistrarVentaTab extends StatefulWidget {
  const _RegistrarVentaTab();

  @override
  State<_RegistrarVentaTab> createState() => _RegistrarVentaTabState();
}

class _RegistrarVentaTabState extends State<_RegistrarVentaTab> {
  final _formKey = GlobalKey<FormState>();
  final _vendCtrl = TextEditingController();

  List<_Finca> _fincas = [];
  _Finca? _fincaSel;
  bool _loadingFincas = true;
  bool _guardando = false;

  // Items de venta dinámicos
  final List<_ItemRow> _items = [];

  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _cargarFincas();
    _agregarItem(); // primer item por defecto
  }

  @override
  void dispose() {
    _vendCtrl.dispose();
    for (final i in _items) i.dispose();
    super.dispose();
  }

  void _cargarFincas() {
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

  void _agregarItem() {
    setState(() => _items.add(_ItemRow()));
  }

  void _quitarItem(int idx) {
    if (_items.length == 1) return;
    setState(() {
      _items[idx].dispose();
      _items.removeAt(idx);
    });
  }

  double get _totalLatas =>
      _items.fold(0, (s, i) => s + (double.tryParse(i.latasCtrl.text) ?? 0));

  double get _totalPagar => _items.fold(0, (s, i) => s + i.subtotal);

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fincaSel == null) {
      _snack('Selecciona una finca', error: true);
      return;
    }
    // Validar items
    for (int i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.tipoCafe == null) {
        _snack('Selecciona el tipo de café en el item ${i + 1}', error: true);
        return;
      }
      if ((double.tryParse(it.latasCtrl.text) ?? 0) <= 0) {
        _snack('Ingresa las latas en el item ${i + 1}', error: true);
        return;
      }
      if ((double.tryParse(it.precioCtrl.text) ?? 0) <= 0) {
        _snack('Ingresa el precio en el item ${i + 1}', error: true);
        return;
      }
    }

    setState(() => _guardando = true);
    try {
      final itemsModel =
          _items
              .map(
                (i) => ItemVenta(
                  tipoCafe: i.tipoCafe!,
                  latas: double.parse(i.latasCtrl.text),
                  precioPorLata: double.parse(i.precioCtrl.text),
                ),
              )
              .toList();

      await VentaService.guardarVenta(
        VentaModel(
          fincaId: _fincaSel!.id,
          fincaNombre: _fincaSel!.nombre,
          vendedor: _vendCtrl.text.trim(),
          items: itemsModel,
          totalLatas: _totalLatas,
          totalPagar: _totalPagar,
          fecha: DateTime.now(),
        ),
      );

      if (mounted) {
        _snack('¡Venta registrada exitosamente!');
        // Resetear formulario
        setState(() {
          _fincaSel = null;
          _vendCtrl.clear();
          for (final i in _items) i.dispose();
          _items.clear();
          _items.add(_ItemRow());
        });
      }
    } catch (e) {
      _snack('Error al guardar: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            _buildHeader(),
            const SizedBox(height: 22),

            // ── Paso 1: Finca ──
            _stepLabel('1', 'Finca', Icons.landscape_outlined),
            const SizedBox(height: 10),
            _buildCard(
              children: [
                _loadingFincas
                    ? const _LoadingRow('Cargando fincas...')
                    : _fincas.isEmpty
                    ? const _EmptyRow('No tienes fincas registradas')
                    : DropdownButtonFormField<_Finca>(
                      value: _fincaSel,
                      isExpanded: true,
                      decoration: _deco('Finca', Icons.landscape_outlined),
                      hint: const Text(
                        'Selecciona una finca',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textLight,
                        ),
                      ),
                      items:
                          _fincas
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(
                                    '${f.nombre} · ${f.municipio}',
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (f) => setState(() => _fincaSel = f),
                      menuMaxHeight: 280,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.secondary,
                      ),
                      validator:
                          (v) => v == null ? 'Selecciona una finca' : null,
                    ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Paso 2: Items de café ──
            _stepLabel('2', 'Tipo de café y cantidades', Icons.coffee_outlined),
            const SizedBox(height: 10),

            // Items dinámicos
            ...List.generate(_items.length, (idx) {
              return _buildItemCard(idx);
            }),

            // Botón agregar item
            TextButton.icon(
              onPressed: _agregarItem,
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.secondary,
              ),
              label: const Text(
                'Agregar otro tipo de café',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Preview total
            if (_totalPagar > 0) ...[
              const SizedBox(height: 8),
              _buildPreviewTotal(),
            ],
            const SizedBox(height: 20),

            // ── Paso 3: Vendedor ──
            _stepLabel('3', 'Nombre del Comprador', Icons.person_outline),
            const SizedBox(height: 10),
            _buildCard(
              children: [
                TextFormField(
                  controller: _vendCtrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(60)],
                  decoration: _deco(
                    'Nombre del Comprador',
                    Icons.person_outline,
                  ),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Ingresa el nombre del Comprador'
                              : null,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Botón guardar ──
            _guardando
                ? const Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                )
                : ElevatedButton.icon(
                  onPressed: _guardar,
                  icon: const Icon(Icons.save_outlined, size: 22),
                  label: const Text(
                    'Registrar venta',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    backgroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int idx) {
    final item = _items[idx];
    return AnimatedBuilder(
      animation: Listenable.merge([item.latasCtrl, item.precioCtrl]),
      builder: (_, __) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border:
                item.tipoCafe != null
                    ? Border.all(
                      color: (_coloresTipo[item.tipoCafe!] ?? AppColors.primary)
                          .withOpacity(0.3),
                      width: 1.5,
                    )
                    : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header del item
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Item ${idx + 1}',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_items.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.secondary,
                        size: 22,
                      ),
                      onPressed: () => _quitarItem(idx),
                      tooltip: 'Quitar item',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Tipo de café
              DropdownButtonFormField<String>(
                value: item.tipoCafe,
                isExpanded: true,
                decoration: _deco('Tipo de café', Icons.coffee_outlined),
                hint: const Text(
                  'Selecciona el tipo',
                  style: TextStyle(fontSize: 14, color: AppColors.textLight),
                ),
                items:
                    _tiposCafe
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: _coloresTipo[t],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(t, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => item.tipoCafe = v),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 12),

              // Latas y precio en fila
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: item.latasCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                        LengthLimitingTextInputFormatter(8),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: _deco(
                        'Latas',
                        Icons.scale_outlined,
                      ).copyWith(suffixText: 'latas'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: item.precioCtrl,
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
                      decoration: _deco(
                        'Precio/lata',
                        Icons.attach_money_outlined,
                      ).copyWith(
                        prefixText: '\$ ',
                        prefixStyle: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Subtotal del item
              if (item.subtotal > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (item.tipoCafe != null
                            ? _bgTipo[item.tipoCafe!]
                            : AppColors.primary.withOpacity(0.06)) ??
                        AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.tipoCafe != null
                            ? '${item.tipoCafe} · '
                                '${double.tryParse(item.latasCtrl.text)?.toStringAsFixed(1) ?? '0'} latas'
                            : 'Subtotal',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              item.tipoCafe != null
                                  ? _coloresTipo[item.tipoCafe!]
                                  : AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatCOP(item.subtotal),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color:
                              item.tipoCafe != null
                                  ? _coloresTipo[item.tipoCafe!]
                                  : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreviewTotal() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_outlined, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total venta',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  _formatCOP(_totalPagar),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Total latas',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                '${_totalLatas.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sell_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar Venta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Agrega los tipos de café, cantidades y precios',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLabel(String num, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.secondary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: AppColors.secondary, size: 17),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.secondary, size: 20),
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
        borderSide: const BorderSide(color: AppColors.secondary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ── Item row helper ───────────────────────────────────────────────────────────
class _ItemRow {
  String? tipoCafe;
  final latasCtrl = TextEditingController();
  final precioCtrl = TextEditingController();

  double get subtotal {
    final l = double.tryParse(latasCtrl.text) ?? 0;
    final p = double.tryParse(precioCtrl.text) ?? 0;
    return l * p;
  }

  void dispose() {
    latasCtrl.dispose();
    precioCtrl.dispose();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — VER VENTAS
// ══════════════════════════════════════════════════════════════════════════════

class _VerVentasTab extends StatefulWidget {
  const _VerVentasTab();

  @override
  State<_VerVentasTab> createState() => _VerVentasTabState();
}

class _VerVentasTabState extends State<_VerVentasTab> {
  List<_Finca> _fincas = [];
  _Finca? _fincaSel;
  bool _loadingFincas = true;

  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Selector de finca ──
        _buildSelectorFinca(),

        // ── Contenido ──
        Expanded(
          child:
              _fincaSel == null
                  ? _buildSinFinca()
                  : StreamBuilder<List<VentaModel>>(
                    stream: VentaService.obtenerVentasPorFinca(_fincaSel!.id),
                    builder: (_, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.secondary,
                          ),
                        );
                      }
                      final ventas = snap.data ?? [];
                      if (ventas.isEmpty) return _buildVacio();
                      return _buildListaVentas(ventas);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildSelectorFinca() {
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
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
      ),
      child:
          _loadingFincas
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: _LoadingRow('Cargando fincas...'),
              )
              : _fincas.isEmpty
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: _EmptyRow('No tienes fincas registradas'),
              )
              : DropdownButtonHideUnderline(
                child: DropdownButton<_Finca>(
                  value: _fincaSel,
                  isExpanded: true,
                  hint: const Row(
                    children: [
                      Icon(
                        Icons.landscape_outlined,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Selecciona una finca para ver ventas',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.secondary,
                  ),
                  items:
                      _fincas
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Text(
                                f.nombre,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (f) => setState(() => _fincaSel = f),
                ),
              ),
    );
  }

  Widget _buildListaVentas(List<VentaModel> ventas) {
    // Totales
    final totalGeneral = ventas.fold(0.0, (s, v) => s + v.totalPagar);
    final totalLatas = ventas.fold(0.0, (s, v) => s + v.totalLatas);

    return Column(
      children: [
        // ── Resumen total (recuadro grande) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.bar_chart_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ventas totales · ${_fincaSel!.nombre}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total recaudado',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        Text(
                          _formatCOP(totalGeneral),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Latas vendidas',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        Text(
                          '${totalLatas.toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'latas',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Distribución por tipo
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children:
                      _tiposCafe.map((tipo) {
                        double tot = 0;
                        for (final v in ventas) {
                          for (final i in v.items) {
                            if (i.tipoCafe == tipo) tot += i.subtotal;
                          }
                        }
                        if (tot == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _coloresTipo[tipo] ?? Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tipo,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatCOP(tot),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${ventas.length} ventas registradas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Lista de ventas ──
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: ventas.length,
            itemBuilder:
                (_, i) => _VentaCard(
                  venta: ventas[i],
                  onTap: () => _abrirDetalle(ventas[i]),
                  onEliminar: () => _confirmarEliminar(ventas[i]),
                ),
          ),
        ),
      ],
    );
  }

  void _abrirDetalle(VentaModel v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => DraggableScrollableSheet(
            initialChildSize: 0.75,
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

                      // Header detalle
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.receipt_outlined,
                                    color: AppColors.secondary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v.fincaNombre,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      Text(
                                        'Comprador: ${v.vendedor}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                      Text(
                                        _fechaFormateada(v.fecha),
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
                            const SizedBox(height: 14),

                            // Total destacado
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFB71C1C),
                                    Color(0xFFE53935),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total venta',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        _formatCOP(v.totalPagar),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Total latas',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${v.totalLatas.toStringAsFixed(1)} latas',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Detalle por tipo de café',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),

                      // Items
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: v.items.length,
                          itemBuilder: (_, i) {
                            final item = v.items[i];
                            final color =
                                _coloresTipo[item.tipoCafe] ??
                                AppColors.primary;
                            final bg =
                                _bgTipo[item.tipoCafe] ??
                                AppColors.primary.withOpacity(0.06);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: color.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.coffee_outlined,
                                      color: color,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.tipoCafe,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                        Text(
                                          '${item.latas.toStringAsFixed(1)} latas · '
                                          '${_formatCOP(item.precioPorLata)}/lata',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatCOP(item.subtotal),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _confirmarEliminar(VentaModel v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('¿Eliminar venta?'),
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
    if (ok == true) await VentaService.eliminarVenta(v.id!);
  }

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
                color: AppColors.secondary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.landscape_outlined,
                size: 48,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Selecciona una finca',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Elige una finca para ver sus ventas registradas',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sell_outlined,
            size: 60,
            color: AppColors.secondary.withOpacity(0.25),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sin ventas registradas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Las ventas de esta finca aparecerán aquí',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de venta ──────────────────────────────────────────────────────────
class _VentaCard extends StatelessWidget {
  final VentaModel venta;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  const _VentaCard({
    required this.venta,
    required this.onTap,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sell_outlined,
                color: AppColors.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comprador: ${venta.vendedor}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    venta.items
                        .map(
                          (i) =>
                              '${i.tipoCafe}: ${i.latas.toStringAsFixed(1)} latas',
                        )
                        .join(' · '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fechaFormateada(venta.fecha),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCOP(venta.totalPagar),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 12,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'Ver detalle',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers globales ──────────────────────────────────────────────────────────

String _formatCOP(double v) {
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

String _fechaFormateada(DateTime f) {
  const meses = [
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
  final h = f.hour.toString().padLeft(2, '0');
  final m = f.minute.toString().padLeft(2, '0');
  return '${f.day} ${meses[f.month - 1]} ${f.year} · $h:$m';
}

class _LoadingRow extends StatelessWidget {
  final String texto;
  const _LoadingRow(this.texto);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Text(texto, style: const TextStyle(color: AppColors.textLight)),
      ],
    ),
  );
}

class _EmptyRow extends StatelessWidget {
  final String texto;
  const _EmptyRow(this.texto);
  @override
  Widget build(BuildContext context) => Padding(
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
