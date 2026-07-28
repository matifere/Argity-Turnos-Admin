import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:argrity/bloc/alumnos/alumnos_bloc.dart';
import 'package:argrity/models/student.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:argrity/services/auth_service.dart';

class StudentFormDialog extends StatefulWidget {
  final Student? student;

  const StudentFormDialog({super.key, this.student});

  @override
  State<StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends State<StudentFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _patologiaController;
  late List<String> _patologias;
  late bool _isActive;

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isEditMode => widget.student != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: _isEditMode ? widget.student!.name : '');
    _emailController =
        TextEditingController(text: _isEditMode ? widget.student!.email : '');
    _passwordController = TextEditingController();
    _patologiaController = TextEditingController();
    _patologias = _isEditMode ? List.from(widget.student!.patologias) : [];
    _isActive = _isEditMode ? widget.student!.isActive : true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _patologiaController.dispose();
    super.dispose();
  }

  void _addPatologia() {
    final newPatologia = _patologiaController.text.trim();
    if (newPatologia.isNotEmpty && !_patologias.contains(newPatologia)) {
      setState(() {
        _patologias.add(newPatologia);
        _patologiaController.clear();
      });
    }
  }

  void _removePatologia(String patologia) {
    setState(() => _patologias.remove(patologia));
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    if (name.isEmpty) {
      if (mounted) {
        setState(() => _errorMessage = 'El nombre no puede estar vacío');
      }
      return;
    }

    if (!_isEditMode && (email.isEmpty || pass.isEmpty)) {
      if (mounted) setState(() => _errorMessage = 'Revisa todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isEditMode) {
        final result = await Supabase.instance.client
            .from('profiles')
            .update({
              'full_name': name,
              'patologias': _patologias,
              'is_active': _isActive,
            })
            .eq('id', widget.student!.id)
            .select('id');

        if (result.isEmpty) {
          throw Exception(
              'No se actualizó ningún registro. Verificá las políticas RLS en Supabase.');
        }

        if (mounted) {
          context.read<AlumnosBloc>().add(AlumnosLoadRequested());
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alumno actualizado con éxito')),
          );
        }
      } else {
        final authService = SupaAuthClass();
        final result = await authService.registrarAlumno(email, pass, name);

        if (result == 'Ok') {
          if (mounted) {
            context.read<AlumnosBloc>().add(AlumnosLoadRequested());
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Alumno "$name" registrado correctamente.'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = result;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _isEditMode
              ? 'No se pudo actualizar el alumno. Intentá nuevamente.'
              : 'Error al registrar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: kaliColors.warmWhite,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditMode ? 'Editar Alumno' : 'Añadir Nuevo Alumno',
                      style: _isEditMode
                          ? kaliColors.headingItalic(kaliColors.espresso,
                              size: 24)
                          : kaliColors.heading(kaliColors.espresso, size: 32).copyWith(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: kaliColors.espresso),
                    ),
                  ],
                ),
                if (!_isEditMode) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Se registrará con rol de usuario cliente.',
                    style: kaliColors
                        .body(kaliColors.espresso.withValues(alpha: 0.6)),
                  ),
                ],
                const SizedBox(height: 24),

                // Nombre
                const _FieldLabel('Nombre Completo'),
                const SizedBox(height: 6),
                _buildTextField(_nameController,
                    hint: 'Ej. María Pérez', kaliColors: kaliColors),
                const SizedBox(height: 16),

                // Correo Electrónico
                const _FieldLabel('Correo Electrónico'),
                const SizedBox(height: 6),
                _buildTextField(_emailController,
                    hint: 'correo@ejemplo.com',
                    readOnly: _isEditMode,
                    kaliColors: kaliColors),
                const SizedBox(height: 16),

                // Contraseña (Solo en creación)
                if (!_isEditMode) ...[
                  const _FieldLabel('Contraseña temporal'),
                  const SizedBox(height: 6),
                  _buildTextField(_passwordController,
                      hint: 'Mínimo 6 caracteres',
                      obscureText: true,
                      kaliColors: kaliColors),
                  const SizedBox(height: 16),
                ],

                // Estado activo y patologías (Solo en edición)
                if (_isEditMode) ...[
                  // Estado activo
                  const _FieldLabel('Estado'),
                  const SizedBox(height: 6),
                  _ActiveToggle(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  const SizedBox(height: 20),

                  // Patologías
                  const _FieldLabel('Patologías'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          _patologiaController,
                          hint: 'Añadir patología...',
                          onSubmitted: (_) => _addPatologia(),
                          kaliColors: kaliColors,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addPatologia,
                        icon: Icon(Icons.add_circle,
                            color: kaliColors.clayDark, size: 30),
                      ),
                    ],
                  ),
                  if (_patologias.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _patologias
                          .map((p) => Chip(
                                label: Text(p,
                                    style: kaliColors.body(kaliColors.espresso,
                                        size: 13)),
                                deleteIcon: const Icon(Icons.close, size: 15),
                                onDeleted: () => _removePatologia(p),
                                backgroundColor: kaliColors.sand,
                                side: BorderSide(
                                    color: kaliColors.clayDark
                                        .withValues(alpha: 0.3)),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: kaliColors.body(const Color(0xFFD4685C)),
                  ),
                ],
                const SizedBox(height: 32),

                // Guardar / Cancelar
                if (_isEditMode)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kaliColors.clayDark,
                        foregroundColor:
                            kaliColors.getContrastColor(kaliColors.clayDark),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(
                              color: kaliColors
                                  .getContrastColor(kaliColors.clayDark))
                          : Text('Guardar Cambios',
                              style: kaliColors.body(kaliColors
                                  .getContrastColor(kaliColors.clayDark))),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancelar',
                          style: kaliColors.body(kaliColors.espresso),
                        ),
                      ),
                      const SizedBox(width: 16),
                      MouseRegion(
                        cursor: _isLoading
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _isLoading ? null : _submit,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: _isLoading
                                  ? kaliColors.espresso.withValues(alpha: 0.6)
                                  : kaliColors.espresso,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: kaliColors.warmWhite,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Registrar Alumno',
                                    style: kaliColors.body(kaliColors.warmWhite,
                                        weight: FontWeight.w600, size: 13),
                                  ),
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
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    String hint = '',
    bool readOnly = false,
    bool obscureText = false,
    void Function(String)? onSubmitted,
    required KaliColorsExtension kaliColors,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: kaliColors.body(
        readOnly
            ? kaliColors.espresso.withValues(alpha: 0.6)
            : kaliColors.espresso,
        size: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: kaliColors.body(kaliColors.espresso.withValues(alpha: 0.5),
            size: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: kaliColors.espresso.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kaliColors.espresso),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return Text(
      text,
      style: kaliColors.body(kaliColors.espresso,
          weight: FontWeight.w600, size: 13),
    );
  }
}

class _ActiveToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ActiveToggle({required this.value, required this.onChanged});

  static const _activeColor = Color(0xFF5C9E6C);
  static const _inactiveColor = Color(0xFFD4685C);

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              (value ? _activeColor : _inactiveColor).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                (value ? _activeColor : _inactiveColor).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 18,
              color: value ? _activeColor : _inactiveColor,
            ),
            const SizedBox(width: 8),
            Text(
              value ? 'Activo' : 'Inactivo',
              style: kaliColors.body(
                value ? _activeColor : _inactiveColor,
                weight: FontWeight.w600,
                size: 14,
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _activeColor,
              inactiveThumbColor: _inactiveColor,
            ),
          ],
        ),
      ),
    );
  }
}
