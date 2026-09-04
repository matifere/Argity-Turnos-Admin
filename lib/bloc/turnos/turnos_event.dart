part of 'turnos_bloc.dart';

abstract class TurnosEvent {}

/// Solicita cargar los turnos para la semana indicada.
class TurnosLoadRequested extends TurnosEvent {
  final DateTime weekStart;
  TurnosLoadRequested(this.weekStart);
}

/// El usuario cambió de semana (avanzar/retroceder).
class TurnosWeekChanged extends TurnosEvent {
  final DateTime newWeekStart;
  TurnosWeekChanged(this.newWeekStart);
}

/// El usuario cambió la vista del calendario (semanal, mensual, anual).
class TurnosViewModeChanged extends TurnosEvent {
  final CalendarView viewMode;
  TurnosViewModeChanged(this.viewMode);
}

class TurnoCreated extends TurnosEvent {
  final String name;
  final String? description;
  final String? instructorName;
  final int capacity;
  final String startTime;
  final String endTime;
  final List<int> daysOfWeek;
  final int recurrenceWeeks;

  TurnoCreated({
    required this.name,
    this.description,
    this.instructorName,
    required this.capacity,
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
    this.recurrenceWeeks = 1,
  });
}

/// El usuario tocó una tarjeta de turno en el calendario.
/// Si [turno] ya estaba seleccionado, se deselecciona (toggle).
class TurnoSelected extends TurnosEvent {
  final ClassSession turno;

  TurnoSelected(this.turno);
}

/// El usuario cerró el panel de detalle.
class TurnoDeselected extends TurnosEvent {}

/// El usuario cancela (elimina) un turno.
class TurnoDeleted extends TurnosEvent {
  final ClassSession session;
  final bool deleteAllFuture;

  TurnoDeleted(this.session, {this.deleteAllFuture = false});
}

/// El usuario ha guardado la modificación de un turno.
class TurnoEdited extends TurnosEvent {
  final ClassSession turno;
  final bool editFutureSessions;

  TurnoEdited(this.turno, {this.editFutureSessions = false});
}

enum EnrollmentType {
  single,
  planValidity,
}

/// Se inscribe a un alumno a un turno
class TurnoStudentAssigned extends TurnosEvent {
  final String userId;
  final ClassSession session;
  final EnrollmentType enrollmentType;

  /// Clases futuras de la serie ya resueltas por la UI (incluyen las que
  /// superan el plan cuando el admin eligió forzarlas). Si es null, el
  /// repositorio proyecta respetando el cupo mensual del plan.
  final List<String>? projectedSessionIds;

  TurnoStudentAssigned({
    required this.userId,
    required this.session,
    this.enrollmentType = EnrollmentType.single,
    this.projectedSessionIds,
  });
}

/// Se des-inscribe/remueve a un alumno de un turno
class TurnoStudentRemoved extends TurnosEvent {
  final String reservationId;
  TurnoStudentRemoved(this.reservationId);
}

/// Marca la asistencia de un alumno (cambia status a 'attended' o 'confirmed')
class TurnoStudentAttendanceToggled extends TurnosEvent {
  final String reservationId;
  final String currentStatus;

  TurnoStudentAttendanceToggled({
    required this.reservationId,
    required this.currentStatus,
  });
}

/// El admin marca un día (o rango de vacaciones) como feriado: cancela las
/// clases comprendidas entre [date] y [endDate] inclusive. Si [refundCredits]
/// es true, devuelve el crédito a cada alumno inscripto; si es false, la clase
/// se pierde (la reserva queda marcada como ausente y no libera cupo).
class HolidayAdded extends TurnosEvent {
  final DateTime date;
  final DateTime? endDate;
  final String? reason;
  final bool refundCredits;

  HolidayAdded({
    required this.date,
    this.endDate,
    this.reason,
    this.refundCredits = true,
  });
}

/// El usuario cambió los filtros de instructores o salas
class TurnosFilterChanged extends TurnosEvent {
  final String? instructor;
  final String? room;

  TurnosFilterChanged({
    this.instructor,
    this.room,
  });
}
