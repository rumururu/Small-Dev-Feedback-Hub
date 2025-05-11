import 'package:androidtestnreviewexchange/app/controllers/request_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../data/models/request_model.dart';
import '../data/providers/participation_provider.dart';
import '../data/providers/requests_provider.dart';
import 'auth_controller.dart';
import '../ui/components/image_picker_button.dart';

class RequestDetailController extends GetxController {
  RequestDetailController({
    required this.initialRequest,
    this.autoPairingRequestId,
  });

  // ────────────────── 초기 파라미터 ──────────────────
  final RequestModel initialRequest;
  final String? autoPairingRequestId;

  // ────────────────── 상태 ──────────────────
  final request = Rx<RequestModel?>(null);
  final participants = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;

  // 편의 getter
  String get myId => Get.find<AuthController>().user.value?.id ?? '';
  String get myName => Get.find<AuthController>().user.value?.userMetadata?['full_name'] ?? '';
  bool get isOwner => request.value?.ownerId == myId;
  bool get alreadyParticipated => participants.any((p) => p['user_id'] == myId);
  bool get alreadyRegisteredTester => participants.any((p) => p['user_id'] == myId && p['tester_registered'] == true);
  String? get participatedStatus {
    final participation = participants.firstWhereOrNull(
      (p) => p['user_id'] == myId,
    );
    return participation?['status'];
  }

  @override
  void onInit() {
    super.onInit();
    request.value = initialRequest;
    fetchParticipants();
  }

  // ────────────────── 참가자 목록 로드 ──────────────────
  Future<void> fetchParticipants() async {
    isLoading.value = true;
    final list = await ParticipationProvider().getParticipantDetails(
      requestId: request.value!.id,
    );
    participants.assignAll(list);
    isLoading.value = false;
  }

  // ────────────────── 테스트 시작 ──────────────────
  Future<void> startTest() async {
    if (participants.isEmpty) {
      Get.rawSnackbar(message: '참여자가 1명 이상 있어야 합니다.');
      return;
    }
    final ok = await RequestsProvider().startTestRequest(request.value!.id);
    if (ok) {
      request.update((r) {
        r?.status = 'testing';
        r?.testStartedAt = DateTime.now();
      });
      Get.rawSnackbar(message: '테스트가 시작되었습니다.');
    } else {
      Get.rawSnackbar(message: '테스트 시작 실패');
    }
  }

  // ────────────────── 테스트 재시작 ──────────────────
  Future<void> restartTest() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('테스트 재시작 확인'),
        content: const Text('테스트가 실패했습니다 처음부터 다시 진행합니다. 계속할까요?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('계속'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await RequestsProvider().restartTestRequest(request.value!.id);
    if (ok) {
      Get.rawSnackbar(message: '테스트가 재시작되었습니다.');
      await fetchParticipants();
    } else {
      Get.rawSnackbar(message: '재시작에 실패했습니다.');
    }
  }

  // ────────────────── 테스트 종료 ──────────────────
  Future<void> finishTest() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('테스트 종료 확인'),
        content: const Text('테스트를 완료처리합니다. 계속할까요?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('계속'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await RequestsProvider().completeTestRequest(request.value!.id);
    if (ok) {
      Get.rawSnackbar(message: '테스트가 완료처리되었습니다.');
      await fetchParticipants();
    } else {
      Get.rawSnackbar(message: '종료에 실패했습니다.');
    }
  }

  // ────────────────── 신청/취소 토글 ──────────────────
  Future<void> toggleRequest() async {
    final req = request.value!;

    if (req.requestType == 'review') {
      final newStatus = req.status == 'open' ? 'closed' : 'open';
      final ok = await RequestsProvider().updateRequestStatus(
        req.id,
        newStatus,
      );
      if (ok) {
        request.update((r) => r?.status = newStatus);
        Get.rawSnackbar(message: '요청 상태가 $newStatus 로 변경되었습니다.');
      } else {
        Get.rawSnackbar(message: '상태 변경 실패');
      }
    }
    await fetchParticipants();
  }

  Future<void> cancelRequest() async {
    final req = request.value!;
    if (req.requestType == 'test') {
      if (participants.isNotEmpty) {
        Get.rawSnackbar(message: '참여자가 있는 경우 요청 취소가 불가합니다.');
        return;
      }
      if (req.status != 'open') {
        Get.rawSnackbar(message: 'open상태에서만 요청 취소가 가능합니다.');
        return;
      }
      final ok = await RequestsProvider().cancelRequest(requestId: req.id);
      if (ok) {
        Get.back();
        Get.find<RequestController>().testRequests.removeWhere(
          (r) => r.id == req.id,
        );
        Get.rawSnackbar(message: '테스트요청이 삭제되었습니다..');
      } else {
        Get.rawSnackbar(message: '삭제 실패');
      }
      await fetchParticipants();
    }
  }

  // ────────────────── 참여/취소 토글 ──────────────────
  Future<void> toggleParticipation() async {
    final req = request.value!;
    if (!alreadyParticipated) {
      // =========== 참여 ===========
      // ① 내 요청 중 같은 타입 가져오기
      final myReqs = await RequestsProvider().fetchRequests(
        statusList: ['open', 'test'],
        ownerId: myId,
      );

      // ② autoPairingRequestId 우선
      RequestModel? targetReq = myReqs.firstWhereOrNull(
        (e) => e.id == autoPairingRequestId,
      );

      // ③ 없으면 다이얼로그 선택
      targetReq ??= await _pickMyRequest(myReqs);

      // 다이얼로그에서 선택하지 않은 경우 확인 팝업
      if (targetReq == null) {
        final proceed = await _confirmNoPairing() ?? false;
        if (!proceed) return;
      }

      // ④ 리뷰일 때 증빙 스샷
      String? proofUrl;
      if (req.requestType == 'review') {
        // 다음 화면에서 리뷰 캡처 이미지를 추가해주세요. 다이얼로그 표시
        await Get.dialog(
          AlertDialog(
            content: const Text('다음 화면에서 리뷰 이미지를 추가해주세요.(요청자에게 이미지가 전송됩니다.)'),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('확인')),
            ],
          ),
        );
        // 이미지 선택 및 업로드
        proofUrl = await ImagePickerButton.pickImageAndUpload();

        if (proofUrl == null) return;
      }
      final ok = await ParticipationProvider().createParticipation(
        ownerId: req.ownerId,
        requestId: req.id,
        targetRequestId: targetReq?.id,
        proofUrl: proofUrl,
        requestType: req.requestType,
        participantName: myName,
        appName: req.appName,
      );

      if (ok) {
        Get.rawSnackbar(message: '참여 신청 완료');
      }
    } else {
      // =========== 취소 ===========
      final ok = await ParticipationProvider().cancelParticipation(
        requestId: req.id,
      );
      Get.rawSnackbar(
        message:
            ok == null
                ? '참여취소 실패(이미 처리됨)'
                : ok
                ? '참여 취소 완료'
                : '참여 취소 실패',
      );
    }
    await fetchParticipants();
  }

  Future<void> markTesterRegistered({required String participationId}) async {
    Get.rawSnackbar(message: '테스터 등록이 완료되었습니다.');
    }

  // ────────────────── 헬퍼 ──────────────────
  Future<RequestModel?> _pickMyRequest(List<RequestModel> myReqs) {
    return Get.dialog<RequestModel>(
      AlertDialog(
        title: const Text('내 요청 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: myReqs.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return ListTile(
                  title: const Text('선택 안 함'),
                  subtitle: const Text('맞품하지 않으면 완료시 신뢰점수를 두배 획득합니다.'),
                  onTap: () => Get.back(result: null),
                );
              }
              final r = myReqs[i - 1];
              return ListTile(
                title: Text(r.appName),
                subtitle: Text(r.description),
                onTap: () => Get.back(result: r),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmNoPairing() {
    return Get.dialog<bool>(
      AlertDialog(
        title: const Text('참여 확인'),
        content: const Text('내 요청 없이 참여하면 보상이 두 배입니다. 진행할까요?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('진행'),
          ),
        ],
      ),
    );
  }
}
