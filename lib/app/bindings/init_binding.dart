import '../controllers/request_controller.dart';
import 'package:get/get.dart';
import '../controllers/app_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/main_controller.dart';
import '../data/providers/auth_provider.dart';

class InitBinding extends Bindings {
  @override
  void dependencies() {
    // Supabase Auth provider
    Get.lazyPut<AuthProvider>(() => AuthProvider(), fenix: true);
    // 인증 상태 관리 컨트롤러
    Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
    Get.lazyPut<RequestController>(() => RequestController(), fenix: true);
    Get.lazyPut<AppController>(() => AppController(), fenix: true);
    // 하단 탭 제어 컨트롤러
    Get.put<MainController>(MainController(), permanent: true);
  }
}