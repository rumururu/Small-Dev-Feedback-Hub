import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../pages/noti_list_page.dart';

class NotificationBadgeButton extends StatefulWidget {
  const NotificationBadgeButton({super.key});

  @override
  State<NotificationBadgeButton> createState() => _NotificationBadgeButtonState();
}

class _NotificationBadgeButtonState extends State<NotificationBadgeButton> {
  final _supabase = Supabase.instance.client;
  late String _userId;
  int _unreadCount = 0;
  late RealtimeChannel _notificationsChannel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _userId = _supabase.auth.currentUser!.id;
    _fetchInitialCount();
    _setupRealtimeSubscription();
  }

  Future<void> _fetchInitialCount() async {
    try {
      final count = await _supabase
          .from('notifications')
          .count()
          .eq('user_id', _userId)
          .eq('read', false);

      if (mounted) {
        setState(() {
          _unreadCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notification count: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupRealtimeSubscription() {
    // Create a channel for notifications table
    _notificationsChannel = _supabase.channel('public:notifications');

    // Set up listeners for INSERT and UPDATE events
    _notificationsChannel = _notificationsChannel
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      callback: (payload) {
        final data = payload.newRecord;
        if (data['user_id'] == _userId && data['read'] == false) {
          setState(() => _unreadCount++);
        }
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'notifications',
      callback: (payload) {
        final oldData = payload.oldRecord;
        final newData = payload.newRecord;

        // Handle cases where a notification is marked as read
        if (newData['user_id'] == _userId &&
            oldData['read'] == false &&
            newData['read'] == true &&
            _unreadCount > 0) {
          setState(() => _unreadCount--);
        }
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'notifications',
      callback: (payload) {
        final oldData = payload.oldRecord;
        if (oldData['user_id'] == _userId &&
            oldData['read'] == false &&
            _unreadCount > 0) {
          setState(() => _unreadCount--);
        }
      },
    );

    // Subscribe to the channel
    _notificationsChannel.subscribe();
  }

  @override
  void dispose() {
    _supabase.channel('public:notifications').unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications),
          if (_unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (_isLoading)
            const Positioned(
              right: -2,
              top: -2,
              child: SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              ),
            ),
        ],
      ),
      onPressed: () {
        Get.to(() => const NotificationListPage());
      },
    );
  }
}