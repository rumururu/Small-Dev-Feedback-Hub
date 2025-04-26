import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
/// Supabase 'notifications' 테이블 CRUD for in-app notifications.
class NotificationsProvider {
  final _client = Supabase.instance.client;

  /// Stream of notifications for the current user, newest first.
  Stream<List<NotificationModel>> streamNotifications() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      // No user signed in: return an empty stream
      return Stream.value(<NotificationModel>[]);
    }
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((maps) => maps.map((m) => NotificationModel.fromMap(m)).toList());
  }

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) {
    return _client
        .from('notifications')
        .update({'read': true})
        .eq('id', notificationId);
  }
}
