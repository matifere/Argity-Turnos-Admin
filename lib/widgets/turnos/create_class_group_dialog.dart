import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:argrity/bloc/turnos/turnos_bloc.dart';
import 'package:argrity/services/profile_cache.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _RecurrenceOption { unique, oneMonth, twoMonths, restOfYear }

class CreateClassGroupDialog extends StatefulWidget {
  const CreateClassGroupDialog({super.key});

  @override
  State<CreateClassGroupDialog> createState() => _CreateClassGroupDialogState();
}

class _CreateClassGroupDialogState extends State<CreateClassGroupDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController(text: '8');

  List<String> _instructors = [];
  String? _selectedInstructor;
  bool _isLoadingInstructors = true;

  @override
  void initState() {
    super.initState();
    _loadInstructors();
  }

  Future<void> _loadInstructors() async {
    try {
      // Filtrar por institución si está disponible para no mezclar estudios.
      final instId = ProfileCache.institutionId;

      var query = Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .inFilter('role', const ['admin', 'sudo']);

      if (instId != null) {
        query = query.eq('institution_id', instId);
      }

      final res = await query.order('full_name', ascending: true);
      final list = (res as List).map((e) => e['full_name'] as String).toList();
      if (mounted) {
        setState(() {
          _instructors = list;
          _isLoadingInstructors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingInstructors = false;
        });
      }
    }
  }

  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);

  _RecurrenceOption _recurrenceOption = _RecurrenceOption.restOfYear;

  // 0 = Lunes, 6 = Domingo
  final Set<int> _selectedDays = {};

  final List<String> _dayNames = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom'
  ];

  int _weeksUntilEndOfYear(DateTime from) {
    final endOfYear = DateTime(from.year, 12, 31);
    return ((endOfYear.difference(from).inDays) / 7).ceil().clamp(1, 999);
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // Auto-adjust end time to be 1 hour later
          _endTime =
              TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute);
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Por favor, selecciona al menos un día de la semana')),
        );
        return;
      }

      final weekStart = context.read<TurnosBloc>().state.currentWeekStart;
      final weeks = switch (_recurrenceOption) {
        _RecurrenceOption.unique => 1,
        _RecurrenceOption.oneMonth => 4,
        _RecurrenceOption.twoMonths => 8,
        _RecurrenceOption.restOfYear => _weeksUntilEndOfYear(weekStart),
      };

      final String startTimeStr =
          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
      final String endTimeStr =
          '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

      context.read<TurnosBloc>().add(TurnoCreated(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            instructorName: _selectedInstructor,
            capacity: int.parse(_capacityController.text.trim()),
            startTime: startTimeStr,
            endTime: endTimeStr,
            daysOfWeek: _selectedDays.toList(),
            recurrenceWeeks: weeks,
          ));

      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: kaliColors.warmWhite,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crear Turnos (Grupo)',
                    style: kaliColors.heading(kaliColors.espresso, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agendando a partir de la semana del ${DateFormat("dd MMM", "es_ES").format(context.read<TurnosBloc>().state.currentWeekStart)}.',
                    style: kaliColors
                        .body(kaliColors.espresso.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 24),

                  Text('Nombre de la Clase',
                      style: kaliColors.label(kaliColors.espresso)),
                  const SizedBox(height: 8),
                  TextFormField(
                    style: kaliColors.body(kaliColors.espresso),
                    controller: _nameController,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Requerido' : null,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kaliColors.background,
                      hintStyle: kaliColors
                          .body(kaliColors.espresso.withValues(alpha: 0.65)),
                      hintText: 'Ej. Reformer Pilates',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Descripción (Opcional)',
                      style: kaliColors.label(kaliColors.espresso)),
                  const SizedBox(height: 8),
                  TextFormField(
                    style: kaliColors.body(kaliColors.espresso),
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kaliColors.background,
                      hintStyle: kaliColors
                          .body(kaliColors.espresso.withValues(alpha: 0.65)),
                      hintText: 'Ej. Nivel intermedio, traer mat propia',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Instructor (Opcional)',
                                style: kaliColors.label(kaliColors.espresso)),
                            const SizedBox(height: 8),
                            _isLoadingInstructors
                                ? const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator())
                                : DropdownButtonFormField<String>(
                                    style: kaliColors.body(kaliColors.espresso),
                                    initialValue: _selectedInstructor,
                                    hint: const Text('Sin instructor'),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: kaliColors.background,
                                      hintStyle: kaliColors.body(kaliColors
                                          .espresso
                                          .withValues(alpha: 0.65)),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                          value: null,
                                          child: Text('Sin instructor')),
                                      ..._instructors.map((e) =>
                                          DropdownMenuItem(
                                              value: e, child: Text(e))),
                                    ],
                                    onChanged: (val) {
                                      setState(() => _selectedInstructor = val);
                                    },
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Capacidad',
                                style: kaliColors.label(kaliColors.espresso)),
                            const SizedBox(height: 8),
                            TextFormField(
                              style: kaliColors.body(kaliColors.espresso),
                              controller: _capacityController,
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Requerido';
                                }
                                if (int.tryParse(val.trim()) == null) {
                                  return 'Debe ser número';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: kaliColors.background,
                                hintStyle: kaliColors.body(
                                    kaliColors.espresso.withValues(alpha: 0.65)),
                                hintText: 'Ej. 8',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text('Horario', style: kaliColors.label(kaliColors.espresso)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, true),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: kaliColors.background,
                              hintStyle: kaliColors.body(
                                  kaliColors.espresso.withValues(alpha: 0.65)),
                              labelText: 'Hora de Inicio',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(_startTime.format(context),
                                style: kaliColors.body(kaliColors.espresso)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, false),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: kaliColors.background,
                              hintStyle: kaliColors.body(
                                  kaliColors.espresso.withValues(alpha: 0.65)),
                              labelText: 'Hora de Fin',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(_endTime.format(context),
                                style: kaliColors.body(kaliColors.espresso)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text('Días de la semana',
                      style: kaliColors.label(kaliColors.espresso)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (index) {
                      final isSelected = _selectedDays.contains(index);
                      return ChoiceChip(
                        label: Text(_dayNames[index],
                            style: kaliColors.body(isSelected
                                ? kaliColors.warmWhite
                                : kaliColors.espresso)),
                        selected: isSelected,
                        selectedColor: kaliColors.espresso,
                        backgroundColor: kaliColors.background,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedDays.add(index);
                            } else {
                              _selectedDays.remove(index);
                            }
                          });
                        },
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  // Frecuencia
                  Text('Duración',
                      style: kaliColors.label(kaliColors.espresso)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<_RecurrenceOption>(
                    style: kaliColors.body(kaliColors.espresso),
                    initialValue: _recurrenceOption,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: kaliColors.background,
                      hintStyle: kaliColors
                          .body(kaliColors.espresso.withValues(alpha: 0.65)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: kaliColors.espresso.withValues(alpha: 0.1)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _RecurrenceOption.unique,
                        child: Text('Clase única (solo esta semana/fecha)'),
                      ),
                      DropdownMenuItem(
                        value: _RecurrenceOption.oneMonth,
                        child: Text('1 mes'),
                      ),
                      DropdownMenuItem(
                        value: _RecurrenceOption.twoMonths,
                        child: Text('2 meses'),
                      ),
                      DropdownMenuItem(
                        value: _RecurrenceOption.restOfYear,
                        child: Text('Resto del año (hasta el 31 de diciembre)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _recurrenceOption = val);
                    },
                  ),

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancelar',
                            style: kaliColors.body(
                                kaliColors.espresso.withValues(alpha: 0.6))),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kaliColors.espresso,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Crear Turnos',
                            style: kaliColors.body(kaliColors.warmWhite,
                                weight: FontWeight.w600)),
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
}
