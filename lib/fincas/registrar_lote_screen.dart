import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'lote_model.dart';
import 'lote_service.dart';

class RegistrarLoteScreen extends StatefulWidget {
  final String fincaId;
  final String fincaNombre;

  const RegistrarLoteScreen({
    super.key,
    required this.fincaId,
    required this.fincaNombre,
  });

  @override
  State<RegistrarLoteScreen> createState() => _RegistrarLoteScreenState();
}

class _RegistrarLoteScreenState extends State<RegistrarLoteScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _nombreCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  String? _variedad;
  bool _loading = false;

  // Variedades de café más comunes en Colombia
  final List<String> _variedades = [
    'Castillo',
    'Colombia',
    'Caturra',
    'Bourbon',
    'Típica',
    'Tabi',
    'Cenicafé 1',
    'Geisha',
    'Pacamara',
    'Maragogipe',
    'Supremo',
    'Excelso',
    'Otra',
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
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
    _alturaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_variedad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Selecciona la variedad de café'),
          ]),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final lote = LoteModel(
        nombre: _nombreCtrl.text.trim(),
        altura: double.parse(_alturaCtrl.text.trim()),
        variedad: _variedad!,
        fincaId: widget.fincaId,
        creadoEn: DateTime.now(),
      );
      await LoteService.guardarLote(lote);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Lote registrado exitosamente'),
            ]),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
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
          'Registrar Lote',
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
                  // Header decorativo
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
                          child: const Icon(Icons.grass_outlined,
                              color: Colors.white, size: 34),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nuevo Lote',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                'Finca: ${widget.fincaNombre}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Sección: Información del lote
                  _sectionLabel(
                      'Información del lote', Icons.info_outline),
                  const SizedBox(height: 14),

                  _buildCard(children: [
                    // Nombre del lote
                    _buildField(
                      controller: _nombreCtrl,
                      label: 'Nombre del lote',
                      hint: 'Ej: Lote Alto',
                      icon: Icons.workspaces_outlined,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(50),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa el nombre del lote';
                        }
                        if (v.trim().length < 2) {
                          return 'Mínimo 2 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Altura del lote
                    _buildField(
                      controller: _alturaCtrl,
                      label: 'Altura del lote',
                      hint: 'Ej: 1700',
                      icon: Icons.terrain_outlined,
                      suffix: 'msnm',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa la altura del lote';
                        }
                        final val = int.tryParse(v.trim());
                        if (val == null) return 'Ingresa un número válido';
                        if (val < 500 || val > 4000) {
                          return 'La altura debe estar entre 500 y 4000 msnm';
                        }
                        return null;
                      },
                    ),
                  ]),

                  const SizedBox(height: 22),

                  // Sección: Variedad de café
                  _sectionLabel(
                      'Variedad de café', Icons.eco_outlined),
                  const SizedBox(height: 14),

                  _buildCard(children: [
                    DropdownButtonFormField<String>(
                      value: _variedad,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Variedad sembrada',
                        prefixIcon: const Icon(Icons.eco_outlined,
                            color: AppColors.primary, size: 22),
                        filled: true,
                        fillColor: const Color(0xFFF7F9F8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2)),
                        errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.error)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      hint: const Text('Selecciona la variedad',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textLight)),
                      items: _variedades
                          .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(v,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.text))))
                          .toList(),
                      onChanged: (v) => setState(() => _variedad = v),
                      validator: (v) =>
                          v == null ? 'Selecciona la variedad' : null,
                      menuMaxHeight: 280,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primary),
                    ),

                    // Info de variedades
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.primary, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selecciona la variedad principal sembrada en este lote.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // Botones
                  Row(
                    children: [
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
                              style:
                                  TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary))
                            : ElevatedButton.icon(
                                onPressed: _guardar,
                                icon: const Icon(Icons.save_outlined,
                                    size: 20),
                                label: const Text('Guardar lote'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize:
                                      const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
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
}