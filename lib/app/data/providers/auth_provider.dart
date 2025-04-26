import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider {
  final _client = Supabase.instance.client;

  /// Google OAuth 로그인
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// 현재 사용자
  User? get currentUser => _client.auth.currentUser;
}