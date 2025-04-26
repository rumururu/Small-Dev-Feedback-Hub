/// Supabase 'participations' 테이블 모델
class ParticipationModel {
  final String id;
  final String requestId;
  final String userId;
  final String status;      // 'assigned','pending','completed','failed'
  final String? proofUrl;
  final DateTime requestedAt;
  final DateTime? completedAt;

  ParticipationModel({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.status,
    this.proofUrl,
    required this.requestedAt,
    this.completedAt,
  });

  factory ParticipationModel.fromMap(Map<String, dynamic> m) =>
      ParticipationModel(
        id: m['id'] as String,
        requestId: m['request_id'] as String,
        userId: m['user_id'] as String,
        status: m['status'] as String,
        proofUrl: m['proof_url'] as String?,
        requestedAt: DateTime.parse(m['requested_at'] as String),
        completedAt: m['completed_at'] != null
            ? DateTime.parse(m['completed_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
    'request_id': requestId,
    'user_id': userId,
    'status': status,
    'proof_url': proofUrl,
    'requested_at': requestedAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };
}