import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/participation_model.dart';

/// Supabase 'participations' 테이블 CRUD
class ParticipationProvider {
  final _client = Supabase.instance.client;

  /// 참여 신청
  Future<void> apply(String requestId) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('participations').insert({
      'request_id': requestId,
      'user_id': userId,
      'status': 'assigned',
      'requested_at': DateTime.now().toIso8601String(),
    });
  }

  /// 리뷰 완료 등 상태 변경
  Future<void> complete(String partId, String proofUrl) async {
    await _client.from('participations').update({
      'proof_url': proofUrl,
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', partId);
  }
}