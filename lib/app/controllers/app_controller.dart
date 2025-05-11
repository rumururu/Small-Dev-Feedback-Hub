import 'dart:io';

import 'package:get/get.dart';
import '../data/providers/apps_provider.dart';   // Supabase CRUD provider
import '../data/models/app_model.dart';
import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';
import 'package:image_picker/image_picker.dart';

class AppController extends GetxController {
  // ── 상태 ───────────────────────────────────────────────
  final RxList<AppModel> apps = <AppModel>[].obs;
  final RxBool isLoading = false.obs;

  // 폼용 TextEditingController
  final TextEditingController appNameC     = TextEditingController();
  final TextEditingController packageNameC = TextEditingController();

  /// 수정 다이얼로그용 현재 편집중 AppModel
  final Rxn<AppModel> editingApp = Rxn<AppModel>();
  final RxString state = 'closed_test'.obs;

  final RxnString iconFilePath = RxnString();

  final _prov = AppsProvider(); // Supabase provider

  @override
  void onInit() {
    super.onInit();
    fetchApps();
  }

  // ── CRUD ──────────────────────────────────────────────
  Future<void> fetchApps() async {
    isLoading.value = true;
    final list = await _prov.fetchMyApps();
    apps.assignAll(list);
    isLoading.value = false;
  }

  Future<void> submitApp() async {
    final app = AppModel(
      id: '', // 서버에서 auto
      appName: appNameC.text.trim(),
      packageName: packageNameC.text.trim(),
      appState: state.value,
      createdAt: DateTime.now(),
    );
    await _prov.createApp(app, iconFilePath: iconFilePath.value);
    await fetchApps();
  }

  Future<void> updateApp(
      AppModel origin) async {
    final updated = origin.copyWith(
      appName: appNameC.text.trim(),
      packageName: packageNameC.text.trim(),
      appState: state.value,
    );
    await _prov.updateApp(updated, iconFilePath: iconFilePath.value);
    await fetchApps();
  }

  /// 앱 삭제
  /// - 참조 중인 요청이 있으면 FK 제약으로 에러(code 23503) 발생 → 스낵바 안내
  Future<void> deleteApp(AppModel app) async {
    try {
      await _prov.deleteApp(app.id);
      apps.remove(app);
      Get.snackbar('완료', '앱이 삭제되었습니다.');
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        Get.rawSnackbar(
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(8),
          duration: const Duration(seconds: 4),
          message:
              '삭제 불가\n해당 앱과 연결된 테스트/리뷰 요청이 존재합니다.\n요청을 먼저 삭제하거나 앱을 다른 앱으로 변경하세요.',
        );
      } else {
        Get.rawSnackbar(
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(8),
          duration: const Duration(seconds: 3),
          message: '앱 삭제 실패: ${e.message}',
        );
      }
    } catch (e) {
      Get.rawSnackbar(
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 3),
        message: '앱 삭제 중 알 수 없는 오류가 발생했습니다.',
      );
    }
  }

  /// 다이얼로그를 띄우기 전 폼 필드를 초기화/주입한다.
  void prepareForm({AppModel? editing}) {
    if (editing == null) {
      appNameC.clear();
      packageNameC.clear();
      state.value = 'closed_test';
      editingApp.value = null;
      iconFilePath.value = null;
    } else {
      appNameC.text     = editing.appName;
      packageNameC.text = editing.packageName;
      state.value       = editing.appState;
      editingApp.value  = editing;
      iconFilePath.value = editing.iconUrl;
    }
  }

  // ── 유효성 검사 ────────────────────────────────────────
  bool isValidPackage(String v) =>
      RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$').hasMatch(v);

  @override
  void onClose() {
    appNameC.dispose();
    packageNameC.dispose();
    iconFilePath.value = null;
    super.onClose();
  }

  Future<void> pickIconImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final decoded = await decodeImageFromList(await file.readAsBytes());

      final width = decoded.width;
      final height = decoded.height;

      if (width != height) {
        Get.snackbar('이미지 오류', '정사각형 이미지만 선택할 수 있습니다.');
        return;
      }

      if (width > 512 || height > 512) {
        Get.snackbar('이미지 오류', '512x512 이하의 이미지여야 합니다.');
        return;
      }

      iconFilePath.value = pickedFile.path;
    }
  }
}