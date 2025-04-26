import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/request_model.dart';

/// Supabase 'requests' 테이블 CRUD
class RequestsProvider {
  final _client = Supabase.instance.client;

  /// 스트림: type으로 필터링한 요청 리스트
  Stream<List<RequestModel>> streamRequests({required String type}) {
    return _client
        .from('requests')
        .stream(primaryKey: ['id'])
        .eq('type', type)
        .order('created_at', ascending: false)
        .map((maps) => maps
        .map((m) => RequestModel.fromMap(m as Map<String, dynamic>))
        .toList());
  }

  /// 새 요청 삽입
  Future<void> createRequest(RequestModel r) async {
    await _client.from('requests').insert(r.toMap());
  }
}