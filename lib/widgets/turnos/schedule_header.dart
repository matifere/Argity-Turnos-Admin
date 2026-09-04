import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:argrity/theme/kali_colors_extension.dart';
import 'package:argrity/bloc/turnos/turnos_bloc.dart';
import 'package:intl/intl.dart';

/// Header del calendario semanal con título, rango de fechas y filtros.
class ScheduleHeader extends StatelessWidget {
  final DateTime currentWeekStart;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback? onCreateTurno;
  final VoidCallback? onAddHoliday;
  final bool showInstructorFilter;
  final bool showDropdownFilters;
  final String? selectedInstructor;
  final String? selectedRoom;
  final List<String> availableInstructors;
  final List<String> availableRooms;
  final void Function(String? instructor, String? room) onFilterChanged;
  
  // Novedad: vista del calendario
  final CalendarView viewMode;
  final ValueChanged<CalendarView> onViewModeChanged;

  const ScheduleHeader({
    super.key,
    required this.currentWeekStart,
    required this.onPreviousWeek,
    required this.onNextWeek,
    this.onCreateTurno,
    this.onAddHoliday,
    this.showInstructorFilter = true,
    this.showDropdownFilters = true,
    required this.selectedInstructor,
    required this.selectedRoom,
    required this.availableInstructors,
    required this.availableRooms,
    required this.onFilterChanged,
    this.viewMode = CalendarView.weekly,
    required this.onViewModeChanged,
  });

  String get _weekRange {
    const formatStr = "dd MMM";
    if (viewMode == CalendarView.monthly) {
      // mostramos "Mes Año", la currentWeekStart puede ser cualquier dia del mes,
      // pero si navegamos apuntamos al dia 1. Si no, usamos el mes actual de currentWeekStart, 
      // pero ojo, currentWeekStart siempre es Lunes, a veces el 1ro cae martes y currentWeekStart es del mes pasado.
      // Mejor basarnos en (currentWeekStart + 3 dias) que seguro cae en el mes foco
      final foco = currentWeekStart.add(const Duration(days: 3));
      final month = DateFormat('MMMM', 'es_ES').format(foco);
      return '${month[0].toUpperCase()}${month.substring(1)} ${foco.year}';
    }
    if (viewMode == CalendarView.yearly) {
      final foco = currentWeekStart.add(const Duration(days: 3));
      return '${foco.year}';
    }
    // viewMode == CalendarView.weekly
    final endOfWeek = currentWeekStart.add(const Duration(days: 6));
    return '${DateFormat(formatStr, 'es_ES').format(currentWeekStart)} — ${DateFormat(formatStr, 'es_ES').format(endOfWeek)}, ${endOfWeek.year}';
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    final bool isSmall = MediaQuery.of(context).size.width < 640;
    final filters = _filterWidgets(kaliColors);
    final actions = _actionWidgets(compact: isSmall, kaliColors: kaliColors);

    // ── Versión compacta para celular ─────────────────────────────────────────
    // Sin título grande (ya navegaste a Turnos) y todo en lo mínimo vertical
    // posible, porque con la barra de Chrome el alto útil es muy chico.
    if (isSmall) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _navControls(compact: true, kaliColors: kaliColors),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _weekRange,
                    style: kaliColors.body(kaliColors.espresso,
                        weight: FontWeight.w600, size: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (filters.isNotEmpty || actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [...filters, ...actions],
              ),
            ],
          ],
        ),
      );
    }

    // ── Versión escritorio ──────────────────────────────────────────────────
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Título y Controles de Navegación ──
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: [
              Text(
                viewMode == CalendarView.monthly
                    ? 'Calendario Mensual'
                    : viewMode == CalendarView.yearly
                        ? 'Calendario Anual'
                        : 'Calendario Semanal',
                style: kaliColors
                    .heading(kaliColors.espresso, size: 40)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              _navControls(compact: false, kaliColors: kaliColors),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _weekRange,
            style: kaliColors.body(
              kaliColors.espresso.withValues(alpha: 0.65),
              size: 14,
            ),
          ),
          const SizedBox(height: 20),

          // ── Filtros y Botones de Acción ──
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: filters,
                ),
                if (actions.isNotEmpty)
                  Wrap(spacing: 12, runSpacing: 12, children: actions),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Controles de navegación de semana (◀ ▶) ────────────────────────────────
  Widget _navControls(
      {required bool compact, required KaliColorsExtension kaliColors}) {
    final double iconSize = compact ? 20 : 24;
    final BoxConstraints? constraints =
        compact ? const BoxConstraints(minWidth: 36, minHeight: 36) : null;
    return Container(
      decoration: BoxDecoration(
        color: kaliColors.warmWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kaliColors.espresso.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, size: iconSize),
            onPressed: onPreviousWeek,
            color: kaliColors.espresso,
            tooltip: 'Semana Anterior',
            padding: compact ? EdgeInsets.zero : null,
            constraints: constraints,
          ),
          Container(
              width: 1,
              height: 24,
              color: kaliColors.espresso.withValues(alpha: 0.1)),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, size: iconSize),
            onPressed: onNextWeek,
            color: kaliColors.espresso,
            tooltip: 'Próxima Semana',
            padding: compact ? EdgeInsets.zero : null,
            constraints: constraints,
          ),
        ],
      ),
    );
  }

  // ── Dropdowns de filtro ────────────────────────────────────────────────────
  List<Widget> _filterWidgets(KaliColorsExtension kaliColors) {
    return [
      if (showDropdownFilters && showInstructorFilter)
        _FilterDropdown(
          label: selectedInstructor ?? 'Todos los Instructores',
          options: ['Todos los Instructores', ...availableInstructors],
          selectedValue: selectedInstructor ?? 'Todos los Instructores',
          onChanged: (val) {
            onFilterChanged(
              val == 'Todos los Instructores' ? null : val,
              selectedRoom,
            );
          },
        ),
      if (showDropdownFilters)
        _FilterDropdown(
          label: selectedRoom ?? 'Todas las Salas',
          options: ['Todas las Salas', ...availableRooms],
          selectedValue: selectedRoom ?? 'Todas las Salas',
          onChanged: (val) {
            onFilterChanged(
              selectedInstructor,
              val == 'Todas las Salas' ? null : val,
            );
          },
        ),
    ];
  }

  // ── Botones de acción (crear turno / plantillas) ───────────────────────────
  List<Widget> _actionWidgets(
      {required bool compact, required KaliColorsExtension kaliColors}) {
    final EdgeInsets pad = compact
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    return [
      _buildViewToggle(kaliColors: kaliColors, compact: compact),
      if (onAddHoliday != null)
        OutlinedButton.icon(
          onPressed: onAddHoliday,
          icon: Icon(Icons.event_busy_rounded,
              size: compact ? 18 : 20, color: kaliColors.espresso),
          label: Text(
            compact ? 'Feriado' : 'Agregar Feriado',
            style: kaliColors.body(kaliColors.espresso,
                weight: FontWeight.w600, size: 13),
          ),
          style: OutlinedButton.styleFrom(
            padding: pad,
            side: BorderSide(color: kaliColors.espresso.withValues(alpha: 0.2)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      if (onCreateTurno != null)
        ElevatedButton.icon(
          onPressed: onCreateTurno,
          icon: Icon(Icons.add_rounded,
              size: compact ? 18 : 20, color: kaliColors.warmWhite),
          label: Text(
            compact ? 'Turno' : 'Nuevo Turno',
            style: kaliColors.body(kaliColors.warmWhite,
                weight: FontWeight.w600, size: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: kaliColors.espresso,
            padding: pad,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
    ];
  }

  Widget _buildViewToggle({required KaliColorsExtension kaliColors, required bool compact}) {
    return SegmentedButton<CalendarView>(
      segments: const [
        ButtonSegment(
          value: CalendarView.weekly,
          label: Text('Semana'),
        ),
        ButtonSegment(
          value: CalendarView.monthly,
          label: Text('Mes'),
        ),
        ButtonSegment(
          value: CalendarView.yearly,
          label: Text('Año'),
        ),
      ],
      selected: {viewMode},
      onSelectionChanged: (Set<CalendarView> newSelection) {
        onViewModeChanged(newSelection.first);
      },
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        foregroundColor: kaliColors.espresso,
        selectedForegroundColor: kaliColors.warmWhite,
        selectedBackgroundColor: kaliColors.espresso,
        textStyle: kaliColors.body(kaliColors.espresso, weight: FontWeight.w600, size: 13),
      ),
    );
  }
}

// ─── Dropdown de filtro ───────────────────────────────────────────────────────
class _FilterDropdown extends StatefulWidget {
  final String label;
  final List<String> options;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  State<_FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<_FilterDropdown> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: kaliColors.warmWhite,
      elevation: 8,
      onSelected: widget.onChanged,
      itemBuilder: (context) => widget.options.map((option) {
        final isSelected = option == widget.selectedValue;
        return PopupMenuItem<String>(
          value: option,
          child: Text(
            option,
            style: kaliColors.body(
              isSelected
                  ? kaliColors.espresso
                  : kaliColors.espresso.withValues(alpha: 0.7),
              weight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        );
      }).toList(),
      child: MouseRegion(
        onEnter: (e) {
          if (e.kind == PointerDeviceKind.mouse) {
            setState(() => _hovered = true);
          }
        },
        onExit: (e) {
          if (e.kind == PointerDeviceKind.mouse) {
            setState(() => _hovered = false);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? kaliColors.sand : kaliColors.warmWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: kaliColors.espresso.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: kaliColors.body(
                  kaliColors.espresso,
                  weight: FontWeight.w500,
                  size: 13,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: kaliColors.espresso.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
