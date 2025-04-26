// lib/app/ui/pages/request_detail_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/request_model.dart';
import '../../data/providers/participation_provider.dart';
import '../components/image_picker_button.dart';

/// 요청 상세 페이지: 테스트 신청 또는 리뷰 완료 처리
class RequestDetailPage extends StatelessWidget {
  final RequestModel request;
  const RequestDetailPage({Key? key, required this.request}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final partProv = ParticipationProvider();
    return Scaffold(
      appBar: AppBar(title: Text(request.appName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.description),
            const SizedBox(height: 24),
            if (request.type == 'test') ...[
              ElevatedButton(
                onPressed: () async {
                  await partProv.apply(request.id);
                  Get.back();
                },
                child: const Text('테스트 참여 신청'),
              ),
            ] else ...[
              ImagePickerButton(
                onImagePicked: (file) async {
                  if (file != null) {
                    await partProv.complete(request.id, file.path);
                    Get.back();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}