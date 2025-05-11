import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/request_model.dart';
import '../data/providers/requests_provider.dart';
import '../utils/notification_templates.dart';
import '../routes/app_routes.dart';

// 최상위 함수: 로컬 알림 백그라운드 핸들러
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // 백그라운드에서는 최소한의 작업만 수행
  // 데이터를 저장하고 앱이 시작될 때 처리
  _handleBackgroundResponse(response);
}

// 백그라운드 응답 처리 헬퍼 함수
@pragma('vm:entry-point')
Future<void> _handleBackgroundResponse(NotificationResponse response) async {
  final payload = response.payload;
  if (payload != null) {
    try {
      // SharedPreferences에 데이터 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_notification_payload', payload);
      await prefs.setBool('notification_tapped_in_background', true);
    } catch (e) {
      if (kDebugMode) {
        print('백그라운드 알림 데이터 저장 오류: $e');
      }
    }
  }
}

// Firebase 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in this background isolate
  await Firebase.initializeApp();

  // Initialize local notifications plugin for background
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // 메시지 데이터 저장
  final prefs = await SharedPreferences.getInstance();
  if (message.data.isNotEmpty) {
    await prefs.setString('fcm_background_message', jsonEncode(message.data));
  }

  // 로컬 알림 생성
  await NotificationService._showLocalNotification(
    flutterLocalNotificationsPlugin,
    message.data,
  );
}

class NotificationService {
  // Android 채널 ID 및 이름
  static const String _channelId = 'default_channel';
  static const String _channelName = '알림 채널';

  // 로컬 알림 플러그인 인스턴스 (전역 상태로 관리)
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // 초기화 상태 플래그
  static bool _isInitialized = false;

  static Future<void> _handleNotificationAction(
      Map<String, dynamic> data,
      ) async {
    if (kDebugMode) {
      print('알림 처리 시작: $data');
    }

    final String? action = data['action'] as String?;
    final String? requestId = data['requestId'] as String?;

    if (kDebugMode) {
      print('알림 처리: action=$action, 요청ID=$requestId');
    }

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
  }

  /// 알림 처리 초기화: 로컬 알림 및 FCM 리스너 설정
  static Future<void> initialize(
      GlobalKey<NavigatorState> navigatorKey,
      ) async {
    // 이미 초기화된 경우 중복 초기화 방지
    if (_isInitialized) return;

    // 1) 로컬 알림 설정
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    // Android 채널 생성 (Android 8.0 이상 필수)
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Android 채널 등록
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // 알림 초기화
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          try {
            if (kDebugMode) {
              print('알림 탭 페이로드: $payload');
            }
            final data = jsonDecode(payload) as Map<String, dynamic>;
            await _handleNotificationAction(data);
          } catch (e) {
            if (kDebugMode) {
              print('알림 페이로드 처리 오류: $e');
            }
          }
        }
      },
      // 백그라운드 핸들러 등록
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 2) FCM 권한 요청
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // FCM 토큰 얻기
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (kDebugMode) {
      print('FCM 토큰: $fcmToken');
    }
    // 토큰을 서버에 저장하는 로직 추가 (필요한 경우)

    // 3) 백그라운드에서 저장된 알림 데이터 확인 및 처리
    await _checkSavedNotifications();

    // 4) 포그라운드 FCM 메시지 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('포그라운드 메시지 수신: ${message.data}');
        print('알림 제목: ${message.notification?.title}');
        print('알림 내용: ${message.notification?.body}');
      }

      // 포그라운드에서 로컬 알림 표시
      _showLocalNotification(
        _localNotifications,
        message.data,
      );
    });

    // 5) 앱이 종료된 상태에서 알림 탭 처리
    FirebaseMessaging.instance.getInitialMessage().then((message) async {
      if (message != null) {
        if (kDebugMode) {
          print('종료 상태에서 알림 탭: ${message.data}');
        }
        await _handleNotificationAction(message.data);
      }
    });

    // 6) 앱이 백그라운드에 있을 때 알림 탭 처리
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      if (kDebugMode) {
        print('백그라운드 알림 탭: ${message.data}');
      }
      await _handleNotificationAction(message.data);
    });

    _isInitialized = true;
  }

  // 저장된 알림 데이터 확인 및 처리
  static Future<void> _checkSavedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 로컬 알림에서 저장된 데이터 확인
      final notificationPayload = prefs.getString('last_notification_payload');
      final wasNotificationTapped =
          prefs.getBool('notification_tapped_in_background') ?? false;

      // FCM 백그라운드 메시지에서 저장된 데이터 확인
      final fcmBackgroundMessage = prefs.getString('fcm_background_message');

      // 저장된 데이터가 있으면 처리 - 먼저 로컬 알림 데이터 처리
      if (wasNotificationTapped && notificationPayload != null) {
        try {
          final data = jsonDecode(notificationPayload) as Map<String, dynamic>;
          // UI가 준비될 시간을 주기 위해 약간의 지연
          Future.delayed(const Duration(seconds: 1), () {
            _handleNotificationAction(data);
          });
        } catch (e) {
          if (kDebugMode) {
            print('저장된 알림 페이로드 처리 오류: $e');
          }
        }
      }
      // FCM 백그라운드 메시지 데이터 처리
      else if (fcmBackgroundMessage != null) {
        try {
          final data = jsonDecode(fcmBackgroundMessage) as Map<String, dynamic>;
          // UI가 준비될 시간을 주기 위해 약간의 지연
          Future.delayed(const Duration(seconds: 1), () {
            _handleNotificationAction(data);
          });
        } catch (e) {
          if (kDebugMode) {
            print('저장된 FCM 메시지 처리 오류: $e');
          }
        }
      }

      // 처리 후 데이터 삭제
      await prefs.remove('last_notification_payload');
      await prefs.remove('notification_tapped_in_background');
      await prefs.remove('fcm_background_message');
    } catch (e) {
      if (kDebugMode) {
        print('저장된 알림 확인 중 오류: $e');
      }
    }
  }

  // 로컬 알림 표시
  static Future<void> _showLocalNotification(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
      Map<String, dynamic> payload,
      ) async {
    try {
      if (kDebugMode) {
        print('로컬 알림 생성 시작: $payload');
      }

      // action을 사용하여 알림 타입 확인 (FCM 데이터에는 'type' 대신 'action'이 있음)
      final String? actionString = payload['action'] as String?;
      if (actionString == null) {
        if (kDebugMode) {
          print('알림 타입이 없어 기본 알림을 표시합니다.');
        }

        // 기본 알림 표시 (타입이 없는 경우)
        const androidDetails = AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          channelShowBadge: true,
        );
        const notificationDetails = NotificationDetails(android: androidDetails);

        await flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch.remainder(100000), // 유니크한 ID 생성
          payload['title'] as String? ?? '새 알림',
          payload['body'] as String? ?? '새로운 알림이 도착했습니다.',
          notificationDetails,
          payload: jsonEncode(payload),
        );
        return;
      }

      // actionString으로 NotificationType 매칭
      NotificationType? type;
      try {
        // action 값을 기반으로 NotificationType 찾기
        final matching = NotificationType.values.where(
              (e) => e.toString().split('.').last == actionString,
        );

        type = matching.isNotEmpty ? matching.first : NotificationType.participationRequest;
      } catch (e) {
        if (kDebugMode) {
          print('알림 타입 매칭 실패: $e, 기본 타입으로 진행');
        }
        type = NotificationType.participationRequest;
      }

      if (kDebugMode) {
        print('알림 타입: $type');
      }

      // 해당 타입의 템플릿 가져오기
      final template = notificationTemplates[type]!;
      final title = template.title;

      // String으로 변환된 파라미터 맵 생성
      final params = Map<String, String>.from(
          payload.map((k, v) => MapEntry(k, v?.toString() ?? ""))
      );

      final body = template.bodyBuilder(params);

      if (kDebugMode) {
        print('알림 제목: $title');
        print('알림 내용: $body');
      }

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        channelShowBadge: true,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      // 알림 표시
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000), // 유니크한 ID 생성
        title,
        body,
        notificationDetails,
        payload: jsonEncode(payload),
      );

      if (kDebugMode) {
        print('로컬 알림 생성 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('로컬 알림 생성 중 오류 발생: $e');
      }
    }
  }
}