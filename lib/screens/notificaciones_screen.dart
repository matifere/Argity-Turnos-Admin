import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:argrity/bloc/alumnos/alumnos_bloc.dart';
import 'package:argrity/bloc/notifications/notifications_cubit.dart';
import 'package:argrity/theme/kali_colors_extension.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _mensajeController = TextEditingController();
  final _searchController = TextEditingController();
  
  String _targetType = 'all'; // 'all' or 'selected'
  final Set<String> _selectedStudentIds = {};
  
  @override
  void initState() {
    super.initState();
    // Disparar carga de alumnos si no están cargados
    final alumnosBloc = context.read<AlumnosBloc>();
    if (alumnosBloc.state is! AlumnosLoaded) {
      alumnosBloc.add(AlumnosLoadRequested());
    }
  }
  
  @override
  void dispose() {
    _tituloController.dispose();
    _mensajeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    final bool isSmall = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 20 : 40,
              vertical: 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  'Enviar Notificaciones',
                  style: kaliColors
                      .heading(kaliColors.espresso, size: isSmall ? 32 : 36)
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                Text(
                  'Envía avisos a los alumnos de la institución. Las notificaciones aparecerán en tiempo real.',
                  style: kaliColors.body(
                    kaliColors.espresso.withValues(alpha: 0.6),
                    size: 16,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Formulario principal
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: kaliColors.warmWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: kaliColors.espresso.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: kaliColors.espresso.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destinatarios',
                          style: kaliColors.body(kaliColors.espresso,
                              weight: FontWeight.bold, size: 16),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _TargetOptionCard(
                                title: 'Todos los usuarios',
                                description: 'Toda la institución',
                                icon: Icons.groups_rounded,
                                isSelected: _targetType == 'all',
                                kaliColors: kaliColors,
                                onTap: () => setState(() => _targetType = 'all'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _TargetOptionCard(
                                title: 'Alumnos específicos',
                                description: 'Seleccionar manual',
                                icon: Icons.person_add_alt_1_rounded,
                                isSelected: _targetType == 'selected',
                                kaliColors: kaliColors,
                                onTap: () =>
                                    setState(() => _targetType = 'selected'),
                              ),
                            ),
                          ],
                        ),
                        
                        if (_targetType == 'selected') ...[
                          const SizedBox(height: 24),
                          Text(
                            'Buscar Alumnos',
                            style: kaliColors.label(
                                kaliColors.espresso.withValues(alpha: 0.8)),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Ej. Juan Pérez...',
                              hintStyle: TextStyle(
                                color: kaliColors.espresso.withValues(alpha: 0.3),
                              ),
                              prefixIcon: Icon(Icons.search,
                                  color: kaliColors.espresso.withValues(alpha: 0.4)),
                              filled: true,
                              fillColor: kaliColors.sand.withValues(alpha: 0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          BlocBuilder<AlumnosBloc, AlumnosState>(
                            builder: (context, state) {
                              if (state is AlumnosLoading || state is AlumnosInitial) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (state is AlumnosError) {
                                return Text('Error al cargar alumnos', style: TextStyle(color: kaliColors.error));
                              }
                              if (state is AlumnosLoaded) {
                                return ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _searchController,
                                  builder: (context, searchValue, _) {
                                    final query = searchValue.text.toLowerCase();
                                    final filteredStudents = state.students.where((s) => 
                                      s.name.toLowerCase().contains(query) || 
                                      s.email.toLowerCase().contains(query)
                                    ).toList();
                                    
                                    return Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: kaliColors.sand.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: kaliColors.espresso.withValues(alpha: 0.1)),
                                      ),
                                      child: filteredStudents.isEmpty
                                          ? Center(
                                              child: Text(
                                                'No se encontraron alumnos.',
                                                style: kaliColors.caption(kaliColors.espresso.withValues(alpha: 0.5)),
                                              ),
                                            )
                                          : ListView.builder(
                                              itemCount: filteredStudents.length,
                                              itemBuilder: (context, index) {
                                                final student = filteredStudents[index];
                                                final isSelected = _selectedStudentIds.contains(student.id);
                                                return CheckboxListTile(
                                                  value: isSelected,
                                                  activeColor: kaliColors.espresso,
                                                  title: Text(student.name, style: kaliColors.body(kaliColors.espresso, weight: FontWeight.w500)),
                                                  subtitle: Text(student.email, style: kaliColors.caption(kaliColors.espresso.withValues(alpha: 0.6))),
                                                  onChanged: (bool? value) {
                                                    setState(() {
                                                      if (value == true) {
                                                        _selectedStudentIds.add(student.id);
                                                      } else {
                                                        _selectedStudentIds.remove(student.id);
                                                      }
                                                    });
                                                  },
                                                );
                                              },
                                            ),
                                    );
                                  },
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Alumnos seleccionados: ${_selectedStudentIds.length}',
                            style: kaliColors.caption(kaliColors.espresso.withValues(alpha: 0.7)),
                          ),
                        ],
                        
                        const SizedBox(height: 32),
                        Text(
                          'Plantillas',
                          style: kaliColors.body(kaliColors.espresso,
                              weight: FontWeight.bold, size: 16),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _TemplateChip(
                                label: '🌴 Feriado',
                                kaliColors: kaliColors,
                                onTap: () {
                                  _tituloController.text = '🌴 Feriado: Clases suspendidas';
                                  _mensajeController.text = 'Te avisamos que el estudio permanecerá cerrado por feriado. ¡Que disfrutes tu merecido descanso! 😎';
                                },
                              ),
                              const SizedBox(width: 8),
                              _TemplateChip(
                                label: '🔄 Cambio de profe',
                                kaliColors: kaliColors,
                                onTap: () {
                                  _tituloController.text = '🔄 Cambio de profesor';
                                  _mensajeController.text = 'Te informamos que por motivos de fuerza mayor, tu próxima clase será dictada por un profesor de reemplazo. 💪 ¡A entrenar con todo!';
                                },
                              ),
                              const SizedBox(width: 8),
                              _TemplateChip(
                                label: '💸 Recordatorio',
                                kaliColors: kaliColors,
                                onTap: () {
                                  _tituloController.text = '💸 Recordatorio de pago';
                                  _mensajeController.text = '¡Hola! 👋 Te recordamos que tu plan está próximo a vencer. Acordate de renovarlo para no perder tu lugar reservado. ¡Te esperamos!';
                                },
                              ),
                              const SizedBox(width: 8),
                              _TemplateChip(
                                label: '🎉 Promoción',
                                kaliColors: kaliColors,
                                onTap: () {
                                  _tituloController.text = '🎉 ¡Nueva promoción disponible!';
                                  _mensajeController.text = 'Aprovechá nuestros nuevos descuentos especiales. 🔥 Acercate a recepción para conocer más y sumar beneficios.';
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Contenido',
                          style: kaliColors.body(kaliColors.espresso,
                              weight: FontWeight.bold, size: 16),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Título',
                          style: kaliColors.label(
                              kaliColors.espresso.withValues(alpha: 0.8)),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _tituloController,
                          decoration: InputDecoration(
                            hintText: 'Ej. Clase suspendida por feriado',
                            hintStyle: TextStyle(
                              color: kaliColors.espresso.withValues(alpha: 0.3),
                            ),
                            filled: true,
                            fillColor: kaliColors.sand.withValues(alpha: 0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa un título';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Mensaje',
                          style: kaliColors.label(
                              kaliColors.espresso.withValues(alpha: 0.8)),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _mensajeController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Escribe el detalle de la notificación...',
                            hintStyle: TextStyle(
                              color: kaliColors.espresso.withValues(alpha: 0.3),
                            ),
                            filled: true,
                            fillColor: kaliColors.sand.withValues(alpha: 0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa un mensaje';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kaliColors.espresso,
                              foregroundColor: kaliColors.warmWhite,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.send_rounded, size: 20),
                            label: const Text(
                              'Enviar Notificación',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                if (_targetType == 'selected' && _selectedStudentIds.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Por favor, selecciona al menos un alumno.',
                                            style: TextStyle(color: kaliColors.warmWhite)),
                                        backgroundColor: kaliColors.error),
                                  );
                                  return;
                                }

                                final title = _tituloController.text.trim();
                                final message = _mensajeController.text.trim();
                                final cubit = context.read<NotificationsCubit>();

                                if (_targetType == 'all') {
                                  final alumnosState = context.read<AlumnosBloc>().state;
                                  final allIds = alumnosState is AlumnosLoaded 
                                      ? alumnosState.students.map((s) => s.id).toList() 
                                      : <String>[];
                                      
                                  if (allIds.isNotEmpty) {
                                    await cubit.sendNotifications(
                                        title: title, message: message, targetUserIds: allIds);
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('No hay alumnos registrados.', style: TextStyle(color: kaliColors.warmWhite)), backgroundColor: kaliColors.error),
                                      );
                                    }
                                    return;
                                  }
                                } else {
                                  await cubit.sendNotifications(
                                      title: title, message: message, targetUserIds: _selectedStudentIds.toList());
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('¡Notificación enviada con éxito!')),
                                  );
                                  _tituloController.clear();
                                  _mensajeController.clear();
                                  setState(() {
                                    _selectedStudentIds.clear();
                                    _searchController.clear();
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final KaliColorsExtension kaliColors;

  const _TargetOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.kaliColors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? kaliColors.espresso.withValues(alpha: 0.05)
              : kaliColors.sand.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? kaliColors.espresso
                : kaliColors.espresso.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? kaliColors.espresso
                  : kaliColors.espresso.withValues(alpha: 0.5),
              size: 28,
            ),
            const SizedBox(height: 12),
            AutoSizeText(
              title,
              maxLines: 1,
              style: kaliColors.body(
                kaliColors.espresso,
                weight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            AutoSizeText(
              description,
              maxLines: 1,
              style: kaliColors.caption(
                kaliColors.espresso.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final KaliColorsExtension kaliColors;

  const _TemplateChip({
    required this.label,
    required this.onTap,
    required this.kaliColors,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: kaliColors.body(kaliColors.espresso, weight: FontWeight.w600)),
      backgroundColor: kaliColors.sand.withValues(alpha: 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: kaliColors.espresso.withValues(alpha: 0.1)),
      ),
      onPressed: onTap,
    );
  }
}
