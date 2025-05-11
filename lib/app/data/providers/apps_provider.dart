import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mime/mime.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/app_model.dart';

/// Supabase 'user_apps' 테이블 CRUD
class AppsProvider {
  final _client = Supabase.instance.client;

  /// 앱 리스트 가져오기 (stream → fetch)
  Future<List<AppModel>> fetchMyApps() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      // 인증된 사용자가 없으면 빈 리스트 반환
      return [];
    }
    final userId = currentUser.id;
    final rows = await _client
        .from('user_apps')
        .select('*')
        .eq('owner_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => AppModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<AppModel> createApp(AppModel app, {String? iconFilePath}) async {
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    String? iconStoragePath;
    if (iconFilePath != null) {
      final file = File(iconFilePath);
      final fileExt = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'icon/$fileName';

      final storageResponse = await _client.storage.from('icon').upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      if (storageResponse.isNotEmpty) {
        final supabaseUrl = dotenv.env['SUPABASE_URL']!;
        final storagePrefix =
            '$supabaseUrl/storage/v1/object/public/icon/';
        iconStoragePath = '$storagePrefix/$filePath';
      }
    }

    final data = app.toMap()..['owner_id'] = _client.auth.currentUser!.id;
    if (iconStoragePath != null) {
      data['icon_url'] = iconStoragePath;
    }

    final res = await _client
        .from('user_apps')
        .insert(data)
        .select()
        .single();

    Get.back();
    return AppModel.fromMap(res);
  }

  Future<void> updateApp(AppModel app, {String? iconFilePath}) async {
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    final updates = app.toMap();
    if (iconFilePath != null) {
      final file = File(iconFilePath);
      final bytes = await file.readAsBytes();
      final contentType = lookupMimeType(file.path) ?? 'image/jpeg';

      final fileName = '${app.packageName}.${file.uri.pathSegments.last.contains('.') ? file.uri.pathSegments.last.split('.').last : ''}';
      final filePath = '$fileName';

      final storageResponse = await _client.storage.from('icon').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );

      if (storageResponse.isNotEmpty) {
        final supabaseUrl = dotenv.env['SUPABASE_URL']!;
        final storagePrefix =
            '$supabaseUrl/storage/v1/object/public/icon/';
        updates['icon_url'] = '$storagePrefix/$filePath';
      } else {
        debugPrint('Icon upload failed.');
      }
    }
    await _client.from('user_apps').update(updates).eq('id', app.id);
    Get.back();
  }

  Future<void> deleteApp(String id) async {
    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);
    try {
      await _client.from('user_apps').delete().eq('id', id);
    } finally {
      if (Get.isDialogOpen == true) Get.back(); // 무조건 다이얼로그 닫기
    }
  }
}