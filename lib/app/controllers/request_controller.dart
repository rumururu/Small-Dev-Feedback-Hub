import 'package:get/get.dart';
import '../data/providers/auth_provider.dart';
import '../data/providers/requests_provider.dart';
import '../data/models/request_model.dart';
import 'app_controller.dart';

/// 리뷰 품앗이 리스트 조회를 처리합니다.
class RequestController extends GetxController {
  final AuthProvider _authProv = Get.find<AuthProvider>();
  final RequestsProvider _reqProv = RequestsProvider();
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMoreRequests = true.obs;

  /// 현재 컨트롤러가 다루는 요청 유형 ('test' or 'review')
  String? requestType;   // null이면 모든 타입을 로드

  /// 실시간 리뷰 요청 리스트
  RxList<RequestModel> reviewRequests = <RequestModel>[].obs;
  RxList<RequestModel> testRequests = <RequestModel>[].obs;
  RxList<RequestModel> myRequests = <RequestModel>[].obs;
  RxList<Map<String, dynamic>> todoRequests = <Map<String, dynamic>>[].obs;
  RxBool filterMyParticipation = true.obs;
  RxString sortBy = 'trust'.obs;

  /// 참여 상태 필터 리스트 (used if multiple statuses needed)
  final RxList<String> participationStatusList = <String>[].obs;

  /// 외부에서 타입을 설정하면 자동으로 리스트를 로드한다.
  void setRequestType(String? type) {
    requestType = type;
  }

  Future<void> loadRequests({DateTime? updatedAtCursor}) async {
    isLoading.value = true;
    final list = await _reqProv.fetchRequests(
      requestType: requestType,
      statusList: ['open', 'test'],
      filterMyParticipation: filterMyParticipation.value,
      sortBy: sortBy.value,
      updatedAtCursor: updatedAtCursor,
    );
    hasMoreRequests.value = list.length >= 30;
    if (requestType == 'test') {
      if (updatedAtCursor == null) {
        testRequests.assignAll(list);
      } else {
        testRequests.addAll(list);
      }
    } else {
      if (updatedAtCursor == null) {
        reviewRequests.assignAll(list);
      } else {
        reviewRequests.addAll(list);
      }
    }
    isLoading.value = false;
  }

  /// 추가 요청을 불러와서 리스트에 추가합니다 (페이지네이션 등에서 사용)
  Future<void> loadMoreRequests() async {
    if (isLoading.value) return;
    isLoadingMore.value = true;

    final lastUpdated = requestType == 'test'
        ? (testRequests.isNotEmpty ? testRequests.last.updatedAt : null)
        : (reviewRequests.isNotEmpty ? reviewRequests.last.updatedAt : null);

    if (lastUpdated == null) {
      isLoadingMore.value = false;
      return;
    }

    await loadRequests(updatedAtCursor: lastUpdated);
    isLoadingMore.value = false;
  }


  Future<void> loadMyRequests() async {
    isLoading.value = true;
    final uid = _authProv.currentUser?.id;
    final list = await _reqProv.fetchRequests(requestType: requestType, ownerId: uid);
    myRequests.assignAll(list);
    isLoading.value = false;
  }

  /// 새 요청 등록
  Future<void> submit(
    String targetAppId,
    String description, {
    String? descUrl,
    String? appLink,
    String? webLink,
  }) async {
    final user = _authProv.currentUser;
    if (user == null) {
      Get.snackbar('오류', '로그인이 필요합니다.');
      return;
    }
    if (requestType == null) {
      Get.snackbar('오류', 'requestType이 지정되지 않았습니다.');
      return;
    }
    final appC = Get.find<AppController>();
    final app = appC.apps.firstWhere((a) => a.id == targetAppId);

    final userDisplayName = user.userMetadata?['full_name'] ?? '';
    final userTrustScore = user.userMetadata?['trust_score'] ?? 0;

    if (description.isEmpty) {
      Get.snackbar('오류', '설명을 입력하세요.');
      return;
    }
    // RequestModel 생성 (id는 빈 문자열, Supabase 삽입 시 무시됨)
    final req = RequestModel(
      id: '',
      targetAppId: targetAppId,
      requestType: requestType!,
      description: description,
      ownerId: user.id,
      status: 'open',
      currentParticipants: 0,
      createdAt: DateTime.now(),
      updatedAt:DateTime.now(),
      packageName: app.packageName,
      appState: app.appState,
      trustScore: userTrustScore,
      displayName: userDisplayName,
      appName: app.appName,
      descUrl: descUrl,
    );
    // 생성된 요청 ID를 반환받아 모델에 반영
    final newId = await _reqProv.createRequest(req);
    if (newId != null) {
      // ID가 null이 아니면 새로운 모델 인스턴스 생성
      final newReq = RequestModel(
        id: newId,
        targetAppId: req.targetAppId,
        requestType: req.requestType,
        description: req.description,
        ownerId: req.ownerId,
        status: req.status,
        currentParticipants: req.currentParticipants,
        createdAt: req.createdAt,
        updatedAt: req.updatedAt,
        packageName: req.packageName,
        appState: req.appState,
        trustScore: req.trustScore,
        displayName: req.displayName,
        appName: req.appName,
        descUrl: req.descUrl,
      );
      requestType == 'test'
        ? testRequests.insert(0, newReq)
        : reviewRequests.insert(0, newReq);
    } else {
      // ID 수신 실패 시 원래 모델 삽입
      requestType == 'test'
        ? testRequests.insert(0, req)
        : reviewRequests.insert(0, req);
    }
  }

  /// 내가 맞품앗이를 해줘야 할 요청(RequestModel 리스트) 로드
  Future<void> loadMyToDo() async {
    isLoading.value = true;

    final uid = _authProv.currentUser?.id;
    if (uid == null) {
      todoRequests.clear();
      isLoading.value = false;
      return;
    }

    // 1) 내 요청이 메모리에 없다면 먼저 로드
    if (myRequests.isEmpty) {
      await loadMyRequests();
    }

    // 2) 내 요청 id 목록
    final myReqIds = myRequests.map((r) => r.id).toList();

    // 3) provider 메서드로 상대방 요청 가져오기
    final list = await _reqProv.fetchUnpairedParticipationForOwner(myReqIds);
    todoRequests.assignAll(list);

    isLoading.value = false;
  }

}