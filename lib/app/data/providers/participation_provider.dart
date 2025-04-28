// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/participation_model.dart';

/// Supabase 'participations' 테이블 CRUD
class ParticipationProvider {
  final _client = Supabase.instance.client;

  /// 참여 신청
  Future<void> createParticipation({
    required String requestId,
    String? targetRequestId,
    String? proofUrl,
  }) async {
    final data = {
      'request_id': requestId,
      'user_id': Supabase.instance.client.auth.currentUser!.id,
      if (targetRequestId != null) 'target_request_id': targetRequestId,
      if (proofUrl != null) 'proof_url': proofUrl,
    };

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      await Supabase.instance.client.from('participations').insert(data);
    } finally {
      Get.back();
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

  Future<bool> cancelParticipation({required String requestId}) async {
    final userId = _client.auth.currentUser!.id;
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
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
              .select();

      // 삭제된 데이터 개수로 성공 여부 판단
      return res.isNotEmpty;
    } catch (e) {
      print('참여 취소 실패: $e');
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
          'id, user_id, requested_at, target_request_id, proof_url, users(display_name, trust_score)',
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
            'target_request_id': e['target_request_id'],
            'proof_url': e['proof_url'],
            'requested_at': DateTime.parse(e['requested_at']),
          },
        )
        .toList();
  }

  /// 참여 상태를 'completed'로 변경
  Future<void> updateParticipationStatus(String participationId) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );
    try {
      await _client
          .from('participations')
          .update({'status': 'completed'})
          .eq('id', participationId);
    } finally {
      Get.back();
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
    } finally {
      Get.back();
    }
  }

  /// 현재 사용자 참여 내역 조회 (앱 이름 포함)
  Future<List<Map<String, dynamic>>> getMyParticipations() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return [];
    final userId = currentUser.id;

    final res = await _client
        .from('participations')
        .select('''
  id, request_id, user_id, status, proof_url, requested_at, completed_at, 
  requests!participations_request_id_fkey(
    target_app_id, user_apps(app_name, package_name)
  )
''')
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
      };
    }).toList();
  }
}
