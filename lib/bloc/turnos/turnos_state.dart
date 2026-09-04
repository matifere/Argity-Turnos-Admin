part of 'turnos_bloc.dart';

enum CalendarView { weekly, monthly, yearly }

/// Estado del calendario de turnos.
class TurnosState {
  final List<ClassSession> sessions;

  /// La fecha representa siempre al lunes de la semana focalizada.
  final DateTime currentWeekStart;
  final bool isLoading;
  final String? error;

  /// Mensaje informativo transitorio (ej. resultado de cancelar un feriado).
  /// La UI lo muestra en un SnackBar y luego se limpia.
  final String? infoMessage;

  /// El turno actualmente seleccionado, o [null] si ninguno lo está.
  final ClassSession? selectedTurno;

  final String? selectedInstructor;
  final String? selectedRoom;

  final CalendarView viewMode;

  TurnosState({
    this.sessions = const [],
    required this.currentWeekStart,
    this.isLoading = true,
    this.error,
    this.infoMessage,
    this.selectedTurno,
    this.selectedInstructor,
    this.selectedRoom,
    this.viewMode = CalendarView.weekly,
  });

  bool get hasSelection => selectedTurno != null;

  // Computados una sola vez por instancia de estado (late final = lazy + cached).
  late final List<String> availableInstructors = () {
    final set = <String>{};
    for (final s in sessions) {
      final name = s.instructorName;
      if (name != null && name.isNotEmpty) set.add(name);
    }
    return set.toList()..sort();
  }();

  late final List<String> availableRooms = () {
    final set = <String>{};
    for (final s in sessions) {
      if (s.name.isNotEmpty) set.add(s.name);
    }
    return set.toList()..sort();
  }();

  late final List<ClassSession> filteredSessions = () {
    final noInstructor =
        selectedInstructor == null || selectedInstructor!.isEmpty;
    final noRoom = selectedRoom == null || selectedRoom!.isEmpty;
    if (noInstructor && noRoom) return sessions;
    return sessions.where((s) {
      if (!noInstructor && s.instructorName != selectedInstructor) return false;
      if (!noRoom && s.name != selectedRoom) return false;
      return true;
    }).toList();
  }();

  TurnosState copyWith({
    List<ClassSession>? sessions,
    DateTime? currentWeekStart,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? infoMessage,
    bool clearInfoMessage = false,
    ClassSession? selectedTurno,
    bool clearSelection = false,
    String? Function()? selectedInstructor,
    String? Function()? selectedRoom,
    CalendarView? viewMode,
  }) {
    return TurnosState(
      sessions: sessions ?? this.sessions,
      currentWeekStart: currentWeekStart ?? this.currentWeekStart,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      infoMessage: clearInfoMessage ? null : (infoMessage ?? this.infoMessage),
      selectedTurno:
          clearSelection ? null : (selectedTurno ?? this.selectedTurno),
      selectedInstructor: selectedInstructor != null
          ? selectedInstructor()
          : this.selectedInstructor,
      selectedRoom: selectedRoom != null ? selectedRoom() : this.selectedRoom,
      viewMode: viewMode ?? this.viewMode,
    );
  }
}
