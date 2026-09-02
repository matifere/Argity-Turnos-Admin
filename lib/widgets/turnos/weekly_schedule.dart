import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:argrity/models/class_session.dart';
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:argrity/widgets/turnos/day_column.dart';
import 'package:argrity/widgets/turnos/time_labels_column.dart';
import 'package:argrity/widgets/turnos/mobile_schedule.dart';

/// Grilla del calendario semanal 7 columnas (Lun–Dom).
///
/// Cada turno se posiciona con [Stack] + [Positioned] según su hora de inicio
/// y duración. Turnos solapados se muestran en carriles side-by-side.
class WeeklySchedule extends StatelessWidget {
  final DateTime currentWeekStart;
  final List<ClassSession> sessions;
  final ClassSession? selectedTurno;
  final ValueChanged<ClassSession> onTurnoSelected;

  const WeeklySchedule({
    super.key,
    required this.currentWeekStart,
    required this.sessions,
    this.selectedTurno,
    required this.onTurnoSelected,
  });

  // Rango horario visible en la grilla: 06:00 a 23:00.
  int get _startHour => 6;
  int get _endHour => 23;

  int get _totalHours {
    final start = _startHour;
    final end = _endHour;
    return end > start ? end - start : 1;
  }

  // Cada hora = 2 celdas de 30 min.
  static const int _slotsPerHour = 2;
  int get _totalSlots => _totalHours * _slotsPerHour;

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return LayoutBuilder(
      builder: (context, constraints) {
        // En celular la grilla de 7 días no entra: mostramos un solo día con
        // un selector arriba, en vez de obligar a scrollear horizontalmente.
        const double mobileBreakpoint = 640.0;
        if (constraints.maxWidth < mobileBreakpoint) {
          return MobileDaySchedule(
            currentWeekStart: currentWeekStart,
            sessions: sessions,
            selectedTurno: selectedTurno,
            onTurnoSelected: onTurnoSelected,
            startHour: _startHour,
            totalSlots: _totalSlots,
            slotsPerHour: _slotsPerHour,
          );
        }

        const double minWidth = 680.0;
        final needsScroll = constraints.maxWidth < minWidth;
        final schedule = Column(
          children: [
            _buildDayHeaders(kaliColors),
            Expanded(child: _buildScheduleBody(kaliColors)),
          ],
        );
        if (needsScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minWidth, child: schedule),
          );
        }
        return schedule;
      },
    );
  }

  // ── Headers de días ────────────────────────────────────────────────────────
  Widget _buildDayHeaders(KaliColorsExtension kaliColors) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.fromLTRB(60, 16, 0, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: kaliColors.espresso.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: List.generate(7, (i) {
          final dayDate = currentWeekStart.add(Duration(days: i));
          final isToday = dayDate.year == now.year &&
              dayDate.month == now.month &&
              dayDate.day == now.day;
          final dayName =
              DateFormat('EEE', 'es_ES').format(dayDate).toUpperCase();
          return Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayName,
                    style: kaliColors.label(
                      isToday
                          ? kaliColors.espresso
                          : kaliColors.espresso.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isToday ? kaliColors.espresso : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${dayDate.day}',
                      style: kaliColors.body(
                        isToday ? kaliColors.warmWhite : kaliColors.espresso,
                        weight: isToday ? FontWeight.w700 : FontWeight.w400,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Cuerpo del calendario: horas + grilla por día ─────────────────────────
  Widget _buildScheduleBody(KaliColorsExtension kaliColors) {
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) {
        const double minSlotH = 17.0;
        final double slotH = (constraints.maxHeight / _totalSlots)
            .clamp(minSlotH, double.infinity);
        final double totalH = slotH * _totalSlots;

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeLabels(slotH, kaliColors),
            ...List.generate(7, (dayIdx) {
              final dayDate = currentWeekStart.add(Duration(days: dayIdx));
              final isToday = dayDate.year == now.year &&
                  dayDate.month == now.month &&
                  dayDate.day == now.day;
              return Expanded(
                child: DayColumn(
                  dayIndex: dayIdx,
                  isToday: isToday,
                  turnos: sessions.where((t) => t.dayIndex == dayIdx).toList(),
                  selectedTurno: selectedTurno,
                  onTurnoSelected: onTurnoSelected,
                  startHour: _startHour,
                  slotHeight: slotH,
                  totalSlots: _totalSlots,
                ),
              );
            }),
          ],
        );

        if (totalH > constraints.maxHeight) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SizedBox(height: totalH, child: row),
          );
        }
        return SizedBox(height: constraints.maxHeight, child: row);
      },
    );
  }

  // ── Columna lateral de horas ───────────────────────────────────────────────
  Widget _buildTimeLabels(double slotH, KaliColorsExtension kaliColors) {
    return buildTimeLabelsColumn(
      slotH: slotH,
      startHour: _startHour,
      totalSlots: _totalSlots,
      slotsPerHour: _slotsPerHour,
      kaliColors: kaliColors,
    );
  }
}
