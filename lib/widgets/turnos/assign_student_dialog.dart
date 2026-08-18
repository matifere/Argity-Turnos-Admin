import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:argrity/bloc/turnos/turnos_bloc.dart';
import 'package:argrity/models/class_session.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:argrity/repositories/turnos_repository.dart';
import 'package:argrity/widgets/common/avatar_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssignStudentDialog extends StatefulWidget {
  final ClassSession session;

  const AssignStudentDialog({super.key, required this.session});

  @override
  State<AssignStudentDialog> createState() => _AssignStudentDialogState();
}

class _AssignStudentDialogState extends State<AssignStudentDialog> {
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _filteredProfiles = [];
  bool _isLoading = true;
  String? _error;
  EnrollmentType _enrollmentType = EnrollmentType.planValidity;
  bool _canProject = false;
  bool _isAssigning = false;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    try {
      final client = Supabase.instance.client;
      final sessionDate = widget.session.date;
      final instId = widget.session.institutionId;
      final monthStart = DateTime(sessionDate.year, sessionDate.month, 1);
      final monthEnd = DateTime(sessionDate.year, sessionDate.month + 1, 0);
      final startIso = monthStart.toIso8601String().split('T')[0];
      final endIso = monthEnd.toIso8601String().split('T')[0];

      // 1. Prepare single embedded query for profiles with their subscriptions and reservations
      var profilesQuery = client
          .from('profiles')
          .select('''
            id, full_name, avatar_url,
            subscriptions!subscriptions_user_id_fkey(status, end_date, plans(max_reservations_per_month)),
            reservations!reservations_user_id_fkey(status, class_sessions(date, institution_id))
          ''')
          .eq('role', 'client');
      if (instId != null) {
        profilesQuery = profilesQuery.eq('institution_id', instId);
      }
      final profilesFuture = profilesQuery.order('full_name', ascending: true);

      final seriesStartIso = sessionDate
          .add(const Duration(days: 1))
          .toIso8601String()
          .split('T')[0];
      var seriesQuery = client
          .from('class_sessions')
          .select('id')
          .gte('date', seriesStartIso);
      if (widget.session.groupId != null) {
        seriesQuery = seriesQuery.eq('group_id', widget.session.groupId!);
      } else {
        seriesQuery = seriesQuery
            .eq('name', widget.session.name)
            .eq('start_time', widget.session.startTime);
        if (instId != null) {
          seriesQuery = seriesQuery.eq('institution_id', instId);
        }
      }
      final seriesFuture = seriesQuery.limit(1);

      // Execute queries concurrently
      final results = await Future.wait([
        profilesFuture,
        seriesFuture,
      ]);

      final profilesRes = results[0] as List<dynamic>;
      final seriesRes = results[1] as List<dynamic>;

      final canProject = seriesRes.isNotEmpty;

      // 4. Filtrar los que ya están anotados en esta sesión
      final enrolledIds =
          widget.session.enrolledStudents.map((e) => e.userId).toSet();

      final available = profilesRes
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .where((p) => !enrolledIds.contains(p['id']))
          .map((p) {
        final subs = (p['subscriptions'] as List<dynamic>?) ?? [];
        int maxRes = 0;
        DateTime? planEndDate;
        bool hasActivePlan = false;

        for (var sub in subs) {
          final status = sub['status'];
          if (status == 'active' || status == 'pending') {
            hasActivePlan = true;
            final plansData = sub['plans'];
            if (plansData != null &&
                plansData['max_reservations_per_month'] != null) {
              maxRes += (plansData['max_reservations_per_month'] as int);
            }
            if (sub['end_date'] != null) {
              final ed = DateTime.tryParse(sub['end_date'].toString());
              if (ed != null) {
                if (planEndDate == null || ed.isAfter(planEndDate)) {
                  planEndDate = ed;
                }
              }
            }
          }
        }

        final resList = (p['reservations'] as List<dynamic>?) ?? [];
        int currRes = 0;
        for (var r in resList) {
          final status = r['status'];
          if (status == 'cancelled') continue;
          final session = r['class_sessions'];
          if (session == null) continue;
          if (instId != null && session['institution_id'] != instId) continue;
          final dateStr = session['date']?.toString();
          if (dateStr == null) continue;
          if (dateStr.compareTo(startIso) >= 0 &&
              dateStr.compareTo(endIso) <= 0) {
            currRes++;
          }
        }

        String? disabledReason;
        if (!hasActivePlan) {
          disabledReason = 'Sin plan activo';
        } else {
          if (maxRes > 0 && currRes >= maxRes) {
            disabledReason = 'Límite mensual alcanzado';
          }
        }

        p['disabledReason'] = disabledReason;
        p['currRes'] = currRes;
        p['maxRes'] = maxRes;
        p['endDate'] = planEndDate;
        return p;
      }).toList();

      if (mounted) {
        setState(() {
          _profiles = available;
          _filteredProfiles = available;
          _canProject = canProject;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar alumnos: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _filter(String query) {
    if (query.isEmpty) {
      setState(() => _filteredProfiles = _profiles);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredProfiles = _profiles.where((p) {
        final name = (p['full_name'] ?? '').toString().toLowerCase();
        return name.contains(q);
      }).toList();
    });
  }

  Future<void> _toggleSelection(
      String userId, String name, String? disabledReason) async {
    if (_selectedIds.contains(userId)) {
      setState(() => _selectedIds.remove(userId));
      return;
    }

    if (disabledReason != null) {
      final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Seleccionar sin créditos',
              style: kaliColors.heading(kaliColors.espresso, size: 20)),
          content: Text(
            '$name no cumple los requisitos ($disabledReason). '
            '¿Seleccionarlo de todas formas? Como admin podés forzar la inscripción.',
            style: kaliColors.body(kaliColors.espresso),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancelar',
                  style: kaliColors
                      .body(kaliColors.espresso.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Seleccionar igual',
                  style: kaliColors.body(kaliColors.espresso,
                      weight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _selectedIds.add(userId));
  }

  /// Calcula la proyección recurrente de cada alumno seleccionado. Si alguna
  /// clase futura queda fuera del cupo mensual de su plan, se lo avisa al admin
  /// y lo deja decidir si la fuerza igual (el alumno nunca puede: lo frena el
  /// RPC del servidor).
  Future<void> _assignSelected() async {
    if (_selectedIds.isEmpty || _isAssigning) return;

    final bloc = context.read<TurnosBloc>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nameById = {
      for (final p in _profiles) p['id'] as String: (p['full_name'] ?? 'Alumno') as String
    };

    final plans = <String, RecurrentEnrollmentPlan>{};
    if (_enrollmentType != EnrollmentType.single) {
      setState(() => _isAssigning = true);
      try {
        for (final userId in _selectedIds) {
          plans[userId] = await bloc.repository.planRecurrentEnrollment(
            userId: userId,
            session: widget.session,
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isAssigning = false);
        messenger.showSnackBar(
          SnackBar(content: Text('No se pudo calcular la recurrencia: $e')),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _isAssigning = false);
    }

    var forceOverPlan = false;
    final overPlan = plans.entries.where((e) => e.value.hasOverPlan).toList();
    if (overPlan.isNotEmpty) {
      final decision = await _askForceOverPlan(overPlan, nameById);
      if (decision == null || !mounted) return;
      forceOverPlan = decision;
    }

    var totalClasses = 0;
    for (final userId in _selectedIds) {
      final plan = plans[userId];
      final ids = plan == null
          ? null
          : <String>[...plan.withinPlan, if (forceOverPlan) ...plan.overPlan];
      totalClasses += 1 + (ids?.length ?? 0);

      bloc.add(TurnoStudentAssigned(
        userId: userId,
        session: widget.session,
        enrollmentType: _enrollmentType,
        projectedSessionIds: ids,
      ));
    }

    navigator.pop();
    final count = _selectedIds.length;
    final base = count == 1
        ? 'Alumno inscripto correctamente'
        : 'Se inscribieron $count alumnos correctamente';
    messenger.showSnackBar(
      SnackBar(
        content: Text(_enrollmentType == EnrollmentType.single
            ? base
            : '$base ($totalClasses ${totalClasses == 1 ? 'clase' : 'clases'} en total)'),
      ),
    );
  }

  /// `true` = inscribir también las clases que superan el plan, `false` = solo
  /// las que entran, `null` = el admin canceló.
  Future<bool?> _askForceOverPlan(
    List<MapEntry<String, RecurrentEnrollmentPlan>> overPlan,
    Map<String, String> nameById,
  ) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('La recurrencia supera el plan',
            style: kaliColors.heading(kaliColors.espresso, size: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El cupo mensual del plan no alcanza para todas las clases de la serie:',
              style: kaliColors.body(kaliColors.espresso),
            ),
            const SizedBox(height: 12),
            ...overPlan.map((e) {
              final plan = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${nameById[e.key] ?? 'Alumno'}: entran ${plan.withinPlan.length} de ${plan.total} clases '
                  '(${plan.overPlan.length} fuera del plan)',
                  style: kaliColors.body(kaliColors.espresso, size: 13),
                ),
              );
            }),
            const SizedBox(height: 12),
            Text(
              'Como admin podés inscribir igual en todas; el alumno no puede pasarse por su cuenta.',
              style:
                  kaliColors.body(kaliColors.espresso.withValues(alpha: 0.6), size: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Cancelar',
                style:
                    kaliColors.body(kaliColors.espresso.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Solo las que entran',
                style: kaliColors.body(kaliColors.espresso)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Inscribir en todas',
                style: kaliColors.body(kaliColors.espresso,
                    weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: kaliColors.warmWhite,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Inscribir Alumno',
                  style: kaliColors.heading(kaliColors.espresso, size: 24),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Clase: ${widget.session.name}',
              style: kaliColors.body(kaliColors.espresso, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: kaliColors.espresso.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${DateFormat('EEEE d MMMM', 'es').format(widget.session.date)} • ${widget.session.startTimeFormatted} - ${widget.session.endTimeFormatted} hs',
                    style: kaliColors.body(kaliColors.espresso.withValues(alpha: 0.7), size: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: kaliColors.espresso.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: kaliColors.espresso.withValues(alpha: 0.1)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_canProject || widget.session.groupId != null) ...[
              Text('Opciones de inscripción recurrentes',
                  style: kaliColors.body(kaliColors.espresso,
                      size: 14, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<EnrollmentType>(
                initialValue: _enrollmentType,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: kaliColors.espresso.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: kaliColors.espresso.withValues(alpha: 0.1)),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: EnrollmentType.planValidity,
                    child: Text('Proyectar hasta el vencimiento del plan'),
                  ),
                  DropdownMenuItem(
                    value: EnrollmentType.single,
                    child: Text('Solo a esta clase'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _enrollmentType = v);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)))
                      : _filteredProfiles.isEmpty
                          ? Center(
                              child: Text(
                                  'No se encontraron alumnos disponibles',
                                  style: kaliColors.body(kaliColors.espresso
                                      .withValues(alpha: 0.65))))
                          : ListView.separated(
                              itemCount: _filteredProfiles.length,
                              separatorBuilder: (_, __) => Divider(
                                  color: kaliColors.espresso
                                      .withValues(alpha: 0.1)),
                              itemBuilder: (context, index) {
                                final p = _filteredProfiles[index];
                                final name = p['full_name'] ?? 'Sin nombre';
                                final disabledReason = p['disabledReason'] as String?;
                                final currRes = p['currRes'] as int?;
                                final maxRes = p['maxRes'] as int?;
                                final endDate = p['endDate'] as DateTime?;
                                final endStr = endDate != null
                                    ? ' (vence: ${DateFormat('d/M/yy').format(endDate)})'
                                    : '';

                                final isSelected = _selectedIds.contains(p['id']);
                                return ListTile(
                                  onTap: () => _toggleSelection(
                                      p['id'], name, disabledReason),
                                  leading: CircleAvatar(
                                    backgroundColor: kaliColors.clay,
                                    backgroundImage:
                                        AvatarProvider.fromUrl(p['avatar_url']),
                                    child: p['avatar_url'] == null
                                        ? Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                                color: kaliColors.warmWhite,
                                                fontSize: 12))
                                        : null,
                                  ),
                                  title: Text(name,
                                      style: kaliColors.body(
                                          kaliColors.espresso.withValues(
                                              alpha: disabledReason != null
                                                  ? 0.5
                                                  : 1.0),
                                          weight: FontWeight.w600)),
                                  subtitle: disabledReason != null
                                      ? Text('$disabledReason$endStr',
                                          style: TextStyle(
                                              color: Colors.red[700],
                                              fontSize: 12))
                                      : Text(
                                          (maxRes ?? 0) > 0
                                              ? '$currRes/$maxRes reservas este mes$endStr'
                                              : 'Con plan activo$endStr',
                                          style: TextStyle(
                                            color: ((maxRes ?? 0) > 0 &&
                                                    (currRes ?? 0) >= maxRes!)
                                                ? Colors.orange[700]
                                                : kaliColors.clay,
                                            fontSize: 12,
                                          ),
                                        ),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    activeColor: kaliColors.espresso,
                                    onChanged: (_) => _toggleSelection(
                                        p['id'], name, disabledReason),
                                  ),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 16),
            Divider(color: kaliColors.espresso.withValues(alpha: 0.1), height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedIds.isEmpty
                      ? 'Ninguno seleccionado'
                      : '${_selectedIds.length} ${_selectedIds.length == 1 ? 'seleccionado' : 'seleccionados'}',
                  style: kaliColors.body(
                    kaliColors.espresso.withValues(alpha: 0.7),
                    size: 13,
                    weight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancelar',
                          style: kaliColors.body(
                              kaliColors.espresso.withValues(alpha: 0.6))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: (_selectedIds.isEmpty || _isAssigning)
                          ? null
                          : _assignSelected,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kaliColors.espresso,
                        foregroundColor: kaliColors.warmWhite,
                        disabledBackgroundColor:
                            kaliColors.espresso.withValues(alpha: 0.2),
                        disabledForegroundColor:
                            kaliColors.warmWhite.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isAssigning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _selectedIds.isEmpty
                                  ? 'Inscribir'
                                  : 'Inscribir (${_selectedIds.length})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
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
