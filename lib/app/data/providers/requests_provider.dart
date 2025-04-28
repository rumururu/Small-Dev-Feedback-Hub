import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/request_model.dart';

/// Supabase 'requests' 테이블 CRUD
class RequestsProvider {
  final _client = Supabase.instance.client;

  /// 요청 리스트 가져오기 (조인 없이 기본 request + 추가 조회)
  Future<List<RequestModel>> fetchRequests({required String requestType}) async {
    final res = await _client
        .from('requests')
        .select('id, target_app_id, description, owner_id, status, request_type, current_participants, created_at')
        .eq('request_type', requestType);

    final data = res as List<dynamic>? ?? [];

    List<RequestModel> requests = [];

    for (final m in data) {
      final id = m['id'] as String;
      final targetAppId = m['target_app_id'] as String;
      final description = m['description'] as String? ?? '';
      final ownerId = m['owner_id'] as String;
      final status = m['status'] as String;
      final requestType = m['request_type'] as String;
      final currentParticipants = m['current_participants'] as int;
      final createdAt = DateTime.parse(m['created_at'] as String);

      final appData = await _client
          .from('user_apps')
          .select('package_name, app_state, cafe_url, app_name')
          .eq('id', targetAppId)
          .maybeSingle();

      final userData = await _client
          .from('users')
          .select('display_name, trust_score')
          .eq('id', ownerId)
          .maybeSingle();

      requests.add(RequestModel(
        id: id,
        targetAppId: targetAppId,
        description: description,
        ownerId: ownerId,
        displayName: userData?['display_name'] ?? '',
        status: status,
        requestType: requestType,
        currentParticipants: currentParticipants,
        createdAt: createdAt,
        appName: appData?['app_name'] ?? '',
        packageName: appData?['package_name'] ?? '',
        appState: appData?['app_state'] ?? '',
        cafeUrl: appData?['cafe_url'],
        trustScore: userData?['trust_score'] ?? 0,
      ));
    }

    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return requests;
  }

  /// 새 요청 삽입
  Future<void> createRequest(RequestModel r) async {
    await _client.from('requests').insert(r.toMap());
  }

  /// 단일 요청 가져오기
  Future<RequestModel?> fetchSingleRequest(String requestId) async {
    final res = await _client
        .from('requests')
        .select('id, target_app_id, description, owner_id, status, request_type, current_participants, created_at')
        .eq('id', requestId)
        .maybeSingle();

    if (res == null) return null;

    final id = res['id'] as String;
    final targetAppId = res['target_app_id'] as String;
    final description = res['description'] as String? ?? '';
    final ownerId = res['owner_id'] as String;
    final status = res['status'] as String;
    final requestType = res['request_type'] as String;
    final currentParticipants = res['current_participants'] as int;
    final createdAt = DateTime.parse(res['created_at'] as String);

    final appData = await _client
        .from('user_apps')
        .select('package_name, app_state, cafe_url, app_name')
        .eq('id', targetAppId)
        .maybeSingle();

    final userData = await _client
        .from('users')
        .select('display_name, trust_score')
        .eq('id', ownerId)
        .maybeSingle();

    return RequestModel(
      id: id,
      targetAppId: targetAppId,
      description: description,
      ownerId: ownerId,
      displayName: userData?['display_name'] ?? '',
      status: status,
      requestType: requestType,
      currentParticipants: currentParticipants,
      createdAt: createdAt,
      appName: appData?['app_name'] ?? '',
      packageName: appData?['package_name'] ?? '',
      appState: appData?['app_state'] ?? '',
      cafeUrl: appData?['cafe_url'],
      trustScore: userData?['trust_score'] ?? 0,
    );
  }

  /// 특정 요청의 참여자 리스트 가져오기
  Future<List<Map<String, dynamic>>> fetchParticipantDetails(String requestId) async {
    final res = await _client
        .from('participations')
        .select('user_id, requested_at, target_request_id, users(display_name, trust_score)')
        .eq('request_id', requestId);

    final data = res as List<dynamic>? ?? [];

    return data.map((e) => {
      'user_id': e['user_id'],
      'display_name': e['users']['display_name'] ?? '알 수 없음',
      'trust_score': e['users']['trust_score'] ?? 0,
      'requested_at': DateTime.parse(e['requested_at']),
      'target_request_id': e['target_request_id'],
    }).toList();
  }

}

