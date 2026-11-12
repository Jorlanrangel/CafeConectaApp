import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();

  String? _departamentoSeleccionado;

  final List<String> _departamentosColombia = [
    'Amazonas',
    'Antioquia',
    'Arauca',
    'Atlántico',
    'Bolívar',
    'Boyacá',
    'Caldas',
    'Caquetá',
    'Casanare',
    'Cauca',
    'Cesar',
    'Chocó',
    'Córdoba',
    'Cundinamarca',
    'Guainía',
    'Guaviare',
    'Huila',
    'La Guajira',
    'Magdalena',
    'Meta',
    'Nariño',
    'Norte de Santander',
    'Putumayo',
    'Quindío',
    'Risaralda',
    'San Andrés y Providencia',
    'Santander',
    'Sucre',
    'Tolima',
    'Valle del Cauca',
    'Vaupés',
    'Vichada',
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _cedulaCtrl.dispose();
    _telefonoCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      if (_nombreCtrl.text.trim().isEmpty) {
        _showError('Ingresa tu nombre');
        return;
      }
      if (_nombreCtrl.text.trim().length < 2) {
        _showError('El nombre debe tener al menos 2 caracteres');
        return;
      }
      if (_apellidoCtrl.text.trim().isEmpty) {
        _showError('Ingresa tu apellido');
        return;
      }
      if (_cedulaCtrl.text.trim().isEmpty) {
        _showError('Ingresa tu número de cédula');
        return;
      }
      if (_cedulaCtrl.text.trim().length < 6) {
        _showError('La cédula debe tener al menos 6 dígitos');
        return;
      }
    }
    if (_currentPage == 1) {
      final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (_emailCtrl.text.trim().isEmpty) {
        _showError('Ingresa tu correo electrónico');
        return;
      }
      if (!emailRegex.hasMatch(_emailCtrl.text.trim())) {
        _showError('Ingresa un correo válido');
        return;
      }
      if (_telefonoCtrl.text.trim().isEmpty) {
        _showError('Ingresa tu número de teléfono');
        return;
      }
      if (_telefonoCtrl.text.trim().length < 7) {
        _showError('El teléfono debe tener al menos 7 dígitos');
        return;
      }
      if (_departamentoSeleccionado == null) {
        _showError('Selecciona tu departamento');
        return;
      }
    }
    setState(() => _currentPage++);
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    setState(() => _currentPage--);
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _register() async {
    if (_passCtrl.text != _passConfirmCtrl.text) {
      _showError('Las contraseñas no coinciden');
      return;
    }
    if (_passCtrl.text.length < 8) {
      _showError('La contraseña debe tener al menos 8 caracteres');
      return;
    }
    if (!RegExp(r'(?=.*[A-Z])').hasMatch(_passCtrl.text)) {
      _showError('La contraseña debe tener al menos una mayúscula');
      return;
    }
    if (!RegExp(r'(?=.*[0-9])').hasMatch(_passCtrl.text)) {
      _showError('La contraseña debe tener al menos un número');
      return;
    }

    setState(() => _loading = true);

    try {
      // 1. Crear usuario en Firebase Auth
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text.trim(),
          );

      // 2. Guardar datos adicionales en Firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(credential.user!.uid)
          .set({
            'nombre': _nombreCtrl.text.trim(),
            'apellido': _apellidoCtrl.text.trim(),
            'cedula': _cedulaCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'telefono': _telefonoCtrl.text.trim(),
            'pais': 'Colombia',
            'departamento': _departamentoSeleccionado,
            'creadoEn': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta creada exitosamente!'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      String mensaje;
      switch (e.code) {
        case 'email-already-in-use':
          mensaje = 'Ya existe una cuenta con este correo';
          break;
        case 'weak-password':
          mensaje = 'La contraseña es muy débil';
          break;
        case 'invalid-email':
          mensaje = 'El correo no es válido';
          break;
        default:
          mensaje = 'Error al crear la cuenta. Intenta de nuevo';
      }
      _showError(mensaje);
    } catch (e) {
      _showError('Error inesperado. Intenta de nuevo');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.text),
          onPressed:
              _currentPage == 0 ? () => Navigator.of(context).pop() : _prevPage,
        ),
        title: Text(
          _currentPage == 0
              ? 'Datos personales'
              : _currentPage == 1
              ? 'Contacto y ubicación'
              : 'Crea tu contraseña',
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de progreso
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              child: Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      height: 5,
                      decoration: BoxDecoration(
                        color:
                            i <= _currentPage
                                ? AppColors.primary
                                : AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Paso ${_currentPage + 1} de 3',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            // Páginas
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildPage1(), _buildPage2(), _buildPage3()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _sectionHeader(
            '¿Cómo te llamas?',
            'Ingresa tu nombre completo tal como aparece en tu cédula',
          ),
          const SizedBox(height: 24),

          _field(
            controller: _nombreCtrl,
            label: 'Nombre',
            icon: Icons.person_outline,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ ]'),
              ),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo requerido';
              if (v.trim().length < 2) return 'Mínimo 2 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _field(
            controller: _apellidoCtrl,
            label: 'Apellido',
            icon: Icons.person_outline,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ ]'),
              ),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo requerido';
              if (v.trim().length < 2) return 'Mínimo 2 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _field(
            controller: _cedulaCtrl,
            label: 'Número de cédula',
            icon: Icons.badge_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo requerido';
              if (v.trim().length < 6) return 'Mínimo 6 dígitos';
              if (v.trim().length > 12) return 'Máximo 12 dígitos';
              return null;
            },
          ),

          const SizedBox(height: 36),
          ElevatedButton(onPressed: _nextPage, child: const Text('Continuar')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _sectionHeader(
            'Contacto y ubicación',
            'Necesitamos saber dónde estás para conectarte mejor',
          ),
          const SizedBox(height: 24),

          _field(
            controller: _emailCtrl,
            label: 'Correo electrónico',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo requerido';
              final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(v.trim())) {
                return 'Correo inválido (ej: nombre@dominio.com)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          _field(
            controller: _telefonoCtrl,
            label: 'Teléfono',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo requerido';
              final digits = v.replaceAll(RegExp(r'\D'), '');
              if (digits.length < 7) return 'Mínimo 7 dígitos';
              if (digits.length > 15) return 'Máximo 15 dígitos';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // País fijo: Colombia
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: const [
                Icon(Icons.public, color: AppColors.primary, size: 22),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'País',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Colombia',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Icon(Icons.check_circle, color: AppColors.primary, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Departamento — 32 de Colombia
          DropdownButtonFormField<String>(
            value: _departamentoSeleccionado,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Departamento',
              prefixIcon: const Icon(
                Icons.location_city_outlined,
                color: AppColors.primary,
              ),
              filled: true,
              fillColor: AppColors.card,
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
            ),
            hint: const Text(
              'Selecciona tu departamento',
              style: TextStyle(fontSize: 14),
            ),
            items:
                _departamentosColombia
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
            onChanged: (v) => setState(() => _departamentoSeleccionado = v),
            validator: (v) => v == null ? 'Selecciona tu departamento' : null,
          ),

          const SizedBox(height: 36),
          ElevatedButton(onPressed: _nextPage, child: const Text('Continuar')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPage3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _sectionHeader(
            'Crea tu contraseña',
            'Debe tener al menos 8 caracteres, una mayúscula y un número',
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: AppColors.primary,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textLight,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 10),

          _PasswordStrengthIndicator(password: _passCtrl.text),

          const SizedBox(height: 16),

          TextFormField(
            controller: _passConfirmCtrl,
            obscureText: _obscureConfirm,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: AppColors.primary,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textLight,
                ),
                onPressed:
                    () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              errorText:
                  _passConfirmCtrl.text.isNotEmpty &&
                          _passCtrl.text != _passConfirmCtrl.text
                      ? 'Las contraseñas no coinciden'
                      : null,
            ),
          ),

          const SizedBox(height: 36),

          _loading
              ? const CircularProgressIndicator(color: AppColors.primary)
              : ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                ),
                child: const Text('Crear mi cuenta'),
              ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: AppColors.textLight),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}

// ─── Indicador de fortaleza de contraseña ────────────────────────────────────

class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  const _PasswordStrengthIndicator({required this.password});

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 8;
    final hasUpper = RegExp(r'(?=.*[A-Z])').hasMatch(password);
    final hasNumber = RegExp(r'(?=.*[0-9])').hasMatch(password);
    final hasSpecial = RegExp(r'(?=.*[!@#\$&*~])').hasMatch(password);

    return Column(
      children: [
        _StrengthRow(label: 'Al menos 8 caracteres', met: hasLength),
        _StrengthRow(label: 'Una letra mayúscula', met: hasUpper),
        _StrengthRow(label: 'Un número', met: hasNumber),
        _StrengthRow(label: 'Carácter especial (!@#\$&*~)', met: hasSpecial),
      ],
    );
  }
}

class _StrengthRow extends StatelessWidget {
  final String label;
  final bool met;
  const _StrengthRow({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: met ? AppColors.primary : AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: met ? AppColors.primary : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
