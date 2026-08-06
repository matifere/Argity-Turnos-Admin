import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
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
  
  String _targetType = 'all'; // 'all' or 'selected'
  
  @override
  void dispose() {
    _tituloController.dispose();
    _mensajeController.dispose();
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
                          const SizedBox(height: 8),
                          Text(
                            '*(Mock)* Aquí irá un selector múltiple de alumnos.',
                            style: kaliColors.caption(
                                kaliColors.espresso.withValues(alpha: 0.5)),
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
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                // TODO: Implementar lógica de envío
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Notificación de prueba enviada (UI Only)')),
                                );
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
