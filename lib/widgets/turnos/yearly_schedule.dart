import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:argrity/theme/kali_colors_extension.dart';

class YearlySchedule extends StatelessWidget {
  final DateTime currentWeekStart;
  final ValueChanged<DateTime> onMonthSelected;

  const YearlySchedule({
    super.key,
    required this.currentWeekStart,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;
    
    // Focus year based on currentWeekStart
    final focusYear = currentWeekStart.add(const Duration(days: 3)).year;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Adjust cross axis count based on available width
          int crossAxisCount = 4; // desktop default
          if (constraints.maxWidth < 600) {
            crossAxisCount = 2; // mobile
          } else if (constraints.maxWidth < 900) {
            crossAxisCount = 3; // tablet
          }

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final monthDate = DateTime(focusYear, index + 1, 15); // use 15th to safely center in month
              return _MonthCard(
                monthDate: monthDate,
                kaliColors: kaliColors,
                onTap: () => onMonthSelected(monthDate),
              );
            },
          );
        },
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final DateTime monthDate;
  final KaliColorsExtension kaliColors;
  final VoidCallback onTap;

  const _MonthCard({
    required this.monthDate,
    required this.kaliColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM', 'es_ES').format(monthDate);
    final capitalizedMonth = '${monthName[0].toUpperCase()}${monthName.substring(1)}';
    
    final now = DateTime.now();
    final isCurrentMonth = monthDate.year == now.year && monthDate.month == now.month;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isCurrentMonth ? kaliColors.espresso : kaliColors.espresso.withValues(alpha: 0.1),
            width: isCurrentMonth ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: kaliColors.warmWhite,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentMonth ? kaliColors.espresso : kaliColors.espresso.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              alignment: Alignment.center,
              child: Text(
                capitalizedMonth,
                style: kaliColors.body(
                  isCurrentMonth ? kaliColors.warmWhite : kaliColors.espresso,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildMiniCalendar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCalendar() {
    // Generate a very small, non-interactive visual representation of the month's days
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstWeekday = DateTime(monthDate.year, monthDate.month, 1).weekday; // 1=Mon, 7=Sun
    final offset = firstWeekday - 1;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (col) {
            final dayIndex = row * 7 + col;
            final dayNum = dayIndex - offset + 1;
            final isValidDay = dayNum > 0 && dayNum <= daysInMonth;
            
            final isToday = isValidDay && 
              monthDate.year == DateTime.now().year && 
              monthDate.month == DateTime.now().month && 
              dayNum == DateTime.now().day;

            return Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isToday ? kaliColors.espresso : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: isValidDay 
                  ? Text(
                      '$dayNum',
                      style: kaliColors.body(
                        isToday ? kaliColors.warmWhite : kaliColors.espresso.withValues(alpha: 0.6),
                        size: 8,
                      ),
                    )
                  : const SizedBox.shrink(),
            );
          }),
        );
      }),
    );
  }
}
