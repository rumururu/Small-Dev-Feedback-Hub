

/// 알림 타입 정의
enum NotificationType {
  participationRequest,    // 테스터/리뷰 품앗이 참여신청 알림: 요청자에게 참여 신청 알림 발송
  testerRegistered,        // 테스터등록 알림: 참여자에게 테스터 등록 완료 알림 발송
  warnUncheckedInstall,    // 설치지연 경고: 1일 이상 설치 미확인 시 참여자에게 경고 알림 발송
  testStarted,             // 테스트시작 알림: 테스트 시작 시 요청자에게 알림 발송
  testRestarted,           // 테스트 재시작 알림: 테스트가 재시작되었음을 알림
  testRestartedReward,     // 테스트 재시작 알림: 재시작 및 보상 알림
  testFailed,              // 테스트실패 알림: 3일 이상 설치 미이행 시 실패 및 패널티 알림
  testCompleted,           // 테스트완료 알림: 테스트 성공 알림 발송
  testCompletedReward,      // 테스트완료 알림: 테스트 성공 시 점수 알림 발송
  unstartedTestReward,     // 미시작보상 알림: 테스트 미시작 30일 경과 시 참여자 보상 알림 발송
  unstartedTestPenalty,    // 미시작패널티 알림: 테스트 미시작 30일 경과 시 요청자 패널티 알림 발송
  reviewCompleted,         // 리뷰완료 알림: 참여자에게 완료 및 점수 획득 알림 발송
  pairingInactiveFailed,   // 맞품앗이실패 알림: 7일 내 매칭 미성사 시 요청자 패널티 알림 발송
  reportedUserPenalized,   // 신고 패널티 알림: 신고된 사용자에게 패널티 알림 발송
}

/// 알림 템플릿 클래스
class NotificationTemplate {
  /// 푸시 알림의 타이틀
  final String title;

  /// 바디 메시지를 동적으로 생성하는 함수
  /// params 맵에 필요한 값을 넘겨주세요.
  final String Function(Map<String, String> params) bodyBuilder;

  const NotificationTemplate({
    required this.title,
    required this.bodyBuilder,
  });
}

/// 타입별 템플릿 매핑
Map<NotificationType, NotificationTemplate> notificationTemplates = {
  NotificationType.participationRequest: NotificationTemplate(
    title: '참여 신청 알림',
    bodyBuilder: (p) =>
      '사용자 ${p["participantName"]}님이 ${p["appName"]}의 품앗이 요청에 참여 신청했습니다.',
  ),
  NotificationType.testerRegistered: NotificationTemplate(
    title: '테스터 등록 완료',
    bodyBuilder: (p) =>
      '요청자 ${p["ownerName"]}님이 ${p["appName"]} 앱의 테스터 등록을 완료했습니다.',
  ),
  NotificationType.reviewCompleted: NotificationTemplate(
    title: '리뷰 완료 알림',
    bodyBuilder: (p) =>
      '${p["appName"]} 앱 리뷰가 완료되어 신뢰 점수 ${p["scoreGain"]}점을 획득했습니다!',
  ),
  NotificationType.warnUncheckedInstall: NotificationTemplate(
    title: '테스트 진행 경고',
    bodyBuilder: (p) =>
      '${p["appName"]} 앱 테스트가 진행중이나 앱 설치가 되지 않았습니다. 빠른 설치 부탁드립니다.',
  ),
  NotificationType.testFailed: NotificationTemplate(
    title: '테스트 실패 알림',
    bodyBuilder: (p) =>
      '${p["appName"]} 테스트 앱의 미설치로 실패 처리되었습니다. 패널티 ${p["penalty"]}점이 부여됩니다.',
  ),
  NotificationType.testCompleted: NotificationTemplate(
    title: '테스트 완료 알림',
    bodyBuilder: (p) =>
      '${p["appName"]} 앱 테스트가 성공적으로 완료되었습니다.',
  ),
  NotificationType.testCompletedReward: NotificationTemplate(
    title: '테스트 완료 알림',
    bodyBuilder: (p) =>
    '${p["appName"]} 앱 테스트가 성공적으로 완료되어 신뢰 점수 ${p["scoreGain"]}점을 획득했습니다!',
  ),
  NotificationType.pairingInactiveFailed: NotificationTemplate(
    title: '맞품앗이 미진행 실패',
    bodyBuilder: (p) =>
      '${p["participantName"]}님의 맞품앗이 요청이 7일 이내에 성사되지 않아 패널티가 부과됩니다.',
  ),
  NotificationType.testStarted: NotificationTemplate(
    title: '테스트 시작',
    bodyBuilder: (p) =>
    '${p["appName"]} 앱 테스트가 시작됬습니다.',
  ),
  NotificationType.testRestarted: NotificationTemplate(
    title: '테스트 재시작',
    bodyBuilder: (p) =>
    '${p["appName"]} 앱 테스트가 재시작되었습니다.',
  ),
  NotificationType.testRestartedReward: NotificationTemplate(
    title: '테스트 재시작 보상',
    bodyBuilder: (p) =>
    '${p["appName"]} 앱 테스트가 재시작되었습니다. 신뢰 점수 ${p["scoreGain"]}점을 획득했습니다!',
  ),
  NotificationType.unstartedTestReward: NotificationTemplate(
    title: '테스트 미시작 보상',
    bodyBuilder: (p) =>
    '${p["appName"]} 앱 테스트가 30일간 시작되지 않아 보상이 지급되었습니다.',
  ),
  NotificationType.unstartedTestPenalty: NotificationTemplate(
    title: '테스트 미시작 패널티',
    bodyBuilder: (p) =>
    '${p["appName"]} 앱 테스트 요청이 30일간 시작되지 않아 패널티가 부과되었습니다.',
  ),
  NotificationType.reportedUserPenalized: NotificationTemplate(
    title: '신고 패널티 부과',
    bodyBuilder: (p) =>
      '신고 처리로 인해 신뢰점수가 감점되었습니다. (참여 ${p["appName"]} )',
  ),
};