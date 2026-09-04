import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:argrity/models/class_session.dart';
import 'package:argrity/theme/kali_colors_extension.dart';

class MonthlySchedule extends StatelessWidget {
  final DateTime currentWeekStart;
  final List<ClassSession> sessions;
  final ClassSession? selectedTurno;
  final ValueChanged<ClassSession> onTurnoSelected;

  const MonthlySchedule({
    super.key,
    required this.currentWeekStart,
    required this.sessions,
    this.selectedTurno,
    required this.onTurnoSelected,
  });

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    
    // Determine the month we are looking at (using currentWeekStart + 3 days to avoid edge cases)
    final focusedMonth = currentWeekStart.add(const Duration(days: 3));
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    
    // We want the calendar to start on Monday.
    // weekday is 1 (Mon) to 7 (Sun).
    final offsetToMonday = firstDayOfMonth.weekday - 1;
    final totalDaysInGrid = lastDayOfMonth.day + offsetToMonday;
    // Calculate total rows needed (always 7 columns)
    final totalRows = (totalDaysInGrid / 7).ceil();
    final totalCells = totalRows * 7;

    return Column(
      children: [
        _buildDaysHeader(kaliColors),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: (constraints.maxWidth / 7) / (constraints.maxHeight / totalRows),
                ),
                itemCount: totalCells,
                itemBuilder: (context, index) {
                  final dayOffset = index - offsetToMonday;
                  final dayDate = firstDayOfMonth.add(Duration(days: dayOffset));
                  
                  final isCurrentMonth = dayDate.month == focusedMonth.month;
                  final now = DateTime.now();
                  final isToday = dayDate.year == now.year && dayDate.month == now.month && dayDate.day == now.day;
                  
                  final daySessions = sessions.where((s) => 
                    s.date.year == dayDate.year && s.date.month == dayDate.month && s.date.day == dayDate.day
                  ).toList()
                    ..sort((a, b) => a.startTime.compareTo(b.startTime));

                  return _buildDayCell(
                    context, 
                    dayDate, 
                    isCurrentMonth, 
                    isToday, 
                    daySessions, 
                    kaliColors
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDaysHeader(KaliColorsExtension kaliColors) {
    const days = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: kaliColors.espresso.withValues(alpha: 0.1))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: days.map((day) => Expanded(
          child: Center(
            child: Text(
              day,
              style: kaliColors.label(kaliColors.espresso.withValues(alpha: 0.7)),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context, 
    DateTime dayDate, 
    bool isCurrentMonth, 
    bool isToday, 
    List<ClassSession> daySessions, 
    KaliColorsExtension kaliColors
  ) {
    final bool hasSessions = daySessions.isNotEmpty;
    
    return GestureDetector(
      onTap: () => _showDayDialog(context, dayDate, daySessions, kaliColors),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: kaliColors.espresso.withValues(alpha: 0.05)),
            bottom: BorderSide(color: kaliColors.espresso.withValues(alpha: 0.05)),
          ),
          color: isCurrentMonth ? Colors.transparent : kaliColors.espresso.withValues(alpha: 0.02),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Day number header
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isToday ? kaliColors.espresso : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${dayDate.day}',
                    style: kaliColors.body(
                      isToday ? kaliColors.warmWhite : (isCurrentMonth ? kaliColors.espresso : kaliColors.espresso.withValues(alpha: 0.4)),
                      weight: isToday ? FontWeight.w700 : FontWeight.w500,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ),
            
            // Sessions
            if (hasSessions)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: daySessions.length,
                  itemBuilder: (context, i) {
                    final s = daySessions[i];
                    final isSelected = selectedTurno?.id == s.id;
  
                    final palette = [
                      kaliColors.clay,
                      kaliColors.clayDark,
                      kaliColors.sage,
                      kaliColors.sageLight,
                      kaliColors.sand2,
                    ];
  
                    Color bg;
                    if (s.isFull) {
                      bg = kaliColors.error;
                    } else {
                      bg = palette[s.name.hashCode.abs() % palette.length];
                    }
  
                    Color fg = bg.computeLuminance() > 0.5 ? kaliColors.espresso : kaliColors.warmWhite;
  
                    return GestureDetector(
                      onTap: () {
                        // Al tocar un turno específico directamente, lo selecciona (y no abre el modal de día).
                        onTurnoSelected(s);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(4),
                          border: isSelected ? Border.all(color: kaliColors.espresso, width: 1.5) : Border.all(color: Colors.transparent, width: 1.5),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: kaliColors.espresso.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: Text(
                          '${s.startTime.substring(0, 5)} ${s.name}',
                          style: kaliColors.body(
                            fg,
                            size: 11,
                            weight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayDialog(
    BuildContext context, 
    DateTime dayDate, 
    List<ClassSession> daySessions, 
    KaliColorsExtension kaliColors
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final formattedDate = DateFormat('EEEE d \'de\' MMMM', 'es_ES').format(dayDate);
        final capDate = '${formattedDate[0].toUpperCase()}${formattedDate.substring(1)}';

        return AlertDialog(
          backgroundColor: kaliColors.warmWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(capDate, style: kaliColors.heading(kaliColors.espresso, size: 20)),
          content: Container(
            width: 400,
            child: daySessions.isEmpty
              ? Text('No hay turnos agendados para este día.', style: kaliColors.body(kaliColors.espresso))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: daySessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = daySessions[i];
                    final isSelected = selectedTurno?.id == s.id;
                    
                    final palette = [
                      kaliColors.clay,
                      kaliColors.clayDark,
                      kaliColors.sage,
                      kaliColors.sageLight,
                      kaliColors.sand2,
                    ];
                    
                    Color bg;
                    if (s.isFull) {
                      bg = kaliColors.error;
                    } else {
                      bg = palette[s.name.hashCode.abs() % palette.length];
                    }
                    Color fg = bg.computeLuminance() > 0.5 ? kaliColors.espresso : kaliColors.warmWhite;
                    
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        onTurnoSelected(s);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected ? Border.all(color: kaliColors.espresso, width: 2) : Border.all(color: Colors.transparent, width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${s.startTime.substring(0, 5)} - ${s.name}',
                                style: kaliColors.body(fg, weight: FontWeight.w600, size: 14),
                              ),
                            ),
                            if (s.instructorName != null && s.instructorName!.isNotEmpty)
                              Text(
                                s.instructorName!,
                                style: kaliColors.body(fg.withValues(alpha: 0.8), size: 12),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar', style: kaliColors.body(kaliColors.espresso, weight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
