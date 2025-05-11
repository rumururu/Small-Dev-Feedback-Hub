// lib/app/ui/pages/review_list_page.dart

import 'package:androidtestnreviewexchange/app/controllers/request_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/app_controller.dart';
import '../../data/models/app_model.dart';
import '../components/notification_badge_button.dart';
import '../components/request_card.dart';

/// 리뷰 품앗이 리스트 화면
class ReviewListPage extends StatelessWidget {
  const ReviewListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<RequestController>();
    ctrl.setRequestType('review');
    if (ctrl.reviewRequests.isEmpty) ctrl.loadRequests();
    final scrollController = ScrollController();
    return Scaffold(
      appBar: AppBar(
        title: const Text('리뷰 품앗이'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final appC = Get.find<AppController>();
              final publishedApps = appC.apps.where((a) => a.appState == 'published').toList();
              if (publishedApps.isEmpty) {
                Get.snackbar('등록할 수 있는 앱 없음', '내 정보에서 published인 앱을 먼저 등록하세요.');
                return;
              }
              final selected = await showDialog<AppModel>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('앱 선택'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: publishedApps.length,
                        itemBuilder: (context, index) {
                          final app = publishedApps[index];
                          return ListTile(
                            title: Text(app.appName),
                            onTap: () => Navigator.pop(context, app),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
              if (selected != null) {
                final existing = ctrl.reviewRequests.where((r) =>
                r.targetAppId == selected.id &&
                    r.requestType == (selected.appState == 'closed_test' ? 'test' : 'review')
                ).toList();
                if (existing.isNotEmpty) {
                  Get.snackbar('알림', '이 앱에 대해 이미 요청이 등록되어 있습니다.');
                  return;
                }
                final descC = TextEditingController();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('설명 입력'),
                    content: TextField(
                      controller: descC,
                      decoration: const InputDecoration(labelText: '앱 설명을 입력하세요'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('취소'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('등록'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && descC.text.trim().isNotEmpty) {
                  ctrl.submit(selected.id, descC.text.trim());
                } else {
                  Get.snackbar('오류', '설명을 입력해야 합니다.');
                }
              }
            },
          ), NotificationBadgeButton(),
        ],
      ),
      body: Obx(() {
        final list = ctrl.reviewRequests;
        return RefreshIndicator(
          onRefresh: () async {
            await ctrl.loadRequests();
          },
          child: CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 기존 SliverToBoxAdapter 필터/정렬 영역 유지
              SliverToBoxAdapter(
                child: Obx(() => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Obx(() {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: ctrl.filterMyParticipation.value,
                              onChanged: (v) {
                                ctrl.filterMyParticipation.value = v ?? true;
                                ctrl.loadRequests();
                              },
                            ),
                            const Text('참여 완료 제외'),
                          ],
                        );
                      }),
                      const SizedBox(width: 24),
                      DropdownButton<String>(
                        value: ctrl.sortBy.value,
                        items: const [
                          DropdownMenuItem(value: 'date', child: Text('최신순')),
                          DropdownMenuItem(value: 'trust', child: Text('신뢰순')),
                        ],
                        onChanged: (v) {
                          ctrl.sortBy.value = v ?? 'trust';
                          ctrl.loadRequests();
                        },
                      ),
                    ],
                  ),
                )),
              ),
              if (ctrl.isLoading.value)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: const Center(
                    child: Text('등록된 리뷰 요청이 없습니다.'),
                  ),
                )
              else
                ...[
                  NotificationListener<ScrollNotification>(
                    onNotification: (scrollInfo) {
                      if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 100 &&
                          !ctrl.isLoadingMore.value &&
                          ctrl.hasMoreRequests.value) {
                        ctrl.loadMoreRequests();
                      }
                      return false;
                    },
                    child: Obx(() => SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (_, i) => RequestCard(request: list[i]),
                        childCount: list.length,
                      ),
                    )),
                  ),
                  if (ctrl.isLoadingMore.value)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  if (!ctrl.hasMoreRequests.value && list.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: Text('더 이상 요청이 없습니다.')),
                      ),
                    ),
                ],
            ],
          ),
        );
      }),
    );
  }
}