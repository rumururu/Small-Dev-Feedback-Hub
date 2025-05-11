import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/app_controller.dart';
import '../../controllers/request_controller.dart';
import '../../data/models/app_model.dart';
import '../components/notification_badge_button.dart';
import '../components/request_card.dart';
// 경로는 실제 위치에 맞게 수정

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authC = Get.find<AuthController>();
    final appC = Get.find<AppController>();
    final reqC = Get.put(RequestController())..setRequestType(null);
    reqC.loadMyToDo();

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보'), actions: [NotificationBadgeButton(),],),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          padding: const EdgeInsets.all(0),
          children: [
            Text('이메일: ${authC.user.value?.email ?? ''}'),
            Row(
              children: [
                Obx(
                  () => Expanded(
                    child: Text(
                      '닉네임: ${authC.user.value?.userMetadata?['full_name'] ?? ''}',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showNicknameDialog(context, authC),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '내 앱',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => appC.fetchApps(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _openAppDialog(context, appC),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (appC.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (appC.apps.isEmpty) {
                return const Center(child: Text('등록된 앱이 없습니다.'));
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: appC.apps.length,
                itemBuilder: (context, index) {
                  final app = appC.apps[index];
                  return ListTile(
                    title: Text(app.appName),
                    subtitle: Text(app.packageName),
                    onTap: () => _openAppDialog(context, appC, editing: app),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _confirmDeleteApp(context, appC, app),
                    ),
                  );
                },
              );
            }),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('내 테스트/리뷰', style: TextStyle(fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => reqC.loadMyRequests(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (reqC.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (reqC.myRequests.isEmpty) {
                return const Center(child: Text('등록된 요청이 없습니다.'));
              }
              return ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children:
                    reqC.myRequests
                        .map((r) => RequestCard(request: r))
                        .toList(),
              );
            }),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('품앗이 필요', style: TextStyle(fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => reqC.loadMyToDo(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (reqC.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (reqC.todoRequests.isEmpty) {
                return const Center(child: Text('참여해야 할 내역이 없습니다.'));
              }
              return ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children:
                    reqC.todoRequests
                        .where((r) => !(r['is_pairing'] ?? false))
                        .map(
                          (r) => RequestCard(
                            request: r['request'],
                            autoPairingRequestId: r['my_request_id'],
                          ),
                        )
                        .toList(),
              );
            }),
            const SizedBox(height: 64),
            ElevatedButton(
              onPressed: Get.find<AuthController>().logout,
              child: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────── helper widgets ──────────────────
  void _showNicknameDialog(BuildContext ctx, AuthController authC) {
    final c = TextEditingController(
      text: authC.user.value?.userMetadata?['full_name'] ?? '',
    );
    showDialog(
      context: ctx,
      builder:
          (_) => AlertDialog(
            title: const Text('닉네임 수정'),
            content: TextField(
              controller: c,
              decoration: const InputDecoration(labelText: '닉네임'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  authC.updateNickname(c.text.trim());
                  Navigator.pop(ctx);
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );
  }

  void _openAppDialog(
    BuildContext ctx,
    AppController appC, {
    AppModel? editing,
  }) {
    final themeData = Get.theme;
    appC.prepareForm(editing: editing);

    Get.bottomSheet(
      _AppFormSheet(), // 새 bottom‑sheet 위젯
      isScrollControlled: true,
      backgroundColor: themeData.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    );
  }

  void _confirmDeleteApp(BuildContext ctx, AppController appC, AppModel app) {
    Get.defaultDialog(
      title: '앱 삭제',
      middleText: '정말 이 앱을 삭제하시겠습니까?',
      textCancel: '취소',
      textConfirm: '삭제',
      confirmTextColor: Colors.white,
      onConfirm: () async {
        // 먼저 확인 다이얼로그 닫기
        Get.back();

        try {
          await appC.deleteApp(app);
        } catch (_) {
          // deleteApp 내부에서 스낵바 처리; 여기선 무시
        }
      },
    );
  }
}

/// 등록/수정 bottom‑sheet
class _AppFormSheet extends GetWidget<AppController> {
  @override
  Widget build(BuildContext context) {
    final isEdit = controller.editingApp.value != null;
    final editing = controller.editingApp.value;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 24,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isEdit ? '앱 상태 변경' : '앱 등록',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.appNameC,
            decoration: const InputDecoration(labelText: '앱 이름'),
            enabled: !isEdit,
          ),
          TextField(
            controller: controller.packageNameC,
            decoration: InputDecoration(
              labelText: '패키지 이름',
              errorText:
                  controller.isValidPackage(controller.packageNameC.text)
                      ? null
                      : '올바르지 않은 패키지',
            ),
            enabled: !isEdit,
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
          const SizedBox(height: 8),
          Obx(
            () => DropdownButton<String>(
              value: controller.state.value,
              items: const [
                DropdownMenuItem(
                  value: 'closed_test',
                  child: Text('closed_test'),
                ),
                DropdownMenuItem(
                  value: 'published',
                  child: Text('published'),
                ),
              ],
              onChanged: (v) => controller.state.value = v!,
            ),
          ),
          const SizedBox(height: 24),
          // --- Image selection widgets start here ---
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          Obx(() {
            final filePath = controller.iconFilePath.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('앱 아이콘(비공개 테스트용)'),
                    IconButton(
                      onPressed: controller.pickIconImage,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (filePath != null)
                  if (filePath.startsWith('https://'))
                    Image.network(
                      filePath,
                      width: 150,
                      height: 150,
                    )
                  else
                    Image.file(File(filePath), width: 150, height: 150),
                const SizedBox(height: 16),
              ],
            );
          }),
          // --- Image selection widgets end here ---
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('취소'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  if (!isEdit) {
                    controller.submitApp();
                  } else {
                    controller.updateApp(editing!);
                  }
                  Get.back();
                },
                child: Text(isEdit ? '저장' : '등록'),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
