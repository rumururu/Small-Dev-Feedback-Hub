

// lib/app/data/models/notification_model.dart

/// Notification model for Supabase 'notifications' table
class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String message;
  final DateTime createdAt;
  final bool read;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.createdAt,
    required this.read,
  });

  /// Create from Supabase map
  factory NotificationModel.fromMap(Map<String, dynamic> m) {
    return NotificationModel(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      type: m['type'] as String,
      message: m['message'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      read: m['read'] as bool? ?? false,
    );
  }

  /// Convert to map for insert/update
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'read': read,
    };
  }
}