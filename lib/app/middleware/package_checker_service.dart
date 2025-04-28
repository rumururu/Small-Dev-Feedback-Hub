import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:workmanager/workmanager.dart';

class PackageCheckerService {
  final _client = Supabase.instance.client;

  static const String _lastCheckDateKey = 'last_package_check_date';
  static const String taskName = 'package_check_task';

  Future<void> performDailyCheck() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final isPhysical = androidInfo.isPhysicalDevice;
    if (!isPhysical) {
      return; // 에뮬레이터에서는 체크 안 함
    }

    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(_lastCheckDateKey);

    final today = DateTime.now().toIso8601String().split('T').first;
    if (lastCheck == today) return; // 오늘 이미 실행됨

    // Supabase에서 모든 앱 패키지명 조회
    final apps = await _client.from('user_apps').select('id, package_name');

    final List<String> failedRequestIds = [];

    for (final app in apps as List<dynamic>) {
      final packageName = app['package_name'] as String;
      final exists = await _checkPackageExists(packageName);

      if (!exists) {
        final requestId = await _getRequestIdByAppId(app['id']);
        if (requestId != null) {
          failedRequestIds.add(requestId);
        }
      }
    }

    if (failedRequestIds.isNotEmpty) {
      final DateTime startTime = DateTime.now();
      bool success = false;
      while (!success) {
        try {
          await _client
              .from('participations')
              .update({'status': 'failed'})
              .inFilter('request_id', failedRequestIds)
              .neq('status', 'failed');
          success = true;
        } catch (_) {
          final elapsed = DateTime.now().difference(startTime);
          if (elapsed > const Duration(hours: 24)) {
            break; // 24시간 넘으면 포기
          }
          await Future.delayed(const Duration(hours: 3)); // 3시간 후 재시도
        }
      }
    }

    await prefs.setString(_lastCheckDateKey, today); // 실행 날짜 기록
  }

  /// 백그라운드 워커에서 호출될 작업 함수
  static void backgroundCheckTask() {
    PackageCheckerService().performDailyCheck();
  }

  /// Workmanager 백그라운드 작업 등록
  static Future<void> registerBackgroundTask() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(hours: 24),
    );
  }

  /// Workmanager 콜백 디스패처
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      await PackageCheckerService().performDailyCheck();
      return Future.value(true);
    });
  }

  Future<bool> _checkPackageExists(String packageName) async {
    return (await InstalledApps.isAppInstalled(packageName)) ?? false;
  }

  Future<String?> _getRequestIdByAppId(String appId) async {
    final res = await _client
        .from('requests')
        .select('id')
        .eq('target_app_id', appId)
        .maybeSingle();

    return res != null ? res['id'] as String : null;
  }
}