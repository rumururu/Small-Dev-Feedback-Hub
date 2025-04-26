// lib/app/ui/pages/review_list_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/review_controller.dart';
import '../components/request_card.dart';

/// 리뷰 품앗이 리스트 화면
class ReviewListPage extends StatelessWidget {
  const ReviewListPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ReviewController>();
    return Scaffold(
      appBar: AppBar(title: const Text('리뷰 품앗이')),
      body: Obx(() {
        final list = ctrl.requests;
        if (list.isEmpty) {
          return const Center(child: Text('등록된 리뷰 요청이 없습니다.'));
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) => RequestCard(request: list[i]),
        );
      }),
    );
  }
}