import 'package:get/get.dart';
import 'app_routes.dart';
import '../ui/pages/login_page.dart';
import '../ui/pages/home_page.dart';

class AppPages {
  static final pages = [
    GetPage(name: AppRoutes.LOGIN,      page: () => const LoginPage()),
    GetPage(name: AppRoutes.HOME,       page: () => const HomePage()),
    // 하위 페이지는 HomePage에서 내부 네비로 접근
  ];
}