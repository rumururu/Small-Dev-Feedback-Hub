import 'package:androidtestnreviewexchange/app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';

/// 로그인 페이지: Google OAuth로 로그인 처리
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    final authC = Get.find<AuthController>();
    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Google 로그인'),
          onPressed: () async {
            await authC.loginWithGoogle();
            if (authC.user.value != null) {
              Get.offAllNamed(AppRoutes.HOME);
            }
          },
        ),
      ),
    );
  }
}