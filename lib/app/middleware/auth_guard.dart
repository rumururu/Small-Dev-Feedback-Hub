// lib/app/middleware/auth_guard.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../routes/app_routes.dart';

/// 로그인 상태에 따라 진입을 허용하거나 리다이렉트합니다.
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final isLoggedIn = Get.find<AuthController>().user.value != null;
    // 로그인 안 된 상태로 HOME 계열 접근 금지
    if (!isLoggedIn && route != AppRoutes.LOGIN) {
      return const RouteSettings(name: AppRoutes.LOGIN);
    }
    // 로그인 상태에서 /login 접근 금지
    if (isLoggedIn && route == AppRoutes.LOGIN) {
      return const RouteSettings(name: AppRoutes.HOME);
    }
    return null;
  }
}