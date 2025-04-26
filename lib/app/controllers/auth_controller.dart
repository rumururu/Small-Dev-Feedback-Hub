import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/providers/auth_provider.dart';

class AuthController extends GetxController {
  final _authProv = Get.find<AuthProvider>();
  var user = Rxn<User>();

  @override
  void onInit() {
    super.onInit();
    // Supabase Auth 상태 변화 구독
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      user.value = data.session?.user;
    });
    // 초기값 세팅
    user.value = _authProv.currentUser;
  }

  Future<void> loginWithGoogle() => _authProv.signInWithGoogle();
  Future<void> logout()        => _authProv.signOut();
}