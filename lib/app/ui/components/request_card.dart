import 'package:flutter/material.dart';
import '../../data/models/request_model.dart';
import '../pages/request_detail_page.dart';

/// A card widget displaying a single RequestModel.
/// On tap, navigates to the detail page.
class RequestCard extends StatelessWidget {
  final RequestModel request;

  const RequestCard({
    super.key,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: ListTile(
        title: Text(request.appName),
        subtitle: Text(request.displayName),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group, size: 20),
            Text('${request.currentParticipants}'),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RequestDetailPage(request: request),
            ),
          );
        },
      ),
    );
  }
}