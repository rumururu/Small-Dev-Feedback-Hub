import 'package:get/get.dart';

/// 하단 탭 인덱스를 관리합니다.
class MainController extends GetxController {
  final tabIndex = 0.obs;
  void changeTab(int idx) => tabIndex.value = idx;
}