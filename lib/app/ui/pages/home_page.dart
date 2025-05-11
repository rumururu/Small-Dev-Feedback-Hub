// lib/app/ui/pages/home_page.dart

import 'package:androidtestnreviewexchange/app/ui/pages/test_app_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../controllers/main_controller.dart';
import '../../middleware/package_checker_service.dart';
import 'test_list_page.dart';
import 'review_list_page.dart';
import 'profile_page.dart';

/// 홈 페이지: 하단 탭 네비게이션으로 세 화면 전환
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 배터리 최적화 제외 권한 확인
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await showBackgroundPermissionDialog(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mainC = Get.find<MainController>();
    final pages = const [
      TestListPage(),
      ReviewListPage(),
      TestAppListPage(),
      ProfilePage(),
    ];

    return Obx(() => PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        final currentTime = DateTime.now();
        if (mainC.lastPressedTime == null || currentTime.difference(mainC.lastPressedTime!) > const Duration(seconds: 2)) {
          mainC.lastPressedTime = currentTime;
          Get.rawSnackbar(message: '한 번 더 누르면 종료됩니다.');
        } else {
          mainC.lastPressedTime = null;
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: pages[mainC.tabIndex.value],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: mainC.tabIndex.value,
          onTap: mainC.changeTab,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.list), label: '테스트'),
            BottomNavigationBarItem(icon: Icon(Icons.rate_review), label: '리뷰'),
            BottomNavigationBarItem(icon: Icon(Icons.apps), label: '테스트앱'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: '내정보'),
          ],
        ),
      ),
    ));
  }
}