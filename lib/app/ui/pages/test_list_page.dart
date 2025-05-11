// lib/app/ui/pages/test_list_page.dart

import 'package:androidtestnreviewexchange/app/controllers/request_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/app_model.dart';
import '../components/notification_badge_button.dart';
import '../components/request_card.dart';
import '../../controllers/app_controller.dart';
import '../components/test_request_bottom_sheet.dart';

/// 테스트 품앗이 리스트 및 신규 요청 등록
class TestListPage extends StatelessWidget {
  const TestListPage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<RequestController>();

    ctrl.setRequestType('test');
    if (ctrl.testRequests.isEmpty) ctrl.loadRequests();
    return Scaffold(
      appBar: AppBar(
        title: const Text('테스트 품앗이'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final appC = Get.find<AppController>();
              // 이미 테스트 요청이 등록된 앱 ID 집합
              final existingIds =
                  ctrl.testRequests
                      .where((r) => r.requestType == 'test')
                      .map((r) => r.targetAppId)
                      .toSet();
              // closed_test 앱 중에서, 아직 요청이 없는 앱만 선택 대상
              final closedTestApps =
                  appC.apps
                      .where(
                        (a) =>
                            a.appState == 'closed_test' &&
                            !existingIds.contains(a.id),
                      )
                      .toList();
              if (closedTestApps.isEmpty) {
                Get.snackbar(
                  '등록할 수 있는 앱 없음',
                  '내 정보에서 closed_test인 앱을 먼저 등록하세요.',
                );
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
                        itemCount: closedTestApps.length,
                        itemBuilder: (context, index) {
                          final app = closedTestApps[index];
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
                // --- 하단 시트로 필드 입력 ---
                final result = await showTestRequestBottomSheet(context);
                if (result != null && result['description']!.isNotEmpty) {
                  ctrl.submit(
                    selected.id,
                    result['description']!,
                    descUrl: result['cafeUrl'],
                    appLink: result['appLink'],
                    webLink: result['webLink'],
                  );
                } else {
                  Get.snackbar('오류', '앱 설명은 필수입니다.');
                }
              }
            },
          ),
          NotificationBadgeButton(),
        ],
      ),
      body: Obx(() {
        final list = ctrl.testRequests;
        return RefreshIndicator(
          onRefresh: () async {
            await ctrl.loadRequests();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Obx(
                  () => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8.0,
                    ),
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
                            DropdownMenuItem(
                              value: 'trust',
                              child: Text('신뢰순'),
                            ),
                          ],
                          onChanged: (v) {
                            ctrl.sortBy.value = v ?? 'trust';
                            ctrl.loadRequests();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (ctrl.isLoading.value)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (list.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('등록된 테스트 요청이 없습니다.')),
                )
              else ...[
                NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 100 &&
                        !ctrl.isLoadingMore.value &&
                        ctrl.hasMoreRequests.value) {
                      ctrl.loadMoreRequests();
                    }
                    return false;
                  },
                  child: Obx(
                    () => SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => RequestCard(request: list[i]),
                        childCount: list.length,
                      ),
                    ),
                  ),
                ),
                if (ctrl.isLoadingMore.value)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
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
