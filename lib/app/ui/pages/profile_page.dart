// lib/app/ui/pages/profile_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../data/models/request_model.dart';
import '../../data/providers/requests_provider.dart';

/// 프로필 화면: 사용자 정보 및 내가 등록한 요청 목록
class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final authC = Get.find<AuthController>();
    final reqProv = RequestsProvider();
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이메일: ${authC.user.value?.email ?? ''}'),
            Text('닉네임: ${authC.user.value?.userMetadata?['full_name'] ?? ''}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: authC.logout,
              child: const Text('로그아웃'),
            ),
            const Divider(height: 32),
            const Text('내가 등록한 요청:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<RequestModel>>(
                stream: reqProv.streamRequests(type: 'test'),
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
                        .map((r) => ListTile(title: Text(r.appName)))
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}