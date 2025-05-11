// lib/app/ui/components/image_picker_button.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// A button widget that opens the device gallery and returns the selected image file.
class ImagePickerButton extends StatelessWidget {
  /// Callback invoked when an image is picked (or null if selection was canceled).
  final void Function(File?) onImagePicked;

  /// Label text for the button.
  final String label;

  const ImagePickerButton({
    super.key,
    required this.onImagePicked,
    this.label = '리뷰 이미지 추가',
  });

  /// Compresses [file] iteratively to be under [maxBytes] size.
  /// Compresses [file] iteratively to be under [maxBytes] size.
  static Future<File> _compressToLimit(File file, {int maxBytes = 200 * 1024}) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    File currentFile = file;
    int lastSize = await currentFile.length();
    int quality = 90;

    while (quality > 10) {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        currentFile.path,
        quality: quality,
      );
      if (compressedBytes == null) break;

      // If under size limit, write and return
      if (compressedBytes.lengthInBytes <= maxBytes) {
        final outFile = File(targetPath)..writeAsBytesSync(compressedBytes);
        return outFile;
      }

      // If no further reduction in size, stop to prevent loop
      if (compressedBytes.lengthInBytes >= lastSize) {
        break;
      }

      // Write intermediate compressed result for next iteration
      final intermediateFile = File(targetPath)..writeAsBytesSync(compressedBytes);
      currentFile = intermediateFile;
      lastSize = compressedBytes.lengthInBytes;
      quality -= 10;
    }

    // Return the best available file
    return currentFile;
  }

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
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );
      if (picked == null) return null;
      // Show upload progress
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );
      final file = File(picked.path);
      // Compress image to be <=200KB
      final compressedFile = await _compressToLimit(file);
      try {
        final bytes = await compressedFile.readAsBytes();
        final contentType = lookupMimeType(compressedFile.path) ?? 'image/jpeg';
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
      } finally {
        Get.back();
      }
    } catch (e) {
      debugPrint('pickImageAndUpload error: $e');
      return null;
    }
  }
}
