/// Supabase 'requests' 테이블 모델
class RequestModel {
  final String id;
  final String appName;
  final String type;        // 'test' 또는 'review'
  final String description;
  final String ownerId;
  final int currentParticipants;
  final DateTime createdAt;

  RequestModel({
    required this.id,
    required this.appName,
    required this.type,
    required this.description,
    required this.ownerId,
    required this.currentParticipants,
    required this.createdAt,
  });

  /// Supabase에서 Map 형태로 받아 모델로 변환
  factory RequestModel.fromMap(Map<String, dynamic> m) => RequestModel(
    id: m['id'] as String,
    appName: m['app_name'] as String,
    type: m['type'] as String,
    description: m['description'] as String? ?? '',
    ownerId: m['owner_id'] as String,
    currentParticipants: m['current_participants'] as int,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  /// Supabase 삽입용 Map 변환
  Map<String, dynamic> toMap() => {
    'app_name': appName,
    'type': type,
    'description': description,
    'owner_id': ownerId,
    'current_participants': currentParticipants,
    'created_at': createdAt.toIso8601String(),
  };
}