import 'package:flutter/material.dart';
import '../../data/models/request_model.dart';
import '../pages/request_detail_page.dart';
import 'package:get/get.dart';
/// A card widget displaying a single RequestModel.
/// On tap, navigates to the detail page.
class RequestCard extends StatelessWidget {
  final RequestModel request;
  final String? autoPairingRequestId;

  const RequestCard({
    super.key,
    required this.request,
    this.autoPairingRequestId
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: ListTile(
        title: Text(request.appName),
        subtitle: Text('${request.requestType} 요청, ${request.displayName} (${request.trustScore} 점)'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group, size: 20),
            Text('${request.currentParticipants}'),
          ],
        ),
        onTap: () {
          Get.to(
                () => RequestDetailPage(request: request),
            arguments: {'autoPairingRequestId': autoPairingRequestId},
          );
        },
      ),
    );
  }
}