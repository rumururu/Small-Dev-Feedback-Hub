/// Supabase 'user_apps' 테이블 모델
class AppModel {
  final String id;
  final String appName;       // app_name 컬럼 (추가)
  final String packageName;   // package_name 컬럼
  final String appState;      // app_state 컬럼
  final String? cafeUrl;      // cafe_url 컬럼
  final DateTime createdAt;   // created_at 컬럼

  AppModel({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.appState,
    this.cafeUrl,
    required this.createdAt,
  });

  factory AppModel.fromMap(Map<String, dynamic> m) => AppModel(
    id: m['id'] as String,
    appName: m['app_name'] as String,
    packageName: m['package_name'] as String,
    appState: m['app_state'] as String,
    cafeUrl: m['cafe_url'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  Map<String, dynamic> toMap() => {
    'app_name': appName,
    'package_name': packageName,
    'app_state': appState,
    'cafe_url': cafeUrl,
  };
}