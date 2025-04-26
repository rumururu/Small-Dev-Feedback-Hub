// lib/app/ui/pages/test_list_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/test_controller.dart';
import '../components/request_card.dart';
import '../components/image_picker_button.dart';

/// 테스트 품앗이 리스트 및 신규 요청 등록
class TestListPage extends StatelessWidget {
  const TestListPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<TestController>();
    return Scaffold(
      appBar: AppBar(title: const Text('테스트 품앗이')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                TextField(
                  controller: ctrl.appNameC,
                  decoration: const InputDecoration(labelText: '앱 이름'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl.descC,
                  decoration: const InputDecoration(labelText: '설명'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ctrl.submit(
                    ctrl.appNameC.text,
                    ctrl.descC.text,
                  ),
                  child: const Text('등록'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Obx(() {
              final list = ctrl.requests;
              if (list.isEmpty) {
                return const Center(child: Text('등록된 테스트 요청이 없습니다.'));
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => RequestCard(request: list[i]),
              );
            }),
          ),
        ],
      ),
    );
  }
}