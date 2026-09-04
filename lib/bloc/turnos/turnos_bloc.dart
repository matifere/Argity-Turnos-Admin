import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:argrity/bloc/activity/activity_bloc.dart';
import 'package:argrity/models/class_session.dart';
import 'package:argrity/services/profile_cache.dart';
import 'package:argrity/repositories/turnos_repository.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'turnos_event.dart';
part 'turnos_state.dart';

class TurnosBloc extends Bloc<TurnosEvent, TurnosState> {
  final ActivityBloc? _activityBloc;
  final TurnosRepository _repository;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounce;

  /// Expuesto para que la UI pueda pre-calcular una proyección recurrente
  /// (ver [TurnosRepository.planRecurrentEnrollment]) antes de despachar.
  TurnosRepository get repository => _repository;

  TurnosBloc({ActivityBloc? activityBloc, required TurnosRepository repository})
      : _activityBloc = activityBloc,
        _repository = repository,
        super(TurnosState(currentWeekStart: _getStartOfWeek(DateTime.now()))) {
    on<TurnosLoadRequested>(_onLoadRequested);
    on<TurnosWeekChanged>(_onWeekChanged);
    on<TurnosViewModeChanged>(_onViewModeChanged);
    on<TurnoCreated>(_onTurnoCreated);
    on<TurnoSelected>(_onTurnoSelected);
    on<TurnoDeselected>(_onTurnoDeselected);
    on<TurnoDeleted>(_onTurnoDeleted);
    on<TurnoEdited>(_onTurnoEdited);
    on<TurnoStudentAssigned>(_onTurnoStudentAssigned);
    on<TurnoStudentRemoved>(_onTurnoStudentRemoved);
    on<TurnoStudentAttendanceToggled>(_onTurnoStudentAttendanceToggled);
    on<TurnosFilterChanged>(_onFilterChanged);
    on<HolidayAdded>(_onHolidayAdded);
    _initRealtime();
  }

  void _initRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('turnos_calendar')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservations',
            callback: (_) => _scheduleRealtimeReload())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'class_sessions',
            callback: (_) => _scheduleRealtimeReload())
      ..subscribe();
  }

  // Los eventos llegan en ráfagas (p. ej. una inscripción recurrente inserta
  // varias reservas); el debounce colapsa la ráfaga en una sola recarga.
  void _scheduleRealtimeReload() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!isClosed) add(TurnosLoadRequested(state.currentWeekStart));
    });
  }

  @override
  Future<void> close() {
    _realtimeDebounce?.cancel();
    _realtimeChannel?.unsubscribe();
    return super.close();
  }

  void _onViewModeChanged(
    TurnosViewModeChanged event,
    Emitter<TurnosState> emit,
  ) {
    emit(state.copyWith(viewMode: event.viewMode, clearSelection: true));
    add(TurnosLoadRequested(state.currentWeekStart));
  }

  Future<void> _onHolidayAdded(
    HolidayAdded event,
    Emitter<TurnosState> emit,
  ) async {
    try {
      final startDate = event.date;
      final endDate = event.endDate ?? event.date;
      final refund = event.refundCredits;

      final result = await _repository.cancelRangeAsHoliday(
        startDate,
        endDate,
        event.reason,
        refundCredits: refund,
      );
      final sessions = (result['sessions'] as int?) ?? 0;
      final reservations = (result['reservations'] as int?) ?? 0;

      final bool isRange = startDate.year != endDate.year ||
          startDate.month != endDate.month ||
          startDate.day != endDate.day;
      final fechaInicio = DateFormat('dd/MM', 'es_ES').format(startDate);
      final fechaFin = DateFormat('dd/MM', 'es_ES').format(endDate);
      final periodo = isRange ? 'del $fechaInicio al $fechaFin' : 'el $fechaInicio';

      final String creditosMsg;
      if (reservations == 0) {
        creditosMsg = '';
      } else if (refund) {
        creditosMsg =
            ', $reservations ${reservations == 1 ? 'crédito devuelto' : 'créditos devueltos'}';
      } else {
        creditosMsg =
            ', $reservations ${reservations == 1 ? 'clase perdida' : 'clases perdidas'}';
      }

      final String message = sessions == 0
          ? 'No había clases agendadas $periodo.'
          : 'Vacaciones aplicadas $periodo: $sessions ${sessions == 1 ? 'clase cancelada' : 'clases canceladas'}'
              '$creditosMsg.';

      emit(state.copyWith(infoMessage: message, clearSelection: true));

      if (sessions > 0) {
        _activityBloc?.add(ActivityLogged(ActivityEntry(
          title: 'Vacaciones aplicadas',
          subtitle: refund
              ? 'Se cancelaron $sessions clase(s) $periodo y se devolvieron $reservations crédito(s).'
              : 'Se cancelaron $sessions clase(s) $periodo; $reservations clase(s) perdida(s) sin reintegro.',
          category: ActivityCategory.turno,
          timestamp: DateTime.now(),
        )));
      }
      add(TurnosLoadRequested(state.currentWeekStart));
    } catch (e) {
      emit(state.copyWith(error: 'Error al aplicar las vacaciones: $e'));
    }
  }

  void _onFilterChanged(TurnosFilterChanged event, Emitter<TurnosState> emit) {
    emit(state.copyWith(
      selectedInstructor: () => event.instructor,
      selectedRoom: () => event.room,
    ));
  }

  static DateTime _getStartOfWeek(DateTime date) {
    // 1 is Monday
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _onLoadRequested(
    TurnosLoadRequested event,
    Emitter<TurnosState> emit,
  ) async {
    emit(state.copyWith(
        isLoading: true, clearError: true, clearInfoMessage: true));
    try {
      DateTime start = event.weekStart;
      DateTime end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      if (state.viewMode == CalendarView.monthly) {
        // En vista mensual cargamos todo el mes que contiene al currentWeekStart (jueves determina el mes)
        final focus = start.add(const Duration(days: 3));
        final monthStart = DateTime(focus.year, focus.month, 1);
        final monthEnd = DateTime(focus.year, focus.month + 1, 0, 23, 59, 59);
        start = monthStart.subtract(Duration(days: monthStart.weekday - 1)); // start at first Monday
        end = monthEnd.add(Duration(days: 7 - monthEnd.weekday, hours: 23, minutes: 59, seconds: 59)); // end at last Sunday
      } else if (state.viewMode == CalendarView.yearly) {
        // Para anual, quizás no necesitamos cargar turnos, pero por consistencia cargamos nada o lo mínimo
        // o si queremos puntitos por día con turnos, cargaríamos el año. Pero 1 año de turnos es pesado.
        // Lo dejamos vacío, el YearlyView mostrará los meses y al hacer click pasará a mensual.
        emit(state.copyWith(
          sessions: [],
          selectedTurno: null,
          isLoading: false,
        ));
        return;
      }

      final instId = ProfileCache.institutionId;
      final instructorFilter = state.selectedInstructor;

      final sessions = await _repository.getSessions(
        start: start,
        end: end,
        instId: instId,
        instructorFilter: instructorFilter,
      );

      ClassSession? freshSelected;
      if (state.selectedTurno != null) {
        try {
          freshSelected =
              sessions.firstWhere((s) => s.id == state.selectedTurno!.id);
        } catch (_) {
          freshSelected = state.selectedTurno;
        }
      }

      emit(state.copyWith(
        sessions: sessions,
        selectedTurno: freshSelected,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Error al cargar turnos: $e',
      ));
    }
  }

  Future<void> _onWeekChanged(
    TurnosWeekChanged event,
    Emitter<TurnosState> emit,
  ) async {
    final startOfWeek = _getStartOfWeek(event.newWeekStart);
    emit(state.copyWith(currentWeekStart: startOfWeek, clearSelection: true));
    add(TurnosLoadRequested(startOfWeek));
  }

  Future<void> _onTurnoCreated(
    TurnoCreated event,
    Emitter<TurnosState> emit,
  ) async {
    try {
      final instId = ProfileCache.institutionId;

      await _repository.createSessions(
        daysOfWeek: event.daysOfWeek,
        currentWeekStart: state.currentWeekStart,
        startTime: event.startTime,
        endTime: event.endTime,
        recurrenceWeeks: event.recurrenceWeeks,
        name: event.name,
        description: event.description,
        instructorName: event.instructorName,
        capacity: event.capacity,
        instId: instId,
      );

      _activityBloc?.add(ActivityLogged(ActivityEntry(
        title: 'Clase grupal creada',
        subtitle:
            '${event.name} agendado para ${event.recurrenceWeeks} semanas.',
        category: ActivityCategory.turno,
        timestamp: DateTime.now(),
      )));
      add(TurnosLoadRequested(state.currentWeekStart));
    } catch (e) {
      emit(state.copyWith(error: 'Error al crear la clase: $e'));
    }
  }

  void _onTurnoSelected(
    TurnoSelected event,
    Emitter<TurnosState> emit,
  ) {
    if (state.selectedTurno?.id == event.turno.id) {
      emit(state.copyWith(clearSelection: true));
    } else {
      emit(state.copyWith(selectedTurno: event.turno));
    }
  }

  void _onTurnoDeselected(
    TurnoDeselected event,
    Emitter<TurnosState> emit,
  ) {
    emit(state.copyWith(clearSelection: true));
  }

  Future<void> _onTurnoDeleted(
    TurnoDeleted event,
    Emitter<TurnosState> emit,
  ) async {
    try {
      if (event.deleteAllFuture) {
        await _repository.deleteSessions(
            event.session.groupId!, event.session.date);

        _activityBloc?.add(ActivityLogged(ActivityEntry(
          title: 'Serie de turnos cancelada',
          subtitle:
              'Se eliminaron las clases de ${event.session.name} hasta fin de año.',
          category: ActivityCategory.turno,
          timestamp: DateTime.now(),
        )));
      } else {
        await _repository.deleteSession(event.session.id);

        _activityBloc?.add(ActivityLogged(ActivityEntry(
          title: 'Turno cancelado',
          subtitle: 'Se eliminó la sesión del cronograma.',
          category: ActivityCategory.turno,
          timestamp: DateTime.now(),
        )));
      }

      emit(state.copyWith(clearSelection: true));
      add(TurnosLoadRequested(state.currentWeekStart));
    } catch (e) {
      emit(state.copyWith(error: 'Error al cancelar turno: $e'));
    }
  }

  Future<void> _onTurnoEdited(
    TurnoEdited event,
    Emitter<TurnosState> emit,
  ) async {
    final t = event.turno;
    try {
      if (event.editFutureSessions && t.groupId != null) {
        await _repository.updateSessions(
          t.groupId!,
          t.date,
          {
            'name': t.name,
            'description': t.description,
            'start_time': t.startTime.substring(0, 5),
            'end_time': t.endTime.substring(0, 5),
            'capacity': t.capacity,
            'instructor_name': t.instructorName,
          },
        );
      } else {
        await _repository.updateSession(t.id, {
          'name': t.name,
          'description': t.description,
          'date': DateFormat('yyyy-MM-dd').format(t.date),
          'start_time': t.startTime.substring(0, 5),
          'end_time': t.endTime.substring(0, 5),
          'capacity': t.capacity,
          'instructor_name': t.instructorName,
        });
      }

      emit(state.copyWith(clearSelection: true));
      add(TurnosLoadRequested(state.currentWeekStart));
      _activityBloc?.add(ActivityLogged(ActivityEntry(
        title: 'Turno modificado',
        subtitle:
            '${t.name} actualizado para el ${DateFormat('dd/MM', 'es_ES').format(t.date)}.',
        category: ActivityCategory.turno,
        timestamp: DateTime.now(),
      )));
    } catch (e) {
      emit(state.copyWith(error: 'Error al editar turno: $e'));
    }
  }

  Future<void> _onTurnoStudentAssigned(
    TurnoStudentAssigned event,
    Emitter<TurnosState> emit,
  ) async {
    try {
      await _repository.assignStudent(
        userId: event.userId,
        session: event.session,
        enrollmentType: event.enrollmentType,
        projectedSessionIds: event.projectedSessionIds,
      );
      _activityBloc?.add(ActivityLogged(ActivityEntry(
        title: 'Alumno inscripto a turno',
        subtitle:
            'Inscripción confirmada en ${event.session.name}${event.enrollmentType != EnrollmentType.single ? ' (recurrente)' : ''}.',
        category: ActivityCategory.alumno,
        timestamp: DateTime.now(),
      )));
      add(TurnosLoadRequested(state.currentWeekStart));
    } catch (e) {
      emit(state.copyWith(error: 'Error al inscribir alumno: $e'));
    }
  }

  Future<void> _onTurnoStudentRemoved(
    TurnoStudentRemoved event,
    Emitter<TurnosState> emit,
  ) async {
    try {
      await _repository.removeStudent(event.reservationId);
      _activityBloc?.add(ActivityLogged(ActivityEntry(
        title: 'Alumno removido de turno',
        subtitle: 'Reserva cancelada y cupo liberado.',
        category: ActivityCategory.turno,
        timestamp: DateTime.now(),
      )));
      // Refrescar el turno seleccionado
      add(TurnosLoadRequested(state.currentWeekStart));
    } catch (e) {
      emit(state.copyWith(error: 'Error al desinscribir alumno: $e'));
    }
  }

  Future<void> _onTurnoStudentAttendanceToggled(
    TurnoStudentAttendanceToggled event,
    Emitter<TurnosState> emit,
  ) async {
    try {
      final nextStatus =
          event.currentStatus == 'attended' ? 'confirmed' : 'attended';
      await _repository.toggleAttendance(event.reservationId, nextStatus);

      // Refrescar para ver el cambio
      add(TurnosLoadRequested(state.currentWeekStart));
    } catch (e) {
      emit(state.copyWith(error: 'Error al marcar asistencia: $e'));
    }
  }
}
