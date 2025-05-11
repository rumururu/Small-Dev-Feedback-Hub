import 'package:androidtestnreviewexchange/app/middleware/notification_service.dart';
import 'package:androidtestnreviewexchange/app/routes/app_routes.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/bindings/init_binding.dart';
import 'app/middleware/package_checker_service.dart';
import 'app/routes/app_pages.dart';
import 'app/utils/constants.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';



// Firebase 백그라운드 메시지 핸들러 설정 (main() 함수 바깥에 정의)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await firebaseMessagingBackgroundHandler(message);
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp();

  // 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await dotenv.load(fileName: 'assets/.env');
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  // Initialize notification handling
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  await NotificationService.initialize(navigatorKey);
  await PackageCheckerService.registerBackgroundTask();
  initWebViewPlatform();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  // 전역 네비게이터 키 (알림에서 라우팅에 사용)
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();



  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Ensure this is set for navigation from notifications
      initialBinding: InitBinding(),
      initialRoute: AppRoutes.LOGIN,
      getPages: AppPages.pages,
    );
  }
}

void initWebViewPlatform() {
  // Initialize WebView platform with specific settings
  late final WebViewPlatform platform;

  if (WebViewPlatform.instance == null) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      platform = AndroidWebViewPlatform();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      platform = WebKitWebViewPlatform();
    } else {
      // Fallback to Android WebView on other platforms like desktop
      platform = AndroidWebViewPlatform();
    }

    WebViewPlatform.instance = platform;
  }
}