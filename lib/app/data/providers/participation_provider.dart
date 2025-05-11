// ignore_for_file: unused_import

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/participation_model.dart';

/// Supabase 'participations' 테이블 CRUD
class ParticipationProvider {
  final _client = Supabase.instance.client;

  /// 참여 신청
  Future<bool> createParticipation({
    required String ownerId,
    required String requestId,
    required String requestType,
    required String appName,
    required String participantName,
    String? targetRequestId,
    String? proofUrl,
  }) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    // RPC로 참여 삽입 및 알림 생성
    try {
      await Supabase.instance.client.rpc(
        'create_participation',
        params: {
          'p_owner_id': ownerId,
          'p_request_id': requestId,
          'p_participant_id': Supabase.instance.client.auth.currentUser!.id,
          'p_target_request_id': targetRequestId,
          'p_proof_url': proofUrl ?? '',
          'p_request_type': requestType,
          'p_participant_name': participantName,
          'p_app_name': appName,
        },
      );
      Get.back();
      return true;
    } catch (e) {
      Get.back();
      if (kDebugMode) {
        print('오류 발생: $e');
      }
      Get.rawSnackbar(message: '오류 발생: $e');
      return false;
    } finally {
    }
  }

  Future<bool> hasParticipated({required String requestId}) async {
    final userId = _client.auth.currentUser!.id;
    final res =
        await _client
            .from('participations')
            .select('id')
            .eq('request_id', requestId)
            .eq('user_id', userId)
            .maybeSingle();
    return res != null;
  }

  Future<bool?> cancelParticipation({required String requestId}) async {
    final userId = _client.auth.currentUser!.id;
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      // 상태 확인: 'pending'일 때만 취소 가능
      final statusRes =
          await _client
              .from('participations')
              .select('status')
              .eq('request_id', requestId)
              .eq('user_id', userId)
              .maybeSingle();
      final currentStatus = statusRes?['status'] as String?;
      if (currentStatus != 'pending') {
        // 진행 중이거나 완료된 참여는 취소 불가
        return null;
      }

      // 먼저 proof_url 조회
      final fetchRes =
          await _client
              .from('participations')
              .select('proof_url')
              .eq('request_id', requestId)
              .eq('user_id', userId)
              .maybeSingle();

      final proofUrl =
          fetchRes != null ? fetchRes['proof_url'] as String? : null;

      if (proofUrl != null && proofUrl.isNotEmpty) {
        // 파일 경로 추출 (Storage full URL이면 prefix 제거 필요)
        final supabaseUrl = dotenv.env['SUPABASE_URL']!;
        final storagePrefix =
            '$supabaseUrl/storage/v1/object/public/reviewimage/';
        final path = proofUrl.replaceFirst(storagePrefix, '');

        // Supabase Storage에서 파일 삭제
        await _client.storage.from('reviewimage').remove([path]);
      }

      final res =
          await _client
              .from('participations')
              .delete()
              .eq('request_id', requestId)
              .eq('user_id', userId)
              .eq('status', 'pending') // 상태 조건 추가
              .select();

      // 삭제된 데이터 개수로 성공 여부 판단
      return res.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('참여 취소 실패: $e');
      }
      return false;
    } finally {
      Get.back();
    }
  }

  Future<List<Map<String, dynamic>>> getParticipantDetails({
    required String requestId,
  }) async {
    final res = await _client
        .from('participations')
        .select(
          'id, user_id, requested_at, target_request_id, proof_url, is_pairing, status, tester_registered, users(display_name, trust_score, email), target_request_type:target_request_id(request_type)',
        )
        .eq('request_id', requestId);
    final data = res as List<dynamic>;
    return data
        .map(
          (e) => {
            'participation_id': e['id'],
            'user_id': e['user_id'] ?? 'Unknown',
            'display_name': e['users']['display_name'] ?? 'Unknown',
            'trust_score': e['users']['trust_score'] ?? 0,
            'user_email': e['users']['email'] ?? '',
            'target_request_id': e['target_request_id'],
            'proof_url': e['proof_url'],
            'requested_at': DateTime.parse(e['requested_at']),
            'target_request_type':
                (e['target_request_type']
                        as Map<String, dynamic>?)?['request_type']
                    as String?,
            'is_pairing': e['is_pairing'],
            'status': e['status'],
            'tester_registered': e['tester_registered']
          },
        )
        .toList();
  }

  Future<bool> finishReviewParticipation({required String participationId, required String appName}) async {
    try {
      final res = await _client.rpc(
        'finish_review_participation',
        params: {'participation_id': participationId, 'p_app_name': appName},
      );
      return res != null;
    } catch (e, st) {
      if (kDebugMode) {
        print('finishReviewParticipation error: $e\n$st');
      }
      return false;
    }
  }

  /// 신고 생성
  Future<void> createReport({
    required String participationId,
    required String reason,
  }) async {
    final userId = _client.auth.currentUser!.id;
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      await _client.from('reports').insert({
        'participation_id': participationId,
        'reporter_id': userId,
        'reason': reason,
      });

      // 신고 생성 후, 해당 참여 상태를 'reported'로 변경
      await _client
          .from('participations')
          .update({'status': 'reported'})
          .eq('id', participationId);
    } finally {
      Get.back();
    }
  }

  /// 현재 사용자 참여 내역 조회 (앱 이름 포함)
  Future<List<Map<String, dynamic>>> getMyParticipation() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return [];
    final userId = currentUser.id;

    final res = await _client
        .from('participations')
        .select('''
  id, request_id, user_id, status, proof_url, requested_at, completed_at, tester_registered,
  requests!participations_request_id_fkey(target_app_id, user_apps(app_name, package_name))''')
        .eq('user_id', userId)
        .order('requested_at', ascending: false);

    final data = res as List<dynamic>;
    return data.map((e) {
      final m = e as Map<String, dynamic>;
      final nested = m['requests'] as Map<String, dynamic>? ?? {};
      final ua = nested['user_apps'] as Map<String, dynamic>? ?? {};
      return {
        'id': m['id'],
        'requestId': m['request_id'],
        'userId': m['user_id'],
        'status': m['status'],
        'proofUrl': m['proof_url'],
        'requestedAt': DateTime.parse(m['requested_at']),
        'completedAt':
            m['completed_at'] != null
                ? DateTime.parse(m['completed_at'])
                : null,
        'appName': ua['app_name'] as String? ?? '',
        'packageName': ua['package_name'] as String? ?? '',
        'tester_registered': m['tester_registered']
      };
    }).toList();
  }

  Future<bool> markTesterRegistered({
    required String participationId,
    required String appName,
  }) async {
    final response = await Supabase.instance.client.rpc(
      'mark_tester_registered',
      params: {
        'p_participation_id': participationId,
        'p_app_name': appName,
      },
    );
    if (response.error != null) {
      debugPrint('markTesterRegistered 에러: ${response.error!.message}');
      return false;
    }
    return true;
  }
}
