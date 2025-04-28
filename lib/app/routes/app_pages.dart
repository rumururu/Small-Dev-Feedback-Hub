// lib/app/routes/app_pages.dart

import 'package:get/get.dart';
import '../middleware/auth_guard.dart';
import '../ui/pages/request_detail_page.dart';
import '../data/models/request_model.dart';
import '../ui/pages/test_app_list_page.dart';
import 'app_routes.dart';
import '../ui/pages/login_page.dart';
import '../ui/pages/home_page.dart';
import '../ui/pages/test_list_page.dart';
import '../ui/pages/review_list_page.dart';
import '../ui/pages/profile_page.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.LOGIN,
      page: () => const LoginPage(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.HOME,
      page: () => const HomePage(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.TEST_LIST,
      page: () => const TestListPage(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.REVIEW_LIST,
      page: () => const ReviewListPage(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.DETAIL,
      page: () {
        final request = Get.arguments as RequestModel;
        return RequestDetailPage(request: request);
      },
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.PROFILE,
      page: () => const ProfilePage(),
      middlewares: [AuthGuard()],
    ),
    GetPage(
      name: AppRoutes.testApps,
      page: () => const TestAppListPage(),
    ),
  ];
}