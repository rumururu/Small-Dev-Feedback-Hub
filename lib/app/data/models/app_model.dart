/// Supabase 'user_apps' 테이블 모델
class AppModel {
  final String id;
  final String appName;       // app_name 컬럼 (추가)
  final String packageName;   // package_name 컬럼
  final String appState;      // app_state 컬럼
  final DateTime createdAt;   // created_at 컬럼
  final String? iconUrl;      // icon_url 컬럼 (optional)

  AppModel({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.appState,
    required this.createdAt,
    this.iconUrl,
  });

  factory AppModel.fromMap(Map<String, dynamic> m) => AppModel(
    id: m['id'] as String,
    appName: m['app_name'] as String,
    packageName: m['package_name'] as String,
    appState: m['app_state'] as String,
    createdAt: DateTime.parse(m['created_at'] as String),
    iconUrl: m['icon_url'] as String?,
  );

  /// 기존 값을 유지한 채 필요한 필드만 변경한 새 인스턴스를 반환
  AppModel copyWith({
    String? id,
    String? appName,
    String? packageName,
    String? appState,
    DateTime? createdAt,
    String? iconUrl,
  }) {
    return AppModel(
      id: id ?? this.id,
      appName: appName ?? this.appName,
      packageName: packageName ?? this.packageName,
      appState: appState ?? this.appState,
      createdAt: createdAt ?? this.createdAt,
      iconUrl: iconUrl ?? this.iconUrl,
    );
  }

  Map<String, dynamic> toMap() => {
    'app_name': appName,
    'package_name': packageName,
    'app_state': appState,
    if (iconUrl != null) 'icon_url': iconUrl,
  };
}