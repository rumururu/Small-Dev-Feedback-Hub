// lib/app/ui/components/image_picker_button.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A button widget that opens the device gallery and returns the selected image file.
class ImagePickerButton extends StatelessWidget {
  /// Callback invoked when an image is picked (or null if selection was canceled).
  final void Function(File?) onImagePicked;

  /// Label text for the button.
  final String label;

  const ImagePickerButton({
    super.key,
    required this.onImagePicked,
    this.label = '사진 선택',
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.photo_library),
      label: Text(label),
      onPressed: () async {
        final picker = ImagePicker();
        final XFile? picked = await picker.pickImage(
          source: ImageSource.gallery,
        );
        if (picked != null) {
          onImagePicked(File(picked.path));
        } else {
          onImagePicked(null);
        }
      },
    );
  }

  static Future<String?> pickImageAndUpload() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return null;

      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final contentType = lookupMimeType(file.path) ?? 'image/jpeg';

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final path = 'proofs/$fileName';

      final storageResponse = await Supabase.instance.client.storage
          .from('reviewimage')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      if (storageResponse.isEmpty) {
        debugPrint('Storage upload failed.');
        return null;
      }

      return path; // Only the path like 'proofs/xxx.jpg' is returned
    } catch (e) {
      debugPrint('pickImageAndUpload error: $e');
      return null;
    }
  }
}
