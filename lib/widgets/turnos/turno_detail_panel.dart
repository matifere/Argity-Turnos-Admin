import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:argrity/bloc/turnos/turnos_bloc.dart';
import 'package:argrity/models/class_session.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:argrity/widgets/common/kali_icon_button.dart';
import 'package:argrity/widgets/turnos/edit_turno_dialog.dart';
import 'package:argrity/widgets/turnos/assign_student_dialog.dart';
import 'package:argrity/services/profile_cache.dart';

/// Panel lateral con los detalles de un turno seleccionado.
class TurnoDetailPanel extends StatelessWidget {
  final ClassSession turno;
  final VoidCallback onClose;

  const TurnoDetailPanel({
    super.key,
    required this.turno,
    required this.onClose,
  });

  bool get _canModifyStudents {
    if (ProfileCache.isAdmin) {
      if (turno.instructorName == null || ProfileCache.fullName == null) {
        return false;
      }
      return turno.instructorName == ProfileCache.fullName;
    }
    return true; // Sudo u otros roles pueden modificar siempre
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: kaliColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kaliColors.espresso.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(kaliColors),
          _buildSlotInfo(kaliColors),
          if (turno.description != null && turno.description!.isNotEmpty)
            _buildDescription(kaliColors),
          const SizedBox(height: 16),
          Expanded(child: _buildEnrolledStudents(context, kaliColors)),
          if (_canModifyStudents) ...[
            _buildActions(context, kaliColors),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildPanelHeader(KaliColorsExtension kaliColors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Detalles de Clase',
            style: kaliColors.body(
              kaliColors.espresso,
              weight: FontWeight.w700,
              size: 16,
            ),
          ),
          KaliIconButton(
            Icons.close,
            tooltip: 'Cerrar',
            onTap: onClose,
            iconSize: 18,
          ),
        ],
      ),
    );
  }

  // ── Info del slot ──────────────────────────────────────────────────────────
  Widget _buildSlotInfo(KaliColorsExtension kaliColors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kaliColors.sand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TURNO SELECCIONADO',
                style: kaliColors.label(
                  kaliColors.espresso.withValues(alpha: 0.65),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: turno.isFull
                      ? const Color(0xFFD4685C).withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  turno.occupancyText,
                  style: kaliColors
                      .label(
                        turno.isFull
                            ? const Color(0xFFD4685C)
                            : kaliColors.espresso.withValues(alpha: 0.7),
                      )
                      .copyWith(
                          fontWeight: turno.isFull
                              ? FontWeight.bold
                              : FontWeight.normal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            turno.name,
            style: kaliColors.body(
              kaliColors.espresso,
              weight: FontWeight.w700,
              size: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${turno.startTimeFormatted} - ${turno.endTimeFormatted}',
            style: kaliColors.body(
              kaliColors.espresso.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            turno.instructorName ?? 'Sin instructor',
            style: kaliColors.body(
              kaliColors.espresso.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(KaliColorsExtension kaliColors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DESCRIPCIÓN',
            style: kaliColors.label(
              kaliColors.espresso.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            turno.description!,
            style: kaliColors.body(
              kaliColors.espresso.withValues(alpha: 0.7),
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Alumnos inscriptos ──────────────────────────────────────────────────────
  Widget _buildEnrolledStudents(
      BuildContext context, KaliColorsExtension kaliColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALUMNOS INSCRIPTOS',
                style: kaliColors
                    .label(kaliColors.espresso.withValues(alpha: 0.65)),
              ),
              // Sin gate por cupo: el admin puede pasarse de capacidad a
              // propósito. Al alumno lo frena el RPC del lado del servidor.
              if (_canModifyStudents)
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => BlocProvider.value(
                        value: context.read<TurnosBloc>(),
                        child: AssignStudentDialog(session: turno),
                      ),
                    );
                  },
                  child: Text(
                    '+ Inscribir',
                    style: kaliColors.label(kaliColors.espresso).copyWith(
                          color: kaliColors.espresso,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: turno.enrolledStudents.isEmpty
              ? Center(
                  child: Text(
                    'No hay alumnos inscriptos.',
                    style: kaliColors
                        .body(kaliColors.espresso.withValues(alpha: 0.65)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: turno.enrolledStudents.length,
                  itemBuilder: (context, index) {
                    final student = turno.enrolledStudents[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: kaliColors.clay,
                        child: Text(
                            student.studentName.isNotEmpty
                                ? student.studentName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: kaliColors.warmWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                        student.studentName,
                        style: kaliColors.body(kaliColors.espresso,
                            weight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _canModifyStudents
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: student.status == 'attended'
                                      ? 'Presente'
                                      : 'Marcar presente',
                                  child: Checkbox(
                                    value: student.status == 'attended',
                                    activeColor: kaliColors.clay,
                                    onChanged: (_) {
                                      context
                                          .read<TurnosBloc>()
                                          .add(TurnoStudentAttendanceToggled(
                                            reservationId: student.id,
                                            currentStatus: student.status,
                                          ));
                                    },
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(Icons.close,
                                      size: 16,
                                      color: kaliColors.espresso
                                          .withValues(alpha: 0.65)),
                                  onPressed: () {
                                    context
                                        .read<TurnosBloc>()
                                        .add(TurnoStudentRemoved(student.id));
                                  },
                                  tooltip: 'Desinscribir',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            )
                          : (student.status == 'attended'
                              ? Icon(Icons.check_circle,
                                  size: 16, color: kaliColors.clay)
                              : const SizedBox()),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Botones de acción ──────────────────────────────────────────────────────
  Widget _buildActions(BuildContext context, KaliColorsExtension kaliColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _ActionButton(
            icon: Icons.edit_outlined,
            label: 'Editar / Reprogramar',
            onTap: () {
              final bloc = context.read<TurnosBloc>();
              showDialog(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: bloc,
                  child: EditTurnoDialog(turno: turno),
                ),
              );
              onClose(); // Cerrar panel tras abrir
            },
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.delete_outline,
            label: 'Cancelar Sesión',
            onTap: () async {
              final action = await showDialog<int>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cancelar sesión'),
                  content: Text(
                      '¿Seguro que deseas cancelar la clase de ${turno.name}? Esta acción eliminará el turno completamente.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(0),
                        child: const Text('Volver')),
                    if (turno.groupId != null)
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(2),
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Esta y futuras',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(1),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Solo esta')),
                  ],
                ),
              );

              if (action != null && action > 0) {
                if (context.mounted) {
                  context.read<TurnosBloc>().add(TurnoDeleted(
                        turno,
                        deleteAllFuture: action == 2,
                      ));
                }
              }
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

// ─── Botón de acción del panel ────────────────────────────────────────────────
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    final color =
        widget.isDestructive ? const Color(0xFFD4685C) : kaliColors.espresso;

    return MouseRegion(
      onEnter: (e) {
        if (e.kind == PointerDeviceKind.mouse) setState(() => _hovered = true);
      },
      onExit: (e) {
        if (e.kind == PointerDeviceKind.mouse) setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.isDestructive
                    ? const Color(0xFFFDF0EE)
                    : kaliColors.sand)
                : Colors.transparent,
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: kaliColors.body(
                  color,
                  weight: FontWeight.w600,
                  size: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
