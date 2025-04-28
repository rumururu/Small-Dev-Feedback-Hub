// lib/app/controllers/test_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/providers/auth_provider.dart';
import '../data/providers/requests_provider.dart';
import '../data/models/request_model.dart';
import 'app_controller.dart';

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
    loadRequests();
  }

  Future<void> loadRequests() async {
    final list = await _reqProv.fetchRequests(requestType: 'test');
    requests.assignAll(list);
  }

  /// 새 테스트 요청 등록
  Future<void> submit(String targetAppId, String description) async {
    final user = _authProv.currentUser;
    if (user == null) {
      Get.snackbar('오류', '로그인이 필요합니다.');
      return;
    }
    if (description.isEmpty) {
      Get.snackbar('오류', '설명을 입력하세요.');
      return;
    }
    final appC = Get.find<AppController>();
    final app = appC.apps.firstWhere((a) => a.id == targetAppId);

    // user는 _authProv.currentUser로 되어 있으므로 displayName, trustScore는 이미 가지고 있어야 함
    final userDisplayName = user.userMetadata?['full_name'] ?? '';
    final userTrustScore = user.userMetadata?['trust_score'] ?? 0;

    // RequestModel 생성 (id는 빈 문자열, Supabase 삽입 시 무시됨)
    final req = RequestModel(
      id: '',
      targetAppId: targetAppId,
      requestType: 'test',
      description: description,
      ownerId: user.id,
      status: 'open',
      currentParticipants: 0,
      createdAt: DateTime.now(),
      packageName: app.packageName,
      appState: app.appState,
      cafeUrl: app.cafeUrl,
      trustScore: userTrustScore,
      displayName: userDisplayName,
      appName: app.appName,
    );
    await _reqProv.createRequest(req);
    requests.insert(0, req);
  }
}
