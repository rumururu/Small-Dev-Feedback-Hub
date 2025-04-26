// lib/app/data/models/user_model.dart
/// 사용자 정보 모델
class UserModel {
  final String id;
  final String email;
  final String displayName;
  final int trustScore;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.trustScore,
  });

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
    id: m['id'] as String,
    email: m['email'] as String,
    displayName: m['displayName'] as String,
    trustScore: m['trustScore'] as int,
  );
}