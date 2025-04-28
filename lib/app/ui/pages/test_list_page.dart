// lib/app/ui/pages/test_list_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/test_controller.dart';
import '../../data/models/app_model.dart';
import '../components/request_card.dart';
import '../../controllers/app_controller.dart';

/// 테스트 품앗이 리스트 및 신규 요청 등록
class TestListPage extends StatelessWidget {
  const TestListPage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<TestController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('테스트 품앗이'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final appC = Get.find<AppController>();
              final closedTestApps = appC.apps.where((a) => a.appState == 'closed_test').toList();
              if (closedTestApps.isEmpty) {
                Get.snackbar('알림', '등록할 수 있는 앱이 없습니다.');
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
                // 중복 요청 방지: 같은 앱에 대해 같은 타입 요청이 이미 있으면 등록 막기
                final existing = ctrl.requests.where((r) =>
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
          ),
        ],
      ),
      body: Obx(() {
        final list = ctrl.requests;
        if (list.isEmpty) {
          return const Center(child: Text('등록된 테스트 요청이 없습니다.'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            await ctrl.loadRequests();
          },
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => RequestCard(request: list[i]),
          ),
        );
      }),
    );
  }
}