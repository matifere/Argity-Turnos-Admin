import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:argrity/services/profile_cache.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc() : super(DashboardState()) {
    on<DashboardLoadRequested>(_onLoadRequested);
  }

  Future<void> _onLoadRequested(
    DashboardLoadRequested event,
    Emitter<DashboardState> emit,
  ) async {
    if (!state.hasLoaded) {
      emit(state.copyWith(isLoading: true, error: null));
    }
    try {
      final now = DateTime.now();
      final todayIso = DateFormat('yyyy-MM-dd').format(now);
      final supabase = Supabase.instance.client;

      // Las stats deben ser solo de la institución del usuario.
      final instId = ProfileCache.institutionId;

      String? joinCode;
      if (instId != null) {
        try {
          debugPrint('DASHBOARD: instId is $instId');
          final instData = await supabase
              .from('institutions')
              .select('join_code')
              .eq('id', instId)
              .maybeSingle();
          debugPrint('DASHBOARD: instData is $instData');
          joinCode = instData?['join_code'] as String?;
          if (joinCode == null || joinCode.isEmpty) {
            debugPrint('DASHBOARD: joinCode is null/empty, generating new one...');
            const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
            final rnd = Random();
            joinCode = String.fromCharCodes(Iterable.generate(
                8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
            await supabase
                .from('institutions')
                .update({'join_code': joinCode}).eq('id', instId);
            debugPrint('DASHBOARD: generated and updated joinCode: $joinCode');
          } else {
            debugPrint('DASHBOARD: found existing joinCode: $joinCode');
          }
        } catch (e) {
          debugPrint('DASHBOARD ERROR IN QR: $e');
        }
      } else {
        debugPrint('DASHBOARD: instId is NULL');
      }

      // Ambas queries en paralelo
      var sessionsQuery = supabase
          .from('class_sessions')
          .select('id, capacity, reservations(id, status)')
          .eq('date', todayIso)
          .neq('status', 'cancelled');
      if (instId != null) {
        sessionsQuery = sessionsQuery.eq('institution_id', instId);
      }
      final sessionsFuture = sessionsQuery;

      // Ingresos = mismo cálculo que la tarjeta de Pagos: precio del plan de
      // las suscripciones activas de la institución. Se filtra igual que
      // PagosBloc (por el institution_id del perfil del alumno).
      final subsFuture = supabase.from('subscriptions').select(
            'status, end_date, '
            'profiles!subscriptions_user_id_fkey(institution_id), '
            'plans(price)',
          );

      final sessions = await sessionsFuture as List<dynamic>;
      final subsData = await subsFuture;

      int turnosHoy = sessions.length;
      int capacidadTotal = 0;
      int alumnosPresentes = 0;

      for (final session in sessions) {
        capacidadTotal += (session['capacity'] as int? ?? 0);
        final reservations = session['reservations'] as List<dynamic>? ?? [];
        for (final res in reservations) {
          if (res['status'] == 'attended') alumnosPresentes++;
        }
      }

      final today = DateTime(now.year, now.month, now.day);
      double ingresos = 0.0;
      int vencimientosProximos = 0;
      for (final sub in subsData) {
        // Filtro de institución (igual que PagosBloc).
        if (instId != null) {
          final p = sub['profiles'];
          final pInst = p is Map
              ? p['institution_id']
              : (p is List && p.isNotEmpty ? p.first['institution_id'] : null);
          if (pInst != instId) continue;
        }
        // Solo activas y no vencidas por fecha (PagosBloc marca expired si
        // hoy > end_date, y esas no cuentan como ingreso).
        if (sub['status'] != 'active') continue;
        final endStr = sub['end_date'] as String?;
        final end = endStr != null ? DateTime.tryParse(endStr) : null;
        if (end != null) {
          final endDay = DateTime(end.year, end.month, end.day);
          if (today.isAfter(endDay)) continue;
          if (endDay.difference(today).inDays <= 7) vencimientosProximos++;
        }
        final plan = sub['plans'];
        final planMap =
            plan is List ? (plan.isNotEmpty ? plan.first : null) : plan;
        final price = (planMap is Map ? planMap['price'] as num? : null) ?? 0;
        ingresos += price.toDouble();
      }
      
      debugPrint('DASHBOARD: Emitting state with joinCode: $joinCode, ingresos: $ingresos');
      emit(state.copyWith(
        turnosActivosHoy: turnosHoy,
        alumnosPresentesHoy: alumnosPresentes,
        capacidadTotalHoy: capacidadTotal,
        ingresosMensuales: ingresos,
        vencimientosProximos: vencimientosProximos,
        joinCode: joinCode,
        isLoading: false,
        hasLoaded: true,
      ));
    } catch (e) {
      debugPrint('DASHBOARD BLOC ERROR: $e');
      emit(state.copyWith(
        isLoading: false,
        error: 'Error al cargar estadísticas: $e',
      ));
    }
  }
}
