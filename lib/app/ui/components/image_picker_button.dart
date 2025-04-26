// lib/app/ui/components/image_picker_button.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A button widget that opens the device gallery and returns the selected image file.
class ImagePickerButton extends StatelessWidget {
  /// Callback invoked when an image is picked (or null if selection was canceled).
  final void Function(File?) onImagePicked;

  /// Label text for the button.
  final String label;

  const ImagePickerButton({
    Key? key,
    required this.onImagePicked,
    this.label = '사진 선택',
  }) : super(key: key);

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
}
