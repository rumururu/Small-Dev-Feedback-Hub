// lib/app/ui/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/main_controller.dart';
import 'test_list_page.dart';
import 'review_list_page.dart';
import 'profile_page.dart';

/// 홈 페이지: 하단 탭 네비게이션으로 세 화면 전환
class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final mainC = Get.find<MainController>();
    final pages = const [
      TestListPage(),
      ReviewListPage(),
      ProfilePage(),
    ];
    return Obx(() => Scaffold(
      body: pages[mainC.tabIndex.value],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: mainC.tabIndex.value,
        onTap: mainC.changeTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '테스트'),
          BottomNavigationBarItem(icon: Icon(Icons.rate_review), label: '리뷰'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내정보'),
        ],
      ),
    ));
  }
}