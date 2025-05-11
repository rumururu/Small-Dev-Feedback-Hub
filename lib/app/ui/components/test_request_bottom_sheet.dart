import 'package:flutter/material.dart';

Future<Map<String, String>?> showTestRequestBottomSheet(BuildContext context, {
  Map<String, String>? initialData,
}) {
  final descC = TextEditingController(text: initialData?['description'] ?? '');
  final cafeC = TextEditingController(text: initialData?['cafeUrl'] ?? '');

  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descC,
              decoration: const InputDecoration(labelText: '앱 설명'),
            ),
            TextField(
              controller: cafeC,
              decoration: const InputDecoration(labelText: '카페 주소 (선택)'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final map = {
                      'description': descC.text.trim(),
                      'cafeUrl': cafeC.text.trim(),
                    };
                    Navigator.pop(context, map);
                  },
                  child: const Text('등록'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}