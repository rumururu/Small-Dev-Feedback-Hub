// lib/app/controllers/test_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/providers/auth_provider.dart';
import '../data/providers/requests_provider.dart';
import '../data/models/request_model.dart';

/// 테스트 품앗이 리스트와 신규 요청 등록을 처리합니다.
class TestController extends GetxController {
  final AuthProvider _authProv = Get.find<AuthProvider>();
  final RequestsProvider _reqProv = RequestsProvider();

  final appNameC = TextEditingController();
  final descC = TextEditingController();



  /// 실시간 테스트 요청 리스트
  var requests = <RequestModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    // Supabase 'requests' 테이블에서 type='test'인 항목 스트림 구독
    _reqProv.streamRequests(type: 'test').listen((list) {
      requests.value = list;
    });
  }

  /// 새 테스트 요청 등록
  Future<void> submit(String appName, String description) async {
    final user = _authProv.currentUser;
    if (user == null) {
      Get.snackbar('오류', '로그인이 필요합니다.');
      return;
    }
    if (appName.isEmpty || description.isEmpty) {
      Get.snackbar('오류', '앱 이름과 설명을 입력하세요.');
      return;
    }
    // RequestModel 생성 (id는 빈 문자열, Supabase 삽입 시 무시됨)
    final req = RequestModel(
      id: '',
      appName: appName,
      type: 'test',
      description: description,
      ownerId: user.id,
      currentParticipants: 0,
      createdAt: DateTime.now(),
    );
    await _reqProv.createRequest(req);
  }
}