import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/app_model.dart';
import '../data/providers/apps_provider.dart';

/// Controller for managing user_apps table entries
class AppController extends GetxController {
  final AppsProvider _prov = AppsProvider();

  // Form controllers
  final appNameC     = TextEditingController();
  final packageNameC = TextEditingController();
  final cafeUrlC     = TextEditingController();
  final state        = 'closed_test'.obs;

  // 앱 리스트 상태
  var apps = <AppModel>[].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchApps();
  }

  /// 앱 리스트 가져오기 (stream 대신)
  Future<void> fetchApps() async {
    isLoading.value = true;
    final list = await _prov.getMyApps();
    apps.assignAll(list);
    isLoading.value = false;
  }

  /// 새 앱 등록
  Future<void> submitApp() async {
    final current = Supabase.instance.client.auth.currentUser;
    if (current != null) {
      await Supabase.instance.client
          .from('users')
          .upsert([
        {
          'id': current.id,
          'email': current.email,
          'display_name': current.userMetadata?['full_name'] ?? current.email,
        }
      ]);
    }

    final model = AppModel(
      id: '',
      appName: appNameC.text.trim(),
      packageName: packageNameC.text.trim(),
      appState: state.value,
      cafeUrl: cafeUrlC.text.trim().isEmpty ? null : cafeUrlC.text.trim(),
      createdAt: DateTime.now(),
    );
    final newApp = await _prov.createApp(model);
    apps.insert(0, newApp);

    appNameC.clear();
    packageNameC.clear();
    cafeUrlC.clear();
    state.value = 'closed_test';
  }

  /// 앱 수정
  Future<void> updateApp(
      AppModel app, {
        required String appName,
        required String packageName,
        String? cafeUrl,
        required String appState,
      }) async {
    final updated = AppModel(
      id: app.id,
      appName: appName,
      packageName: packageName,
      appState: appState,
      cafeUrl: cafeUrl,
      createdAt: app.createdAt,
    );
    await _prov.updateApp(updated);
    await fetchApps();
  }

  /// 앱 삭제
  Future<void> deleteApp(AppModel app) async {
    await _prov.deleteApp(app.id);
    await fetchApps();
  }
}