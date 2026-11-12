import 'package:cafeconecta_aplication/fincas/finca_model.dart';
import 'package:cafeconecta_aplication/fincas/finca_service.dart';
import 'package:cafeconecta_aplication/fincas/lote_model.dart';
import 'package:cafeconecta_aplication/fincas/lote_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import 'trabajador_model.dart';
import 'cosecha_model.dart';
import 'recoleccion_service.dart';
import 'ver_recoleccion_screen.dart';

class RecoleccionScreen extends StatefulWidget {
  const RecoleccionScreen({super.key});

  @override
  State<RecoleccionScreen> createState() => _RecoleccionScreenState();
}

class _RecoleccionScreenState extends State<RecoleccionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final _kilosCtrl = TextEditingController();
  final _buscarCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  FincaModel? _fincaSeleccionada;
  LoteModel? _loteSeleccionado;
  TrabajadorModel? _trabajadorSeleccionado;

  List<FincaModel> _fincas = [];
  List<LoteModel> _lotes = [];
  List<TrabajadorModel> _trabajadores = [];
  List<TrabajadorModel> _trabajadoresFiltrados = [];

  bool _loading = false;
  bool _loadingFincas = true;

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
    _kilosCtrl.dispose();
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

  void _escucharTrabajadoresPorFinca(String fincaId) {
    RecoleccionService.obtenerTrabajadoresPorFinca(fincaId).listen((lista) {
      if (mounted) {
        setState(() {
          _trabajadores = lista;
          _trabajadorSeleccionado = null;
          _filtrarTrabajadores(_buscarCtrl.text);
        });
      }
    });
  }

  void _filtrarTrabajadores(String query) {
    setState(() {
      _trabajadoresFiltrados =
          query.isEmpty
              ? _trabajadores
              : _trabajadores
                  .where(
                    (t) => t.nombre.toLowerCase().contains(query.toLowerCase()),
                  )
                  .toList();
    });
  }

  void _onFincaChanged(FincaModel? finca) {
    setState(() {
      _fincaSeleccionada = finca;
      _loteSeleccionado = null;
      _lotes = [];
      _trabajadores = [];
      _trabajadoresFiltrados = [];
      _trabajadorSeleccionado = null;
      _buscarCtrl.clear();
    });
    if (finca != null) {
      // Cargar lotes de la finca
      LoteService.obtenerLotes(finca.id!).listen((lotes) {
        if (mounted) setState(() => _lotes = lotes);
      });
      // Cargar trabajadores de la finca
      _escucharTrabajadoresPorFinca(finca.id!);
    }
  }

  Future<void> _registrarCosecha() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fincaSeleccionada == null) {
      _showSnack('Selecciona una finca', error: true);
      return;
    }
    if (_loteSeleccionado == null) {
      _showSnack('Selecciona un lote', error: true);
      return;
    }
    if (_trabajadorSeleccionado == null) {
      _showSnack('Selecciona un trabajador', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final cosecha = CosechaModel(
        fincaId: _fincaSeleccionada!.id!,
        fincaNombre: _fincaSeleccionada!.nombre,
        loteId: _loteSeleccionado!.id!,
        loteNombre: _loteSeleccionado!.nombre,
        trabajadorId: _trabajadorSeleccionado!.id!,
        trabajadorNombre: _trabajadorSeleccionado!.nombre,
        kilos: double.parse(_kilosCtrl.text.trim()),
        fecha: DateTime.now(),
      );
      await RecoleccionService.guardarCosecha(cosecha);
      if (mounted) {
        _showSnack('¡Cosecha registrada exitosamente!');
        _kilosCtrl.clear();
        setState(() => _trabajadorSeleccionado = null);
      }
    } catch (e) {
      _showSnack('Error al registrar: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
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

  // ── Diálogo registrar trabajador ─────────────────────────────────────────

  void _mostrarDialogoTrabajador() {
    final nombreCtrl = TextEditingController();
    FincaModel? fincaSeleccionadaDialog = _fincaSeleccionada;

    showDialog(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (ctx, setS) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.person_add_outlined, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Registrar trabajador'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nombre
                      TextField(
                        controller: nombreCtrl,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [LengthLimitingTextInputFormatter(60)],
                        decoration: InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: AppColors.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selector de finca
                      DropdownButtonFormField<FincaModel>(
                        value: fincaSeleccionadaDialog,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Asignar a finca',
                          prefixIcon: const Icon(
                            Icons.landscape_outlined,
                            color: AppColors.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        hint: const Text(
                          'Selecciona la finca',
                          style: TextStyle(fontSize: 14),
                        ),
                        items:
                            _fincas
                                .map(
                                  (f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(
                                      f.nombre,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (f) => setS(() => fincaSeleccionadaDialog = f),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (nombreCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ingresa el nombre del trabajador'),
                              backgroundColor: AppColors.secondary,
                            ),
                          );
                          return;
                        }
                        if (fincaSeleccionadaDialog == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Selecciona una finca'),
                              backgroundColor: AppColors.secondary,
                            ),
                          );
                          return;
                        }
                        await RecoleccionService.guardarTrabajador(
                          TrabajadorModel(
                            nombre: nombreCtrl.text.trim(),
                            fincaId: fincaSeleccionadaDialog!.id!,
                            fincaNombre: fincaSeleccionadaDialog!.nombre,
                            creadoEn: DateTime.now(),
                          ),
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _showSnack(
                            'Trabajador registrado en '
                            '${fincaSeleccionadaDialog!.nombre}',
                          );
                        }
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
          ),
    );
  }

  // ── Diálogo eliminar trabajador ──────────────────────────────────────────

  void _mostrarDialogoEliminarTrabajador() {
    showDialog(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder: (ctx, setS) {
              final buscarElimCtrl = TextEditingController();
              var filtrados = List<TrabajadorModel>.from(_trabajadores);
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Row(
                  children: [
                    Icon(
                      Icons.person_remove_outlined,
                      color: AppColors.secondary,
                    ),
                    SizedBox(width: 8),
                    Text('Eliminar trabajador'),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_fincaSeleccionada != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.landscape_outlined,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Finca: ${_fincaSeleccionada!.nombre}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextField(
                        controller: buscarElimCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onChanged:
                            (v) => setS(() {
                              filtrados =
                                  _trabajadores
                                      .where(
                                        (t) => t.nombre.toLowerCase().contains(
                                          v.toLowerCase(),
                                        ),
                                      )
                                      .toList();
                            }),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child:
                            filtrados.isEmpty
                                ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'Sin trabajadores en esta finca',
                                      style: TextStyle(
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: filtrados.length,
                                  itemBuilder: (_, i) {
                                    final t = filtrados[i];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.primary
                                            .withOpacity(0.1),
                                        child: Text(
                                          t.nombre[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(t.nombre),
                                      subtitle: Text(
                                        t.fincaNombre,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.secondary,
                                        ),
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: ctx,
                                            builder:
                                                (_) => AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  title: const Text(
                                                    '¿Eliminar?',
                                                  ),
                                                  content: Text(
                                                    '¿Eliminar a "${t.nombre}"? También se eliminarán sus registros de cosecha.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'Cancelar',
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                AppColors
                                                                    .secondary,
                                                          ),
                                                      child: const Text(
                                                        'Eliminar',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          );
                                          if (ok == true) {
                                            await RecoleccionService.eliminarTrabajador(
                                              t.id!,
                                            );
                                            if (ctx.mounted) {
                                              Navigator.pop(ctx);
                                              _showSnack(
                                                'Trabajador eliminado',
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          'Registrar Cosecha',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const VerRecoleccionScreen(),
                    ),
                  ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bar_chart_outlined,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Ver',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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

                // ── Sección 1: Finca y lote ───────────────────────────
                _sectionLabel(
                  'Seleccionar finca y lote',
                  Icons.landscape_outlined,
                ),
                const SizedBox(height: 12),
                _buildCard(
                  children: [
                    _buildDropdown<FincaModel>(
                      label: 'Finca',
                      icon: Icons.landscape_outlined,
                      value: _fincaSeleccionada,
                      hint:
                          _loadingFincas
                              ? 'Cargando fincas...'
                              : 'Selecciona una finca',
                      items: _fincas,
                      itemLabel: (f) => f.nombre,
                      onChanged: _onFincaChanged,
                      validator:
                          (v) => v == null ? 'Selecciona una finca' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown<LoteModel>(
                      label: 'Lote',
                      icon: Icons.grass_outlined,
                      value: _loteSeleccionado,
                      hint:
                          _fincaSeleccionada == null
                              ? 'Primero selecciona una finca'
                              : _lotes.isEmpty
                              ? 'Sin lotes registrados'
                              : 'Selecciona un lote',
                      items: _lotes,
                      itemLabel: (l) => l.nombre,
                      enabled: _fincaSeleccionada != null && _lotes.isNotEmpty,
                      onChanged: (l) => setState(() => _loteSeleccionado = l),
                      validator: (v) => v == null ? 'Selecciona un lote' : null,
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // ── Sección 2: Trabajador ─────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _sectionLabel('Trabajador', Icons.people_outline),
                    ),
                    _miniButton(
                      icon: Icons.person_add_outlined,
                      label: 'Registrar',
                      color: AppColors.primary,
                      onTap: _mostrarDialogoTrabajador,
                    ),
                    const SizedBox(width: 8),
                    _miniButton(
                      icon: Icons.person_remove_outlined,
                      label: 'Eliminar',
                      color: AppColors.secondary,
                      onTap: _mostrarDialogoEliminarTrabajador,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCard(
                  children: [
                    // Info finca seleccionada
                    if (_fincaSeleccionada != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.landscape_outlined,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Trabajadores de: ${_fincaSeleccionada!.nombre}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Buscador
                    TextField(
                      controller: _buscarCtrl,
                      onChanged: _filtrarTrabajadores,
                      decoration: InputDecoration(
                        hintText: 'Buscar trabajador por nombre...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.primary,
                        ),
                        suffixIcon:
                            _buscarCtrl.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: AppColors.textLight,
                                  ),
                                  onPressed: () {
                                    _buscarCtrl.clear();
                                    _filtrarTrabajadores('');
                                  },
                                )
                                : null,
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
                    const SizedBox(height: 12),

                    // Lista trabajadores
                    _fincaSeleccionada == null
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: Text(
                              'Selecciona una finca para ver sus trabajadores',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                        : _trabajadoresFiltrados.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: Text(
                              _trabajadores.isEmpty
                                  ? 'No hay trabajadores en esta finca.\nUsa "Registrar" para agregar uno.'
                                  : 'Sin resultados para "${_buscarCtrl.text}"',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                        : ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _trabajadoresFiltrados.length,
                            itemBuilder: (_, i) {
                              final t = _trabajadoresFiltrados[i];
                              final seleccionado =
                                  _trabajadorSeleccionado?.id == t.id;
                              return GestureDetector(
                                onTap:
                                    () => setState(
                                      () => _trabajadorSeleccionado = t,
                                    ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        seleccionado
                                            ? AppColors.primary.withOpacity(0.1)
                                            : const Color(0xFFF7F9F8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          seleccionado
                                              ? AppColors.primary
                                              : AppColors.border,
                                      width: seleccionado ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            seleccionado
                                                ? AppColors.primary
                                                : AppColors.primary.withOpacity(
                                                  0.1,
                                                ),
                                        child: Text(
                                          t.nombre[0].toUpperCase(),
                                          style: TextStyle(
                                            color:
                                                seleccionado
                                                    ? Colors.white
                                                    : AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          t.nombre,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight:
                                                seleccionado
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                            color:
                                                seleccionado
                                                    ? AppColors.primary
                                                    : AppColors.text,
                                          ),
                                        ),
                                      ),
                                      if (seleccionado)
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                  ],
                ),

                const SizedBox(height: 22),

                // ── Sección 3: Kilos ──────────────────────────────────
                _sectionLabel('Kilos recolectados', Icons.scale_outlined),
                const SizedBox(height: 12),
                _buildCard(
                  children: [
                    if (_fincaSeleccionada != null ||
                        _loteSeleccionado != null ||
                        _trabajadorSeleccionado != null) ...[
                      _buildResumenSeleccion(),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _kilosCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                        LengthLimitingTextInputFormatter(8),
                      ],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Kilos recolectados',
                        hintText: '0.00',
                        prefixIcon: const Icon(
                          Icons.scale_outlined,
                          color: AppColors.primary,
                        ),
                        suffixText: 'kg',
                        suffixStyle: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.error),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa los kilos recolectados';
                        }
                        final val = double.tryParse(v.trim());
                        if (val == null) return 'Ingresa un número válido';
                        if (val <= 0) {
                          return 'Los kilos deben ser mayores a 0';
                        }
                        if (val > 999) return 'Valor demasiado alto';
                        return null;
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Botón registrar ───────────────────────────────────
                _loading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                    : ElevatedButton.icon(
                      onPressed: _registrarCosecha,
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      label: const Text(
                        'Registrar cosecha',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers UI ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
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
              Icons.shopping_basket_outlined,
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
                  'Registrar Cosecha',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Selecciona la finca, lote y trabajador para registrar los kilos recolectados',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenSeleccion() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de selección',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (_fincaSeleccionada != null)
            _resumenRow(Icons.landscape_outlined, _fincaSeleccionada!.nombre),
          if (_loteSeleccionado != null)
            _resumenRow(Icons.grass_outlined, _loteSeleccionado!.nombre),
          if (_trabajadorSeleccionado != null)
            _resumenRow(Icons.person_outline, _trabajadorSeleccionado!.nombre),
        ],
      ),
    );
  }

  Widget _resumenRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.text),
          ),
        ],
      ),
    );
  }

  Widget _miniButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppColors.primary, size: 17),
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

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: enabled ? AppColors.primary : AppColors.textLight,
          size: 22,
        ),
        filled: true,
        fillColor: enabled ? const Color(0xFFF7F9F8) : const Color(0xFFEEEEEE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      hint: Text(
        hint,
        style: const TextStyle(fontSize: 14, color: AppColors.textLight),
      ),
      items:
          items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel(item),
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                  ),
                ),
              )
              .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
      menuMaxHeight: 280,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: enabled ? AppColors.primary : AppColors.textLight,
      ),
    );
  }
}
