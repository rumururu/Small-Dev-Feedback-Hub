import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';

import '../utils/constants.dart';

// Prevent multiple Supabase initializations
bool _supabaseInitialized = false;

// 백그라운드 isolate와 main isolate 간 통신을 위한 포트 이름
const String BACKGROUND_PORT_NAME = 'background_port';

// 백그라운드 태스크를 위한 top-level 함수
@pragma('vm:entry-point')
void packageCheckCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  if (!_supabaseInitialized) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _supabaseInitialized = true;
  }

  if (kDebugMode) {
    print('packageCheckCallback triggered at ${DateTime.now()}');
  }

  // SendPort를 찾아 메인 isolate에 메시지를 보내기 위한 시도
  final SendPort? sendPort = IsolateNameServer.lookupPortByName(BACKGROUND_PORT_NAME);
  sendPort?.send('Background task started');

  try {
    await PackageCheckerService().performDailyCheck();
    sendPort?.send('Background task completed successfully');
  } catch (e) {
    print('Error in background task: $e');
    sendPort?.send('Background task failed: $e');
  }
}

class PackageCheckerService {
  static DateTime? lastCheckDate;
  static const String _lastCheckDateKey = 'last_package_check_date';
  static const String _backgroundTaskStatusKey = 'background_task_status';
  static const String taskName = 'package_check_task';
  static const int ALARM_ID = 42; // 유니크한 ID 사용

  /// 초기화 시 SharedPreferences에서 마지막 체크 날짜를 읽어 메모리에 저장
  static Future<void> initLastCheckDate() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastCheckDateKey);
    lastCheckDate = last != null ? DateTime.tryParse(last) : null;
  }

  Future<void> performDailyCheck() async {
    // 메모리 캐시에 저장된 마지막 체크 날짜가 없다면 초기화
    if (lastCheckDate == null) {
      await initLastCheckDate();
    }

    if (kDebugMode) {
      print('performDailyCheck start at ${DateTime.now()}...');
    }

    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_backgroundTaskStatusKey, 'performDailyCheck started: ${DateTime.now()}');

    if (!await shouldPerformDailyCheck()) {
      if (kDebugMode) {
        print('Daily check not needed at this time');
      }
      prefs.setString(_backgroundTaskStatusKey, 'Daily check skipped: ${DateTime.now()}');
      return;
    }

    try {
      await performInstallCheck();
      prefs.setString(_backgroundTaskStatusKey, 'performDailyCheck completed: ${DateTime.now()}');
      if (kDebugMode) {
        print('performDailyCheck completed successfully');
      }
    } catch (e) {
      prefs.setString(_backgroundTaskStatusKey, 'Error in performDailyCheck: $e');
      if (kDebugMode) {
        print('Error in performDailyCheck: $e');
      }
      rethrow;
    }
  }

  Future<bool> shouldPerformDailyCheck() async {
    // Physical device check
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    if (!androidInfo.isPhysicalDevice) {
      if (kDebugMode) {
        print('Not a physical device, skipping check');
      }
      return false;
    }

    // Ensure lastCheckDate is initialized
    if (lastCheckDate == null) {
      await initLastCheckDate();
    }

    final last = lastCheckDate;
    final now = DateTime.now();

    if (last == null) {
      if (kDebugMode) {
        print('No previous check timestamp, proceeding');
      }
      return true;
    }

    final hoursSinceLast = now.difference(last).inHours;
    if (kDebugMode) {
      print('Hours since last check: $hoursSinceLast');
    }
    // Only perform if 12 hours have passed
    return hoursSinceLast >= installRecheckHour; ///To-do 수정해야함
  }

  static Future<bool> performInstallCheck() async {
    if (kDebugMode) {
      print('performInstallCheck start...');
    }
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String();

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (kDebugMode) {
        print('No user logged in, skipping check');
      }
      return false;
    }

    if (kDebugMode) {
      print('Fetching participations for user: $userId');
    }
    try {
      // 참여 중인 테스트 요청 가져오기
      final participations = await Supabase.instance.client
          .from('participations')
          .select('request_id, requests:requests!participations_request_id_fkey(id, request_type, status, target_app_id)')
          .eq('user_id', userId);

      if (kDebugMode) {
        print('Found ${participations.length} participations');
      }
      final List<String> matchedRequestIds = [];

      for (final p in participations as List<dynamic>) {
        final request = p['requests'];
        if (request == null ||
            request['request_type'] != 'test' ||
            !(request['status'] == 'open' || request['status'] == 'test')) {
          continue;
        }

        final appId = request['target_app_id'];
        if (kDebugMode) {
          print('Checking app with ID: $appId');
        }

        final packageRes = await Supabase.instance.client
            .from('user_apps')
            .select('package_name')
            .eq('id', appId)
            .maybeSingle();

        final packageName = packageRes?['package_name'];
        if (packageName != null) {
          if (kDebugMode) {
            print('Checking if package exists: $packageName');
          }
          final exists = await PackageCheckerService()._checkPackageExists(packageName);
          if (exists) {
            if (kDebugMode) {
              print('Package found: $packageName');
            }
            matchedRequestIds.add(p['request_id']);
          } else {
            if (kDebugMode) {
              print('Package not found: $packageName');
            }
          }
        }
      }

      if (matchedRequestIds.isNotEmpty) {
        print('Updating matched requests: $matchedRequestIds');
        await Supabase.instance.client
            .from('participations')
            .update({'last_install_check': DateTime.now().toIso8601String()})
            .inFilter('request_id', matchedRequestIds)
            .eq('user_id', userId);
      }

      await prefs.setString(_lastCheckDateKey, today);
      PackageCheckerService.lastCheckDate = DateTime.parse(today);
      if (kDebugMode) {
        print('performInstallCheck completed successfully');
      }
      return true;
    } catch (e) {
      print('Error in performInstallCheck: $e');
      return false;
    }
  }

  /// Android Alarm Manager 백그라운드 작업 등록
  static Future<bool> registerBackgroundTask() async {
    if (kDebugMode) {
      print('Registering background task...');
    }

    // 포트 등록을 통한 isolate 간 통신 설정
    final ReceivePort port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, BACKGROUND_PORT_NAME);

    port.listen((message) {
      print('Message from background isolate: $message');
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString(_backgroundTaskStatusKey, 'Background task registration started: ${DateTime.now()}');

      final initialized = await AndroidAlarmManager.initialize();
      if (!initialized) {
        print('Failed to initialize AndroidAlarmManager');
        prefs.setString(_backgroundTaskStatusKey, 'Failed to initialize AndroidAlarmManager: ${DateTime.now()}');
        return false;
      }

      print('AndroidAlarmManager initialized successfully');

      // 기존 알람이 있다면 취소
      await AndroidAlarmManager.cancel(ALARM_ID);

      // 새 알람 등록 - 15분마다 실행 (더 안정적인 실행을 위해 간격 늘림)
      final success = await AndroidAlarmManager.periodic(
        const Duration(minutes: 120), // 1분에서 15분으로 변경
        ALARM_ID,
        packageCheckCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true, // Doze 모드에서도 실행되도록 설정
      );

      if (success) {
        print('Background task registered successfully');
        prefs.setString(_backgroundTaskStatusKey, 'Background task registered: ${DateTime.now()}');

        // 즉시 한 번 실행해서 테스트
        final immediateSuccess = await AndroidAlarmManager.oneShot(
          const Duration(seconds: 5),
          ALARM_ID + 1, // 다른 ID 사용
          packageCheckCallback,
          exact: true,
          wakeup: true,
          allowWhileIdle: true,
        );

        print('Immediate test alarm set: $immediateSuccess');
      } else {
        print('Failed to register background task');
        prefs.setString(_backgroundTaskStatusKey, 'Failed to register background task: ${DateTime.now()}');
      }

      return success;
    } catch (e) {
      print('Error registering background task: $e');
      final prefs = await SharedPreferences.getInstance();
      prefs.setString(_backgroundTaskStatusKey, 'Error registering background task: $e');
      return false;
    }
  }

  Future<bool> _checkPackageExists(String packageName) async {
    try {
      return (await InstalledApps.isAppInstalled(packageName)) ?? false;
    } catch (e) {
      print('Error checking if package exists: $e');
      return false;
    }
  }

  static Future<String?> getBackgroundTaskStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backgroundTaskStatusKey);
  }

  /// 백그라운드 작업에 필요한 모든 권한 요청
  static Future<bool> requestRequiredPermissions() async {
    print('Requesting required permissions...');
    Map<Permission, PermissionStatus> statuses = await [
      Permission.ignoreBatteryOptimizations,
      Permission.notification,
      Permission.scheduleExactAlarm,
    ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      print('Permission $permission: $status');
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    return allGranted;
  }
}

// 앱 시작시 호출되는 함수
Future<void> initializeBackgroundServices() async {
  print('Initializing background services...');


  final success = await PackageCheckerService.registerBackgroundTask();
  print('Background services initialization ${success ? "successful" : "failed"}');
}

/// 사용자에게 백그라운드 권한을 요청하는 다이얼로그를 표시하는 함수
Future<void> showBackgroundPermissionDialog(BuildContext context) async {

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('배터리 사용량 최적화 중지 요청'),
        content: SingleChildScrollView(
          child: ListBody(
            children: const <Widget>[
              Text(
                '테스트 앱 설치 여부의 백그라운드 확인을 위해 배터리 사용량 최적화 중지를 요청합니다.',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('확인'),
            onPressed: () async {
              Navigator.of(context).pop();
              // 요청 인텐트 호출
              final uri = Uri.parse('package:com.mkideabox.androidtestnreviewexchange');
              await AndroidIntent(
                action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
                data: uri.toString(),
              ).launch();
              // 필요한 권한 요청
              final permissionsGranted = await PackageCheckerService.requestRequiredPermissions();
              print('Permissions granted: $permissionsGranted');
            },
          ),
        ],
      );
    },
  );
}