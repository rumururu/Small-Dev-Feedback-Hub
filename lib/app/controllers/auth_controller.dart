// lib/app/controllers/auth_controller.dart

// ignore_for_file: unused_local_variable

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added for env variables
import '../middleware/push_service.dart';

class AuthController extends GetxController {
  late final StreamSubscription<AuthState> _authSubscription;
  final supabase = Supabase.instance.client;
  final user = Rxn<User>();

  @override
  void onInit() {
    super.onInit();
    user.value = supabase.auth.currentSession?.user;

    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      final event = data.event;
      user.value = session?.user;

      if (user.value != null) {
        await PushService().registerToken();
      }

      if (event == AuthChangeEvent.signedIn) {
        if (user.value != null) {
          await PushService().registerToken();
          Get.offAllNamed('/home');
        }
      }
    });
  }

  Future<void> loginWithGoogle() async {
    // Show loading indicator
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final googleUser = await GoogleSignIn(
        serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
      ).signIn();
      if (googleUser == null) return;

      final auth = await googleUser.authentication;
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: auth.idToken!,
        accessToken: auth.accessToken!,
      );

      if (response.session != null && response.user != null) {
        final user = response.user!;
        this.user.value = user;

        await Supabase.instance.client
            .from('users')
            .upsert({
          'id': user.id,
          'email': user.email,
          'display_name': user.userMetadata?['full_name'] ?? user.email,
        });

        // Navigate to home on success
        Get.offAllNamed('/home');
      } else {
        Get.snackbar('로그인 실패', '다시 시도해주세요.');
      }
    } catch (err) {
      if (kDebugMode) {
        if (kDebugMode) {
          print('로그인 오류: $err');
        }
      }
      Get.snackbar('로그인 오류', err.toString());
    } finally {
      // Dismiss loading indicator
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    }
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
      await _authSubscription.cancel();
      Get.offAllNamed('/login');
    } catch (e) {
      Get.snackbar('오류', e.toString());
    }
  }

  /// 닉네임(Full Name) 수정
  Future<void> updateNickname(String name) async {
    try {
      await supabase.auth.updateUser(
        UserAttributes(data: {'full_name': name}),
      );

      // Refresh local user value from current session
      user.value = supabase.auth.currentSession?.user;
      // Upsert into custom users table
      final currentUser = user.value;
      if (currentUser != null) {
        await supabase.from('users').upsert({
          'id': currentUser.id,
          'email': currentUser.email,
          'display_name': name,
        });
        user.value = supabase.auth.currentSession?.user;
        user.refresh();

      }
      Get.snackbar('완료', '닉네임이 성공적으로 변경되었습니다.');
    } catch (e) {
      print('오류 ${e.toString()}');
      Get.snackbar('오류', e.toString());
    }
  }


}
