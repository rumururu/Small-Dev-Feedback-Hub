import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushService {
  final supabase = Supabase.instance.client;

  Future<void> registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final userId = supabase.auth.currentUser!.id;

    try {
      // 기존 토큰 배열을 가져옵니다.
      final response = await supabase
          .from('users')
          .select('fcm_tokens')
          .eq('id', userId)
          .single();

      // 토큰 데이터 처리
      final List<dynamic> tokens = (response['fcm_tokens'] as List<dynamic>?) ?? [];

      // 중복 토큰 추가 방지
      if (!tokens.contains(token)) {
        tokens.add(token);

        // 업데이트
        await supabase
            .from('users')
            .update({'fcm_tokens': tokens})
            .eq('id', userId);
      }
    } catch (e) {
      print('토큰 처리 중 오류 발생: $e');
    }
  }
}