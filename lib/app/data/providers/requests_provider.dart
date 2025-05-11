import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/request_model.dart';

/// Supabase 'requests' 테이블 CRUD
class RequestsProvider {
  final _client = Supabase.instance.client;

  /// 요청 리스트 가져오기 (조인 없이 기본 request + 추가 조회)
  Future<List<RequestModel>> fetchRequests({
    String? requestType,
    String? ownerId,
    List<String>? statusList,
    bool filterMyParticipation = true,
    String sortBy = 'trust', // 'date' or 'trust'
    DateTime? updatedAtCursor,
  }) async {
    // Select fields, and include participations relation if filtering by participationStatusList
    final baseFields =
        'id, target_app_id, description, owner_id, status, request_type, current_participants, created_at, updated_at, test_started_at, desc_url, trust_score, display_name, app_name, package_name, app_state';
    final viewName =
        (filterMyParticipation)
            ? 'request_with_owner_filtered'
            : 'request_with_owner';
    var query = _client.from(viewName).select(baseFields);

    if (requestType != null) query = query.eq('request_type', requestType);
    if (ownerId != null) query = query.eq('owner_id', ownerId);
    if (statusList != null && statusList.isNotEmpty) {
      query = query.inFilter('status', statusList);
    }

    // If no participation filtering needed, use the normal flow
    // Apply sorting
    PostgrestBuilder queryFinal;
    if (sortBy == 'date') {
      if (updatedAtCursor != null) {
        query = query.lt('updated_at', updatedAtCursor.toIso8601String());
      }
      queryFinal = query.order('updated_at', ascending: false).limit(30);
    } else {
      // Trust-based sorting logic
      if (updatedAtCursor != null) {
        query = query.gt('updated_at', updatedAtCursor.toIso8601String());
      }
      queryFinal = query
          .order('trust_score', ascending: false)
          .order('updated_at', ascending: true)
          .limit(30);
    }

    final res = await queryFinal;
    final data = res as List<dynamic>? ?? [];
    return _mapToRequestModels(data);
  }

  // Helper method to map data to RequestModel objects
  Future<List<RequestModel>> _mapToRequestModels(List<dynamic> data) async {
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
      final updatedAt = DateTime.parse(m['updated_at'] as String);
      final testStartedAt =
          m['test_started_at'] != null
              ? DateTime.parse(m['test_started_at'] as String)
              : null;
      final descUrl = m['desc_url'] as String?;

      requests.add(
        RequestModel(
          id: id,
          targetAppId: targetAppId,
          description: description,
          ownerId: ownerId,
          displayName: m['display_name'] ?? '',
          status: status,
          requestType: requestType,
          currentParticipants: currentParticipants,
          createdAt: createdAt,
          updatedAt: updatedAt,
          testStartedAt: testStartedAt,
          descUrl: descUrl,
          appName: m['app_name'] ?? '',
          packageName: m['package_name'] ?? '',
          appState: m['app_state'] ?? '',
          trustScore: m['trust_score'] ?? 0,
        ),
      );
    }

    return requests;
  }

  /// 새로운 요청을 생성하고, 생성된 요청의 ID를 반환합니다.
  Future<String?> createRequest(RequestModel r) async {
    // 삽입 후 생성된 행의 ID만 선택(select)하여 반환
    final res =
        await _client.from('requests').insert(r.toMap()).select('id').single();
    // Map<String, dynamic> 형태로 반환되므로 'id' 키로 추출
    return (res)['id'] as String?;
  }

  /// 단일 요청 가져오기
  Future<RequestModel?> fetchSingleRequest(String requestId) async {
    final res =
        await _client
            .from('requests')
            .select(
              'id, target_app_id, description, owner_id, status, request_type, current_participants, created_at, updated_at, test_started_at, desc_url',
            )
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
    final updatedAt = DateTime.parse(res['updated_at'] as String);

    final testStartedAt =
        res['test_started_at'] == null
            ? null
            : DateTime.parse(res['test_started_at'] as String);
    final descUrl = res['desc_url'] as String?;

    final appData =
        await _client
            .from('user_apps')
            .select('package_name, app_state, app_name')
            .eq('id', targetAppId)
            .maybeSingle();

    final userData =
        await _client
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
      updatedAt: updatedAt,
      testStartedAt: testStartedAt,
      descUrl: descUrl,
      appName: appData?['app_name'] ?? '',
      packageName: appData?['package_name'] ?? '',
      appState: appData?['app_state'] ?? '',
      trustScore: userData?['trust_score'] ?? 0,
    );
  }

  /// 특정 요청의 참여자 리스트 가져오기
  Future<List<Map<String, dynamic>>> fetchParticipantDetails(
    String requestId,
  ) async {
    final res = await _client
        .from('participations')
        .select(
          'user_id, requested_at, target_request_id, users(display_name, trust_score)',
        )
        .eq('request_id', requestId);

    final data = res as List<dynamic>? ?? [];

    return data
        .map(
          (e) => {
            'user_id': e['user_id'],
            'display_name': e['users']['display_name'] ?? '알 수 없음',
            'trust_score': e['users']['trust_score'] ?? 0,
            'requested_at': DateTime.parse(e['requested_at']),
            'target_request_id': e['target_request_id'],
          },
        )
        .toList();
  }

  // lib/app/data/providers/requests_provider.dart
  /// 테스트 요청을 'open'에서 'testing'으로 전환 (즉시 테스트 시작)
  Future<bool> startTestRequest(String requestId) async {
    try {
      final res = await _client.rpc(
        'start_test_request',
        params: {'p_request_id': requestId},
      );
      return res != null;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return false;
    }
  }

  /// Supabase RPC: 테스트 재시작 처리
  /// - 'restart_test_request' 함수를 호출해 테스트를 재시작합니다.
  Future<bool> restartTestRequest(String requestId) async {
    try {
      final res = await _client.rpc(
        'restart_test_request',
        params: {'request_id': requestId},
      );
      return res != null;
    } catch (e, st) {
      if (kDebugMode) {
        print('restartTestRequest error: $e\n$st');
      }
      return false;
    }
  }

  /// Supabase RPC: 테스트 종료 처리
  /// - 'finish_test_request' 함수를 호출해 테스트를 완료 처리합니다.
  Future<bool> completeTestRequest(String requestId) async {
    try {
      final res = await _client.rpc(
        'complete_test_request',
        params: {'p_request_id': requestId},
      );
      return res != null;
    } catch (e, st) {
      if (kDebugMode) {
        print('finishTestRequest error: $e\n$st');
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUnpairedParticipationForOwner(
    List<String> myReqIds,
  ) async {
    if (myReqIds.isEmpty) return [];

    /* ------------------------------------------------------------------
     *    - request_id ∈ myReqIds (내 요청에 대한 참여)
     *    - target_request_id IS NOT NULL
     *    - is_pairing = false
     *    → target_request 를 embed 하여 상대방 요청 정보를 얻는다.
     * -----------------------------------------------------------------*/
    final rows = await _client
        .from('participations')
        .select('''
          request_id,
          target_request_id,
          target_request:requests!participations_target_request_id_fkey(
            id, target_app_id, description, owner_id, status, request_type,
            current_participants, created_at, updated_at, test_started_at,
            user_apps:target_app_id(app_name, package_name, app_state),
            users:owner_id(display_name, trust_score)
          )
        ''')
        .inFilter('request_id', myReqIds)
        .not('target_request_id', 'is', null)
        .eq('is_pairing', false);

    final data = rows as List<dynamic>? ?? [];

    final List<Map<String, dynamic>> list = [];
    final Set<String> added = {};

    for (final e in data) {
      final tReq = e['target_request'];
      if (tReq == null) continue;

      final reqId = tReq['id'] as String;
      if (added.contains(reqId)) continue;

      final app = tReq['user_apps'];
      final usr = tReq['users'];

      final reqModel = RequestModel(
        id: reqId,
        targetAppId: tReq['target_app_id'] as String,
        description: tReq['description'] as String? ?? '',
        ownerId: tReq['owner_id'] as String,
        displayName: usr?['display_name'] ?? '',
        status: tReq['status'] as String,
        requestType: tReq['request_type'] as String,
        currentParticipants: tReq['current_participants'] as int,
        createdAt: DateTime.parse(tReq['created_at'] as String),
        updatedAt: DateTime.parse(tReq['updated_at'] as String),
        testStartedAt:
            tReq['test_started_at'] == null
                ? null
                : DateTime.parse(tReq['test_started_at'] as String),
        appName: app?['app_name'] ?? '',
        packageName: app?['package_name'] ?? '',
        appState: app?['app_state'] ?? '',
        trustScore: usr?['trust_score'] ?? 0,
      );

      list.add({'my_request_id': e['request_id'], 'request': reqModel});
      added.add(reqId);
    }

    return list;
  }

  /// 테스트 재시작(또는 종료) 처리 RPC
  /// - Supabase에 정의된 'restart_or_finish_test' 함수 호출
  /// - true: 성공, false: 실패
  Future<bool> restartOrFinishTest(String requestId) async {
    try {
      await _client.rpc(
        'restart_or_finish_test',
        params: {'request_id': requestId},
      );
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        print('restartOrFinishTest error: $e\n$st');
      }
      return false;
    }
  }

  /// 리뷰 요청 상태(open ↔ closed) 변경
  /// newStatus는 'open' 또는 'closed' 이어야 함
  Future<bool> updateRequestStatus(String requestId, String newStatus) async {
    try {
      await _client
          .from('requests')
          .update({'status': newStatus})
          .eq('id', requestId);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        print('updateRequestStatus error: $e\n$st');
      }
      return false;
    }
  }

  /// 요청의 상세 정보를 수정하는 메서드
  Future<bool> updateRequestDetails(
    String requestId, {
    required String description,
    String? cafeUrl,
    String? appLink,
    String? webLink,
  }) async {
    try {
      final data = {'description': description, 'desc_url': cafeUrl};

      await _client.from('requests').update(data).eq('id', requestId);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        print('updateRequestDetails error: $e\n$st');
      }
      return false;
    }
  }

  Future<bool> cancelRequest({required String requestId}) async {
    try {
      final res =
          await _client
              .from('requests')
              .delete()
              .eq('id', requestId)
              .eq('status', 'open') // 상태 조건 추가
              .select();
      // 삭제된 데이터 개수로 성공 여부 판단
      return res.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('참여 취소 실패: $e');
      }
      return false;
    }
  }
}
