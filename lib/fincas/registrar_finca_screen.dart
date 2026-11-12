import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'colombia_data.dart';
import 'finca_model.dart';
import 'finca_service.dart';

class RegistrarFincaScreen extends StatefulWidget {
  const RegistrarFincaScreen({super.key});

  @override
  State<RegistrarFincaScreen> createState() => _RegistrarFincaScreenState();
}

class _RegistrarFincaScreenState extends State<RegistrarFincaScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _nombreCtrl = TextEditingController();
  final _veredaCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  final _hectareasCtrl = TextEditingController();

  String? _departamento;
  String? _municipio;
  bool _loading = false;

  List<String> get _municipios =>
      _departamento != null ? (colombiaMunicipios[_departamento!] ?? []) : [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nombreCtrl.dispose();
    _veredaCtrl.dispose();
    _alturaCtrl.dispose();
    _hectareasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final finca = FincaModel(
        nombre: _nombreCtrl.text.trim(),
        departamento: _departamento!,
        municipio: _municipio!,
        vereda: _veredaCtrl.text.trim(),
        altura: double.parse(_alturaCtrl.text.trim()),
        hectareas: double.parse(_hectareasCtrl.text.trim()),
        creadaEn: DateTime.now(),
      );
      await FincaService.guardarFinca(finca);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Finca registrada exitosamente'),
            ]),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          'Registrar Finca',
          style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header decorativo ──
                  Container(
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
                            offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.landscape_outlined,
                              color: Colors.white, size: 34),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nueva Finca',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text(
                                'Completa los datos de tu finca cafetera para registrarla',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Sección: Información básica ──
                  _sectionLabel('Información básica', Icons.info_outline),
                  const SizedBox(height: 14),

                  _buildCard(children: [
                    // Nombre de la finca
                    _buildField(
                      controller: _nombreCtrl,
                      label: 'Nombre de la finca',
                      hint: 'Ej: La Esperanza',
                      icon: Icons.home_work_outlined,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(60),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa el nombre de la finca';
                        }
                        if (v.trim().length < 3) {
                          return 'Mínimo 3 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Vereda
                    _buildField(
                      controller: _veredaCtrl,
                      label: 'Vereda',
                      hint: 'Ej: El Paraíso',
                      icon: Icons.map_outlined,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(60),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa la vereda';
                        }
                        return null;
                      },
                    ),
                  ]),

                  const SizedBox(height: 22),

                  // ── Sección: Ubicación ──
                  _sectionLabel('Ubicación', Icons.location_on_outlined),
                  const SizedBox(height: 14),

                  _buildCard(children: [
                    // Departamento
                    _buildDropdown<String>(
                      label: 'Departamento',
                      icon: Icons.account_balance_outlined,
                      value: _departamento,
                      hint: 'Selecciona tu departamento',
                      items: departamentosColombia,
                      itemLabel: (d) => d,
                      onChanged: (v) {
                        setState(() {
                          _departamento = v;
                          _municipio = null;
                        });
                      },
                      validator: (v) =>
                          v == null ? 'Selecciona un departamento' : null,
                    ),
                    const SizedBox(height: 16),

                    // Municipio (dinámico)
                    _buildDropdown<String>(
                      label: 'Municipio',
                      icon: Icons.location_city_outlined,
                      value: _municipio,
                      hint: _departamento == null
                          ? 'Primero selecciona departamento'
                          : 'Selecciona tu municipio',
                      items: _municipios,
                      itemLabel: (m) => m,
                      enabled: _departamento != null,
                      onChanged: (v) => setState(() => _municipio = v),
                      validator: (v) =>
                          v == null ? 'Selecciona un municipio' : null,
                    ),
                  ]),

                  const SizedBox(height: 22),

                  // ── Sección: Características ──
                  _sectionLabel('Características', Icons.terrain_outlined),
                  const SizedBox(height: 14),

                  _buildCard(children: [
                    // Altura
                    _buildField(
                      controller: _alturaCtrl,
                      label: 'Altura sobre el nivel del mar',
                      hint: 'Ej: 1650',
                      icon: Icons.terrain_outlined,
                      suffix: 'msnm',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: false),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa la altura';
                        }
                        final val = int.tryParse(v.trim());
                        if (val == null) return 'Ingresa un número válido';
                        if (val < 500 || val > 4000) {
                          return 'La altura debe estar entre 500 y 4000 msnm';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Hectáreas
                    _buildField(
                      controller: _hectareasCtrl,
                      label: 'Hectáreas de la finca',
                      hint: 'Ej: 3.5',
                      icon: Icons.square_foot_outlined,
                      suffix: 'ha',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                        LengthLimitingTextInputFormatter(8),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa las hectáreas';
                        }
                        final val = double.tryParse(v.trim());
                        if (val == null) return 'Ingresa un número válido';
                        if (val <= 0) return 'Las hectáreas deben ser mayores a 0';
                        if (val > 10000) return 'Valor demasiado grande';
                        return null;
                      },
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // ── Botones ──
                  Row(
                    children: [
                      // Cancelar
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            side: const BorderSide(
                                color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            foregroundColor: AppColors.textLight,
                          ),
                          child: const Text('Cancelar',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Guardar
                      Expanded(
                        flex: 2,
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary))
                            : ElevatedButton.icon(
                                onPressed: _guardar,
                                icon: const Icon(Icons.save_outlined, size: 20),
                                label: const Text('Guardar finca'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers UI ─────────────────────────────────────────────────────────────

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
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.text)),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
        suffixText: suffix,
        suffixStyle: const TextStyle(
            color: AppColors.textLight,
            fontSize: 13,
            fontWeight: FontWeight.w600),
        filled: true,
        fillColor: const Color(0xFFF7F9F8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.error, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        prefixIcon: Icon(icon,
            color: enabled ? AppColors.primary : AppColors.textLight,
            size: 22),
        filled: true,
        fillColor: enabled ? const Color(0xFFF7F9F8) : const Color(0xFFEEEEEE),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.border.withOpacity(0.5))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      hint: Text(hint,
          style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item),
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.text)),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator,
      menuMaxHeight: 320,
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: enabled ? AppColors.primary : AppColors.textLight),
    );
  }
}