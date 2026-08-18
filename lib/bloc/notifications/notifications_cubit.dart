import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

class NotificationsState {
  final List<NotificationItem> notifications;
  NotificationsState({this.notifications = const []});

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  NotificationsState copyWith({List<NotificationItem>? notifications}) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
    );
  }
}

class NotificationsCubit extends Cubit<NotificationsState> {
  RealtimeChannel? _channel;

  NotificationsCubit() : super(NotificationsState()) {
    _initRealtime();
  }

  void _initRealtime() {
    // Escuchar broadcasts de Supabase (las notificaciones en memoria)
    // El webhook debe enviar mensajes a este canal:
    // supabase.channel('system_notifications').send({
    //   type: 'broadcast',
    //   event: 'new_notification',
    //   payload: { title: '...', message: '...' }
    // })
    _channel = Supabase.instance.client.channel('system_notifications');
    _channel!
        .onBroadcast(
            event: 'new_notification',
            callback: (payload) {
              final data = payload['payload'] ?? {};

              // Filtrar notificaciones dirigidas a otros usuarios
              final targetUserId = data['user_id']?.toString();
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              if (targetUserId != null && targetUserId != currentUserId) {
                return;
              }

              final title = data['title']?.toString() ?? 'Nueva notificación';
              final message = data['message']?.toString() ?? '';
              addNotification(title: title, message: message);
            })
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'class_sessions',
            callback: (payload) {
              final type = payload.eventType.name.toUpperCase();
              addNotification(
                title: 'Actividad en Turnos ($type)',
                message: 'Se registró un cambio en los turnos del sistema.',
              );
            })
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservations',
            callback: (payload) {
              final type = payload.eventType.name.toUpperCase();
              addNotification(
                title: 'Actividad en Inscripciones ($type)',
                message: 'Se registró un cambio en los inscriptos de un turno.',
              );
            })
        .subscribe();
  }

  void addNotification({required String title, required String message}) {
    final newItem = NotificationItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
    );
    final updatedList = List<NotificationItem>.from(state.notifications)
      ..insert(0, newItem);
    emit(state.copyWith(notifications: updatedList));
  }

  void markAsRead(String id) {
    final updatedList = state.notifications.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
    emit(state.copyWith(notifications: updatedList));
  }

  void markAllAsRead() {
    final updatedList =
        state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    emit(state.copyWith(notifications: updatedList));
  }

  /// Crea una notificacion por alumno en la tabla `notifications`. Cada fila
  /// dispara el push a Android/iOS (trigger `trg_send_push`) y le aparece al
  /// alumno en la campanita de su app.
  ///
  /// Devuelve a cuantos alumnos se les envio. El error se propaga a proposito:
  /// antes se lo tragaba un catch vacio y la pantalla cantaba exito igual, asi
  /// que un rechazo de RLS pasaba por envio hecho.
  Future<int> sendNotifications({
    required String title,
    required String message,
    required List<String> targetUserIds,
  }) async {
    final ids = targetUserIds.toSet().toList();
    if (ids.isEmpty) return 0;

    final rows = ids
        .map((id) => {
              'title': title,
              'body': message,
              'user_id': id,
              'type': 'general',
            })
        .toList();

    await Supabase.instance.client.from('notifications').insert(rows);
    return rows.length;
  }

  void clearAll() {
    emit(state.copyWith(notifications: []));
  }

  @override
  Future<void> close() {
    _channel?.unsubscribe();
    return super.close();
  }
}
