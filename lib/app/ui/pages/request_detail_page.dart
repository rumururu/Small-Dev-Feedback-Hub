// 아래 ParticipationProvider에 메서드 추가 필요
// lib/app/ui/pages/request_detail_page.dart

import 'package:androidtestnreviewexchange/app/ui/pages/request_review_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/request_model.dart';
import '../../data/providers/participation_provider.dart';
import '../../data/providers/requests_provider.dart';
import '../components/image_picker_button.dart';

/// 요청 상세 페이지: 테스트 참여 또는 리뷰 완료 기능을 제공합니다.
class RequestDetailPage extends StatefulWidget {
  final RequestModel request;
  const RequestDetailPage({super.key, required this.request});

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  late Future<List<Map<String, dynamic>>> _participantsFuture;

  @override
  void initState() {
    super.initState();
    _participantsFuture = ParticipationProvider().getParticipantDetails(
      requestId: widget.request.id,
    );
  }

  void refreshParticipants() {
    setState(() {
      _participantsFuture = ParticipationProvider().getParticipantDetails(
        requestId: widget.request.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.request.appName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.request.description),
            Text(
              '등록자: ${widget.request.displayName} (신뢰도: ${widget.request.trustScore})',
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 16),
            Text('상태: ${widget.request.status}'),
            Text('요청 타입: ${widget.request.requestType}'),
            Text(
              '경과일: ${DateTime.now().difference(widget.request.createdAt).inDays}일',
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _participantsFuture,
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox();
                final participants = snap.data!;

                final authC = Get.find<AuthController>();
                final userId = authC.user.value?.id ?? '';
                final isOwner = widget.request.ownerId == userId;
                final alreadyParticipated = participants.any(
                  (p) => p['user_id'] == userId,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('참여자 수: ${participants.length}명'),
                    const SizedBox(height: 8),
                    if (participants.isEmpty)
                      const Text('참여자 없음')
                    else ...[
                      const Text(
                        '참여자 목록:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...participants.map((p) {
                        final proofUrl = p['proof_url'];
                        final targetRequestId = p['target_request_id'];
                        final participationId = p['participation_id'] ?? p['id'];
                        final status = p['status'];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: Text(
                                '${p['display_name']} (신뢰도: ${p['trust_score'] ?? 0})',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (p['target_app_name'] != null)
                                    Text('요청 앱: ${p['target_app_name']}'),
                                  if (p['target_request_type'] != null)
                                    Text('요청 타입: ${p['target_request_type']}'),
                                  Text('등록일: ${p['requested_at'].toString().split('T').first}'),
                                  Text('완료 여부: ${p['status'] == 'completed' ? '완료' : '미완료'}'),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                if (proofUrl != null &&
                                    proofUrl != '' &&
                                    proofUrl != 'null' &&
                                    status != 'completed')
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 16,
                                      bottom: 4,
                                      right: 8,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Get.to(
                                          () => ReviewDetailPage(
                                            participationId: participationId,
                                            proofUrl: proofUrl,
                                            isCompleted: status == 'completed',
                                            isOwner: isOwner &&
                                                widget.request.requestType == 'review',
                                            onActionCompleted: refreshParticipants,
                                          ),
                                        );
                                      },
                                      child: const Text('리뷰 확인'),
                                    ),
                                  ),
                                if (targetRequestId != null &&
                                    targetRequestId != 'Unknown')
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 0,
                                      bottom: 4,
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final reqProv = RequestsProvider();
                                        final targetRequest = await reqProv
                                            .fetchSingleRequest(
                                          targetRequestId,
                                        );
                                        if (targetRequest != null) {
                                          Get.to(
                                            () => RequestDetailPage(
                                              request: targetRequest,
                                            ),
                                          );
                                        } else {
                                          Get.snackbar(
                                            '오류',
                                            '해당 요청을 찾을 수 없습니다.',
                                          );
                                        }
                                      },
                                      child: const Text('품앗이 요청 보기'),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(),
                          ],
                        );
                      }),
                    ],
                    const SizedBox(height: 24),
                    if (!isOwner &&
                        (widget.request.requestType == 'test' ||
                            widget.request.requestType == 'review'))
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed:
                                (widget.request.status == 'open')
                                    ? () async {
                                      if (!alreadyParticipated) {
                                        final myReqProv = RequestsProvider();
                                        final myRequests = await myReqProv
                                            .fetchRequests(
                                              requestType:
                                                  widget.request.requestType,
                                            );
                                        final myValidRequests =
                                            myRequests
                                                .where(
                                                  (r) =>
                                                      r.ownerId ==
                                                      authC.user.value?.id,
                                                )
                                                .toList();
                                        final selected = await showDialog<
                                          RequestModel
                                        >(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: const Text('내 요청 선택'),
                                              content: SizedBox(
                                                width: double.maxFinite,
                                                child: ListView.builder(
                                                  shrinkWrap: true,
                                                  itemCount:
                                                      myValidRequests.length +
                                                      1,
                                                  itemBuilder: (
                                                    context,
                                                    index,
                                                  ) {
                                                    if (index == 0) {
                                                      return ListTile(
                                                        title: const Text(
                                                          '요청 선택 안 함',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        subtitle: const Text(
                                                          '요청 없이 참여하면 신뢰도 보상이 두 배입니다.',
                                                        ),
                                                        onTap:
                                                            () => Navigator.pop(
                                                              context,
                                                              null,
                                                            ),
                                                      );
                                                    }
                                                    final req =
                                                        myValidRequests[index -
                                                            1];
                                                    return ListTile(
                                                      title: Text(
                                                        req.packageName,
                                                      ),
                                                      subtitle: Text(
                                                        req.description,
                                                      ),
                                                      onTap:
                                                          () => Navigator.pop(
                                                            context,
                                                            req,
                                                          ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        );

                                        if (selected == null) {
                                          final confirm =
                                              await Get.dialog<bool>(
                                                AlertDialog(
                                                  title: const Text('참여 확인'),
                                                  content: const Text(
                                                    '내 요청을 선택하지 않고 참여하시겠습니까?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Get.back(
                                                            result: false,
                                                          ),
                                                      child: const Text('취소'),
                                                    ),
                                                    TextButton(
                                                      onPressed:
                                                          () => Get.back(
                                                            result: true,
                                                          ),
                                                      child: const Text('참여'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                          if (confirm != true) return;
                                        }

                                        String? proofUrl;
                                        if (widget.request.requestType ==
                                                'review' &&
                                            selected == null) {
                                          proofUrl =
                                              await ImagePickerButton.pickImageAndUpload();
                                        }

                                        await ParticipationProvider()
                                            .createParticipation(
                                              requestId: widget.request.id,
                                              targetRequestId: selected?.id,
                                              proofUrl: proofUrl,
                                            );
                                        refreshParticipants();

                                        // (Snackbar about trust score bonus removed; now explained in dialog.)
                                      } else {
                                        final success =
                                            await ParticipationProvider()
                                                .cancelParticipation(
                                                  requestId: widget.request.id,
                                                );
                                        if (success) {
                                          Get.snackbar('완료', '참여 취소가 완료되었습니다.');
                                          refreshParticipants();
                                        } else {
                                          Get.snackbar('오류', '참여 취소에 실패했습니다.');
                                        }
                                      }
                                    }
                                    : null,
                            style:
                                alreadyParticipated
                                    ? ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    )
                                    : null,
                            child: Text(
                              alreadyParticipated
                                  ? '참여 취소'
                                  : widget.request.requestType == 'test'
                                  ? '테스트 참여 신청'
                                  : '리뷰 참여 신청',
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
