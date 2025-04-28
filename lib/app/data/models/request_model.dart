class RequestModel {
  final String id;
  final String targetAppId;
  final String description;
  final String ownerId;
  final String displayName;
  final String status;
  final String requestType;
  final int currentParticipants;
  final DateTime createdAt;
  final String appName;
  final String packageName;
  final String appState;
  final String? cafeUrl;
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
    required this.appName,
    required this.packageName,
    required this.appState,
    required this.cafeUrl,
    required this.trustScore,
  });

  Map<String, dynamic> toMap() => {
    'target_app_id': targetAppId,
    'description': description,
    'owner_id': ownerId,
    'status': status,
    'request_type': requestType,
    'current_participants': currentParticipants,
    'created_at': createdAt.toIso8601String(),
  };
}