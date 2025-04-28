import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/app_model.dart';

/// Supabase 'user_apps' 테이블 CRUD
class AppsProvider {
  final _client = Supabase.instance.client;

  /// 앱 리스트 가져오기 (stream → fetch)
  Future<List<AppModel>> getMyApps() async {
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

  Future<AppModel> createApp(AppModel app) async {
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    final data = app.toMap()..['owner_id'] = _client.auth.currentUser!.id;
    final res = await _client
        .from('user_apps')
        .insert(data)
        .select()
        .single();
    Get.back();
    return AppModel.fromMap(res);
  }

  Future<void> updateApp(AppModel app) async {
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    await _client
        .from('user_apps')
        .update(app.toMap())
        .eq('id', app.id);
    Get.back();
  }

  Future<void> deleteApp(String id) async {
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    await _client
        .from('user_apps')
        .delete()
        .eq('id', id);
    Get.back();
  }
}