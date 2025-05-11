class RequestModel {
  final String id;
  final String targetAppId;
  String description;
  final String ownerId;
  final String displayName;
  String status;
  final String requestType;
  final int currentParticipants;
  final DateTime createdAt;
  final DateTime updatedAt;
  DateTime? testStartedAt;
  final String appName;
  final String packageName;
  final String appState;
  String? descUrl;
  final int trustScore;

  RequestModel({
    required this.id,
    required this.targetAppId,
    required this.description,
    required this.ownerId,
    required this.displayName,
    required this.status,
    required this.requestType,
    required this.currentParticipants,
    required this.createdAt,
    required this.updatedAt,
    this.testStartedAt,
    required this.appName,
    required this.packageName,
    required this.appState,
    this.descUrl,
    required this.trustScore,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'target_app_id': targetAppId,
      'description': description,
      'owner_id': ownerId,
      'status': status,
      'request_type': requestType,
      'current_participants': currentParticipants,
      'created_at': createdAt.toIso8601String(),
      'updated_at': createdAt.toIso8601String(),
      // 선택 설명 URL
      'desc_url': descUrl,
    };
    return map;
  }
}