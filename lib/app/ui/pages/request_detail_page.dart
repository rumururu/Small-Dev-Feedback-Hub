import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

import '../../utils/constants.dart';
import '../components/test_request_bottom_sheet.dart';
import 'request_review_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../data/models/request_model.dart';
import '../../controllers/request_detail_controller.dart';
import '../../data/providers/requests_provider.dart';
// 추가: 테스트 참여자 알림 전송용
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// 요청 상세 페이지: 테스트 참여 또는 리뷰 완료 기능을 제공합니다.
/// 내가 테스트 요청자인 경우 보이는 버튼
/// 1) 테스트 시작 버튼, 종료/재시작 버튼
///   (종료 재시작 버튼은 test start 후 12일 경과시 클릭가능, 재시작 클릭시 테스트 시작일 오늘 날짜로 초기화, 종료던 재시작이던 참여자 신뢰점수 1점 증가)
/// 2) 참여자 요청으로 이동
/// 3) 참여자에게 테스트 목록 등록 알림 전송
///
/// 내가 리뷰 요청자인 경우 보이는 버튼
/// 1) 내 요청 상태 변경 버튼 (open, closed)
/// 2) 참여자 요청으로 이동
///
/// 내가 참여자인 경우 화면에 보이는 기능
/// 1) 리뷰/테스트 참여 신청, 신청취소 (테스트 시작 이후에는 신청취소 불가)
///    . 리뷰 참여시는 상대방 앱 리뷰 이미지 첨부 필요
///    . 공통적으로 품앗이 받을 내 요청 선택 가능 (또는 품앗이 없이 참여)
///
class RequestDetailPage extends StatelessWidget {
  final RequestModel request;
  final String? autoPairingRequestId;
  const RequestDetailPage({
    super.key,
    required this.request,
    this.autoPairingRequestId,
  });

  Future<void> _editRequestDetails(BuildContext context, RequestDetailController c) async {
    final initialData = {
      'description': c.request.value?.description ?? '',
      'cafeUrl': c.request.value?.descUrl ?? '',
    };

    final result = await showTestRequestBottomSheet(context, initialData: initialData);

    if (result != null && result['description']!.isNotEmpty) {
      final ok = await RequestsProvider().updateRequestDetails(
        c.request.value!.id,
        description: result['description']!,
        cafeUrl: result['cafeUrl'],
        appLink: result['appLink'],
        webLink: result['webLink'],
      );

      if (ok) {
        c.request.update((r) {
          r?.description = result['description']!;
          r?.descUrl = result['cafeUrl'];
        });
        Get.rawSnackbar(message: '요청 정보가 성공적으로 수정되었습니다.');
      } else {
        Get.rawSnackbar(message: '요청 정보 수정 실패');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Controller: tag를 요청 ID로 하여 페이지마다 별도 인스턴스
    final c = Get.put(
      RequestDetailController(
        initialRequest: request,
        autoPairingRequestId: autoPairingRequestId,
      ),
      tag: request.id, // 고유 태그
    );

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(c.request.value?.appName ?? '')),
        actions: [
          if (c.isOwner)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editRequestDetails(context, c),
              tooltip: '등록내용 편집',
            ),
        ],
      ),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final req = c.request.value!;
        final participants = c.participants;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('등록자: ${req.displayName} (신뢰점수: ${req.trustScore})'),
                  const SizedBox(height: 4),
                  Text(
                    '유형: ${req.requestType == 'test' ? '테스트' : '리뷰'} 품앗이, 상태: ${req.status == 'test' ? '테스트중 (${DateTime.now().difference(req.testStartedAt!).inDays}일 경과)' : req.status}',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 테스트 시작 버튼 (owner & test & open)
                      if (req.requestType == 'test' &&
                          c.isOwner &&
                          req.status == 'open')
                        Expanded(
                          child: ElevatedButton(
                            onPressed: c.startTest,
                            child: const Text('테스트 시작'),
                          ),
                        ),
                      // 테스트 시작 버튼 (owner & test & open)
                      if (req.requestType == 'test' &&
                          c.isOwner &&
                          req.status == 'open' && c.participants.isEmpty)
                        ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: c.cancelRequest,
                            child: const Text('테스트 취소'),
                          ),
                        ),
                      ],
                      // 테스트 진행 중 - 12일 경과 전/후 안내 및 액션
                      if (req.requestType == 'test' &&
                          c.isOwner &&
                          req.status == 'test' &&
                          req.testStartedAt != null) ...[
                        // 12일 경과 전 안내 문구
                        if (DateTime.now()
                                .difference(req.testStartedAt!)
                                .inDays <
                            testRestartPossibleDate)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('테스트 시작 $testRestartPossibleDate일 후 직접 완료/실패 처리 가능합니다.'),
                          )
                        else
                        // 12일 경과 후: 실패 및 종료 버튼
                        ...[
                          Expanded(
                            child: ElevatedButton(
                              onPressed: c.restartTest,
                              child: const Text('테스트 실패'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: c.finishTest,
                              child: const Text('테스트 종료'),
                            ),
                          ),
                          // 리뷰 요청자의 상태(open ↔ closed) 토글 버튼
                          if (req.requestType == 'review' && c.isOwner)
                            ElevatedButton(
                              onPressed: c.toggleRequest,
                              child: Text(req.status == 'open' ? '요청 닫기' : '요청 열기'),
                            ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req.description),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final uri = Uri.parse(
                                'https://play.google.com/store/apps/details?id=${req.packageName}',
                              );
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                Get.rawSnackbar(message: '앱 링크를 열 수 없습니다.');
                              }
                            },
                            child: const Text('앱 링크'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final uri = Uri.parse(
                                'https://play.google.com/apps/testing/${req.packageName}',
                              );
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                Get.rawSnackbar(message: '웹 링크를 열 수 없습니다.');
                              }
                            },
                            child: const Text('웹 링크'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // 설명 URL 접기/펼치기
            if (req.descUrl != null && req.descUrl!.isNotEmpty)
              ExpansionTile(
                title: const Text('상세 설명'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: InlineWebView(url: req.descUrl!),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [


                  const SizedBox(height: 24),
                  Text(
                    '참여자 ${participants.length}명',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),


                  if (participants.isEmpty)
                    const Text('참여자 없음')
                  else
                    ...participants.map((p) => _participantTile(p, c)),

                  const SizedBox(height: 24),

                  // 참여/취소 버튼 (owner가 아닌 경우)
                  if (!c.isOwner && !c.alreadyRegisteredTester &&
                      (req.requestType == 'test' ||
                          req.requestType == 'review') && (c.participatedStatus == null || c.participatedStatus == 'pending'))
                    ElevatedButton(
                      onPressed:
                          req.status == 'open' ? c.toggleParticipation : null,
                      style:
                          c.alreadyParticipated
                              ? ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              )
                              : null,
                      child: Text(
                        c.alreadyParticipated
                            ? '참여 취소'
                            : req.requestType == 'test'
                            ? '테스트 참여 신청'
                            : '리뷰 참여 신청',
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  /// 참여자 Tile  (owner가 클릭 시 상대 요청 상세로 이동)
  Widget _participantTile(Map<String, dynamic> p, RequestDetailController c) {
    final statusLabel =
        p['status'] == 'completed'
            ? '완료'
            : p['status'] == 'failed'
            ? '실패'
            : '미완료';

    final requestedAt = p['requested_at'] as DateTime?;
    final formatted =
        requestedAt == null
            ? ''
            : '${requestedAt.month.toString().padLeft(2, '0')}/'
                '${requestedAt.day.toString().padLeft(2, '0')} '
                '${requestedAt.hour.toString().padLeft(2, '0')}:'
                '${requestedAt.minute.toString().padLeft(2, '0')}';

    final participationId = p['participation_id'];
    final proofUrl = p['proof_url'];
    final targetRequestId = p['target_request_id'];
    final isPairing = p['is_pairing'] ?? false;
    final testerRegistered = p['tester_registered'] ?? false;
    final userEmail = p['user_email'];

    // 이동 가능 여부: owner & target_request_id 존재
    final canNavigateTarget =
        c.isOwner && targetRequestId != null && targetRequestId != 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text('${p['display_name']} (신뢰점수:${p['trust_score']})'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p['target_app_name'] != null)
                Text('요청 앱: ${p['target_app_name']}'),
              Text(
                '상태: $statusLabel • 맞품앗이 ${isPairing
                    ? '성공'
                    : canNavigateTarget
                    ? '수행필요'
                    : '불필요'}',
              ),
              Text('등록일: $formatted'),
              if (c.isOwner &&
                  c.request.value!.requestType == 'test' &&
                  userEmail != null)
                Row(
                  children: [
                    Text('이메일: $userEmail'),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: userEmail));
                        Get.rawSnackbar(message: '이메일이 복사되었습니다.');
                      },
                    ),
                  ],
                ),
            ],
          ),
          trailing:
              canNavigateTarget
                  ? const Icon(Icons.arrow_forward_ios, size: 16)
                  : null,
          onTap:
              canNavigateTarget
                  ? () async {
                    final reqProv = RequestsProvider();
                    final targetReq = await reqProv.fetchSingleRequest(
                      targetRequestId,
                    );
                    if (targetReq != null) {
                      await Get.to(
                        () => RequestDetailPage(
                          request: targetReq,
                          autoPairingRequestId: c.request.value!.id,
                        ),
                        preventDuplicates: false, // 같은 페이지 여러 번 push 가능하게
                      );
                      await c.fetchParticipants();
                    } else {
                      Get.rawSnackbar(message: '해당 요청을 찾을 수 없습니다.');
                    }
                  }
                  : null,
        ),

        // 액션 버튼 영역 (리뷰 확인 / 품앗이 요청 보기)
        Row(
          children: [
            if (proofUrl != null &&
                proofUrl != '' &&
                proofUrl != 'null' &&
                c.request.value!.requestType == 'review')
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4, right: 8),
                child: ElevatedButton(
                  onPressed: () async {
                    await Get.to(
                      () => ReviewDetailPage(
                        participationId: p['participation_id'] ?? p['id'],
                        proofUrl: proofUrl,
                        isCompleted: p['status'] != 'pending',
                        isOwner:
                            c.isOwner &&
                            c.request.value!.requestType == 'review',
                        onActionCompleted: c.fetchParticipants,
                        appName: c.request.value?.appName ?? '',
                      ),
                    );
                    await c.fetchParticipants();
                  },
                  child: const Text('리뷰 확인'),
                ),
              ),

            // ── (owner 전용) 개별 참여자에게 테스터 등록 안내 ──
            if (c.isOwner &&
                c.request.value!.requestType == 'test' &&
                !testerRegistered)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: OutlinedButton(
                  onPressed: () => c.markTesterRegistered(
                    participationId: participationId,
                        ),
                  child: const Text('테스터 등록완료 알림 보내기'),
                ),
              ),
          ],
        ),
        const Divider(),
      ],
    );
  }
}

class InlineWebView extends StatefulWidget {
  final String url;

  const InlineWebView({super.key, required this.url});

  @override
  State<InlineWebView> createState() => _InlineWebViewState();
}

class _InlineWebViewState extends State<InlineWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    // Platform 별 WebView 컨트롤러 설정
    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller =
        WebViewController.fromPlatformCreationParams(params)
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {},
              onPageStarted: (String url) {},
              onPageFinished: (String url) {},
              onWebResourceError: (WebResourceError error) {
                debugPrint('WebView 오류: ${error.description}');
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.url));

    // Android 특정 설정
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 모든 제스처 인식기를 집합에 추가
    return WebViewWidget(
      controller: _controller,
      gestureRecognizers: {
        Factory<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer(),
        ),
        Factory<HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
        ),
        Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
        Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
      },
    );
  }
}
