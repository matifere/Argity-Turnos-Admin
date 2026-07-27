import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:argrity/bloc/turnos/turnos_bloc.dart';
import 'package:argrity/models/class_session.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
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
      final monthStart = DateTime(sessionDate.year, sessionDate.month, 1);
      final monthEnd = DateTime(sessionDate.year, sessionDate.month + 1, 0);
      final startIso = monthStart.toIso8601String().split('T')[0];
      final endIso = monthEnd.toIso8601String().split('T')[0];

      // 1. Fetch profiles
      final profilesRes = await client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .eq('role', 'client')
          .order('full_name', ascending: true);

      // 2. Fetch active/pending subscriptions
      final subsRes = await client
          .from('subscriptions')
          .select('user_id, status, end_date, plans(max_reservations_per_month)')
          .inFilter('status', ['active', 'pending']);

      // Map subscriptions by user_id, sum their max_reservations and find latest end_date
      final Map<String, int> userMaxRes = {};
      final Map<String, DateTime?> userPlanEndDate = {};
      final Set<String> usersWithPlan = {};
      for (var sub in (subsRes as List<dynamic>)) {
        final uid = sub['user_id'] as String;
        usersWithPlan.add(uid);
        final plansData = sub['plans'];
        if (plansData != null &&
            plansData['max_reservations_per_month'] != null) {
          userMaxRes[uid] = (userMaxRes[uid] ?? 0) +
              (plansData['max_reservations_per_month'] as int);
        }
        if (sub['end_date'] != null) {
          final ed = DateTime.tryParse(sub['end_date'].toString());
          if (ed != null) {
            final currentEd = userPlanEndDate[uid];
            if (currentEd == null || ed.isAfter(currentEd)) {
              userPlanEndDate[uid] = ed;
            }
          }
        }
      }

      // 3. Fetch reservations for the month (excluyendo canceladas; el .or
      //    preserva las de status NULL legacy que cuentan como confirmadas).
      final resRes = await client
          .from('reservations')
          .select('user_id, status, class_sessions!inner(date)')
          .or('status.is.null,status.neq.cancelled')
          .gte('class_sessions.date', startIso)
          .lte('class_sessions.date', endIso);

      // Count reservations per user
      final Map<String, int> userReservations = {};
      for (var r in (resRes as List<dynamic>)) {
        final uid = r['user_id'] as String;
        userReservations[uid] = (userReservations[uid] ?? 0) + 1;
      }

      // 4b. ¿Hay más sesiones de esta misma serie a futuro?
      //     Si las hay, ofrecemos proyectar la inscripción; si no, no aparece.
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
        if (widget.session.institutionId != null) {
          seriesQuery =
              seriesQuery.eq('institution_id', widget.session.institutionId!);
        }
      }
      final seriesRes = await seriesQuery.limit(1);
      final canProject = (seriesRes as List).isNotEmpty;

      // 4. Filtrar los que ya están anotados en esta sesión
      final enrolledIds =
          widget.session.enrolledStudents.map((e) => e.userId).toSet();

      final available = (profilesRes as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
          .where((p) => !enrolledIds.contains(p['id']))
          .map((p) {
        final uid = p['id'] as String;
        String? disabledReason;
        int maxRes = 0;
        int currRes = userReservations[uid] ?? 0;

        if (!usersWithPlan.contains(uid)) {
          disabledReason = 'Sin plan activo';
        } else {
          maxRes = userMaxRes[uid] ?? 0;
          if (maxRes > 0 && currRes >= maxRes) {
            disabledReason = 'Límite mensual alcanzado';
          }
        }

        p['disabledReason'] = disabledReason;
        p['currRes'] = currRes;
        p['maxRes'] = maxRes;
        p['endDate'] = userPlanEndDate[uid];
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

  void _assignSelected() {
    if (_selectedIds.isEmpty) return;
    for (final userId in _selectedIds) {
      context.read<TurnosBloc>().add(TurnoStudentAssigned(
            userId: userId,
            session: widget.session,
            enrollmentType: _enrollmentType,
          ));
    }
    Navigator.of(context).pop();
    final count = _selectedIds.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? 'Alumno inscripto correctamente'
              : 'Se inscribieron $count alumnos correctamente',
        ),
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
                      onPressed: _selectedIds.isEmpty ? null : _assignSelected,
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
                      child: Text(
                        _selectedIds.isEmpty
                            ? 'Inscribir'
                            : 'Inscribir (${_selectedIds.length})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
