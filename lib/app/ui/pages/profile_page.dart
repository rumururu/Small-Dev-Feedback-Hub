// lib/app/ui/pages/profile_page.dart

// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/app_controller.dart';
import '../../data/models/app_model.dart';
import '../../data/models/request_model.dart';
import '../../data/providers/requests_provider.dart';
import '../../data/providers/participation_provider.dart';
import '../../data/models/participation_model.dart';

/// 프로필 화면: 사용자 정보 및 내가 등록한 요청 목록
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final authC = Get.find<AuthController>();
    final reqProv = RequestsProvider();
    final appC = Get.find<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이메일: ${authC.user.value?.email ?? ''}'),
            GestureDetector(
              onLongPress: () {
                final editC = TextEditingController(text: authC.user.value?.userMetadata?['full_name'] ?? '');
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('닉네임 수정'),
                    content: TextField(controller: editC, decoration: const InputDecoration(labelText: '닉네임')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                      ElevatedButton(
                        onPressed: () {
                          authC.updateNickname(editC.text.trim());
                          Navigator.pop(context);
                        },
                        child: const Text('저장'),
                      ),
                    ],
                  ),
                );
              },
              child: Text('닉네임: ${authC.user.value?.userMetadata?['full_name'] ?? ''}'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: authC.logout,
              child: const Text('로그아웃'),
            ),
            const SizedBox(height: 16),
            // Removed the 내 앱 등록 폼 Column as per instructions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('내 앱', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    // Properly clear appNameC as well as others
                    appC.appNameC.text = '';
                    appC.packageNameC.clear();
                    appC.cafeUrlC.clear();
                    appC.state.value = 'closed_test';
                    showDialog(
                      context: context,
                      builder: (_) => _AppFormDialog(appC: appC),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Wrap the two Expanded widgets in a Flexible Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Obx(() {
                      final list = appC.apps;
                      if (appC.isLoading.value) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return RefreshIndicator(
                        onRefresh: appC.fetchApps,
                        child: list.isEmpty
                            ? const Center(child: Text('등록된 앱이 없습니다.'))
                            : ListView.builder(
                                itemCount: list.length,
                                itemBuilder: (context, index) {
                                  final app = list[index];
                                  return ListTile(
                                    title: Text(app.appName),
                                    subtitle: Text(app.packageName),
                                    onTap: () {
                                      appC.appNameC.text = app.appName;
                                      appC.packageNameC.text = app.packageName;
                                      appC.cafeUrlC.text = app.cafeUrl ?? '';
                                      appC.state.value = app.appState;
                                      showDialog(
                                        context: context,
                                        builder: (_) => _AppFormDialog(appC: appC, editingApp: app),
                                      );
                                    },
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () {
                                        Get.defaultDialog(
                                          title: '앱 삭제',
                                          middleText: '정말 이 앱을 삭제하시겠습니까?',
                                          textCancel: '취소',
                                          textConfirm: '삭제',
                                          confirmTextColor: Colors.white,
                                          onConfirm: () {
                                            appC.deleteApp(app);
                                            Get.back();
                                          },
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      );
                    }),
                  ),
                  const Divider(height: 32),
                  const Text('내가 등록한 테스트/리뷰', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FutureBuilder<List<RequestModel>>(
                      future: reqProv.fetchRequests(requestType: 'test'),
                      builder: (_, snap) {
                        if (!snap.hasData) return const SizedBox();
                        final mine = snap.data!
                            .where((r) => r.ownerId == authC.user.value?.id)
                            .toList();
                        if (mine.isEmpty) {
                          return const Center(child: Text('등록된 요청이 없습니다.'));
                        }
                        return ListView(
                          children: mine
                              .map((r) => ListTile(title: Text(r.packageName)))
                              .toList(),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 32),
                  const Text('내가 참여한 테스트/리뷰', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: ParticipationProvider().getMyParticipations(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        final list = snap.data!;
                        if (list.isEmpty) {
                          return const Center(child: Text('참여한 내역이 없습니다.'));
                        }
                        return ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final item = list[index];
                            return ListTile(
                              title: Text("${item['appName']} (${item['packageName']})"),
                              subtitle: Text('${item['status'] ?? ''} • ${(item['requestedAt'] is DateTime ? (item['requestedAt'] as DateTime).toLocal().toString().split(' ')[0] : item['requestedAt'] ?? '')}'),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _AppFormDialog extends StatelessWidget {
  final AppController appC;
  final AppModel? editingApp;
  const _AppFormDialog({required this.appC, this.editingApp});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(editingApp == null ? '앱 등록' : '앱 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: appC.appNameC,
              decoration: const InputDecoration(labelText: '앱 이름'),
              enabled: editingApp == null,
            ),
            TextField(
              controller: appC.packageNameC,
              decoration: const InputDecoration(labelText: '패키지 이름'),
              enabled: editingApp == null,
            ),
            TextField(
              controller: appC.cafeUrlC,
              decoration: const InputDecoration(labelText: '카페 요청 주소'),
            ),
            Obx(() {
              final bool isEditable = editingApp == null || (editingApp != null && editingApp!.appState == 'closed_test');
              final items = const [
                DropdownMenuItem(value: 'closed_test', child: Text('closed_test')),
                DropdownMenuItem(value: 'published', child: Text('published')),
              ];
              return DropdownButton<String>(
                value: appC.state.value,
                items: items,
                onChanged: isEditable ? (v) {
                  if (editingApp != null) {
                    if (editingApp!.appState == 'closed_test' && v == 'published') {
                      appC.state.value = v!;
                    }
                  } else {
                    appC.state.value = v!;
                  }
                } : null,
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            if (editingApp == null) {
              appC.submitApp();
            } else {
              appC.updateApp(
                editingApp!,
                appName: appC.appNameC.text.trim(),
                packageName: appC.packageNameC.text.trim(),
                cafeUrl: appC.cafeUrlC.text.trim().isEmpty ? null : appC.cafeUrlC.text.trim(),
                appState: appC.state.value,
              );
            }
            Navigator.pop(context);
          },
          child: Text(editingApp == null ? '등록' : '저장'),
        ),
      ],
    );
  }
}
