// lib/ui/pages/noti_list_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/request_model.dart';
import '../../data/providers/requests_provider.dart';
import '../../routes/app_routes.dart';
import '../../utils/notification_templates.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  final supabase = Supabase.instance.client;
  late final String userId;
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  late RealtimeChannel _notificationsChannel;

  @override
  void initState() {
    super.initState();
    userId = supabase.auth.currentUser!.id;
    _fetchNotifications();
    _setupRealtimeSubscription();
  }

  Future<void> _fetchNotifications() async {
    try {
      final data = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          notifications = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      }

      // Mark all unread notifications as read in a single batch operation
      final unreadIds = notifications
          .where((noti) => noti['read'] == false)
          .map((noti) => noti['id'])
          .toList();

      if (unreadIds.isNotEmpty) {
        await supabase
            .from('notifications')
            .update({'read': true})
            .filter('id', 'in', unreadIds);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching notifications: $e');
      }
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _setupRealtimeSubscription() {
    _notificationsChannel = supabase.channel('public:notifications:$userId');

    _notificationsChannel = _notificationsChannel
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        final newNotification = payload.newRecord;

        if (mounted) {
          setState(() {
            notifications.insert(0, Map<String, dynamic>.from(newNotification));
          });

          // Mark as read
          supabase
              .from('notifications')
              .update({'read': true})
              .eq('id', newNotification['id']);
        }
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        final updatedNotification = payload.newRecord;

        if (mounted) {
          setState(() {
            final index = notifications.indexWhere(
                    (noti) => noti['id'] == updatedNotification['id']
            );
            if (index != -1) {
              notifications[index] = Map<String, dynamic>.from(updatedNotification);
            }
          });
        }
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        final deletedId = payload.oldRecord['id'];

        if (mounted) {
          setState(() {
            notifications.removeWhere((noti) => noti['id'] == deletedId);
          });
        }
      },
    );

    _notificationsChannel.subscribe();
  }

  @override
  void dispose() {
    _notificationsChannel.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 목록'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
          ? const Center(child: Text('알림이 없습니다.'))
          : RefreshIndicator(
        onRefresh: _fetchNotifications,
        child: ListView.separated(
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final row = notifications[idx];

            // payload 에 type이 들어있다고 가정
            final payload = row['payload'] as Map<String, dynamic>;
            final typeString = row['action'] as String? ?? '';
            final matching = NotificationType.values.where(
                  (e) => e.toString().split('.').last == typeString,
            );
            final type = matching.isNotEmpty
                ? matching.first
                : NotificationType.participationRequest;

            final template = notificationTemplates[type]!;

            // string map 으로 변환
            final params = payload.map(
                    (k, v) => MapEntry(k.toString(), v.toString())
            );
            final body = template.bodyBuilder(params);

            // 생성 시간 포맷
            final created = DateTime.parse(row['created_at'] as String)
                .toLocal()
                .toString()
                .split('.')[0];
            final requestId = payload['requestId'] as String?;

            return ListTile(
              title: Text(template.title),
              subtitle: Text(body),
              trailing: Text(
                created,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () async {
                if (requestId != null) {
                  try {
                    final reqProv = RequestsProvider();
                    final RequestModel? targetReq = await reqProv.fetchSingleRequest(
                      requestId,
                    );
                    if (targetReq != null) {
                      Get.toNamed(AppRoutes.DETAIL, arguments: targetReq);
                    } else {
                      if (kDebugMode) {
                        print('요청 정보를 찾을 수 없음: $requestId');
                      }
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print('요청 정보 가져오기 오류: $e');
                    }
                  }
                }
              },
            );
          },
        ),
      ),
    );
  }
}