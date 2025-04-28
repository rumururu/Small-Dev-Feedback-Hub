import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import '../../data/providers/participation_provider.dart';

/// 리뷰 상세 페이지 (proof image 및 승인/신고 UI)
class ReviewDetailPage extends StatelessWidget {
  final String participationId;
  final String proofUrl;
  final bool isCompleted;
  final bool isOwner;
  final VoidCallback? onActionCompleted;
  const ReviewDetailPage({
    super.key,
    required this.participationId,
    required this.proofUrl,
    required this.isCompleted,
    required this.isOwner,
    this.onActionCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('리뷰 상세')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('리뷰 증빙 이미지', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            FutureBuilder<String>(
              future: Supabase.instance.client.storage
                  .from('reviewimage')
                  .createSignedUrl(proofUrl, 60 * 60),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return Center(
                  child: SizedBox(
                    height: 240,
                    child: Image.network(snapshot.data!, fit: BoxFit.contain),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            if (isOwner) ...[
              if (!isCompleted)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await ParticipationProvider().updateParticipationStatus(participationId);
                        if (onActionCompleted != null) onActionCompleted!();
                        Get.back();
                      },
                      child: const Text('리뷰 승인'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      onPressed: () async {
                        final reasonController = TextEditingController();
                        final result = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('리뷰 신고'),
                            content: TextField(
                              controller: reasonController,
                              decoration: const InputDecoration(
                                labelText: '신고 사유를 입력하세요',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, null),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, reasonController.text.trim()),
                                child: const Text('신고'),
                              ),
                            ],
                          ),
                        );
                        if (result != null && result.isNotEmpty) {
                          await ParticipationProvider().createReport(participationId: participationId, reason: result);
                          if (onActionCompleted != null) onActionCompleted!();
                          Get.back();
                          Get.snackbar('완료', '신고가 접수되었습니다.');
                        }
                      },
                      child: const Text('리뷰 신고'),
                    ),
                  ],
                ),
              if (isCompleted)
                const Text('이미 승인된 리뷰입니다.', style: TextStyle(color: Colors.grey)),
            ] else ...[
              if (isCompleted)
                const Text('이미 승인된 리뷰입니다.', style: TextStyle(color: Colors.grey)),
            ]
          ],
        ),
      ),
    );
  }
}