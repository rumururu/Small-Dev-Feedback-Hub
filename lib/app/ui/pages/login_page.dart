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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 앱 아이콘
            const Icon(Icons.android, size: 100, color: Colors.green),
            const SizedBox(height: 16),
            // 앱 제목
            Text(
              '안드로이드 비공개 테스트 & 리뷰 품앗이',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // 로그인 버튼
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Google 로그인'),
              onPressed: () async {
                await authC.loginWithGoogle();
                if (authC.user.value != null) {
                  Get.offAllNamed(AppRoutes.HOME);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}