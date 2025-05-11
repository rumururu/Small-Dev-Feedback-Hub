import 'package:get/get.dart';

/// 하단 탭 인덱스를 관리합니다.
class MainController extends GetxController {
  DateTime? lastPressedTime; // 네비화면에서 두번 뒤로가면 종료 관리용
  final tabIndex = 0.obs;
  void changeTab(int idx) => tabIndex.value = idx;
}