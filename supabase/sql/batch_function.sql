-- ✅ [배치 전용] 테스트 시작 후 12일 경과한 참여 완료 처리 및 알림
CREATE OR REPLACE FUNCTION complete_test_request_batch()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  req RECORD;
  part RECORD;
BEGIN
  -- 1) 대상 요청 조회 (모두)
  FOR req IN
    SELECT id AS request_id, app_name, owner_id
    FROM request_with_owner
    WHERE request_type = 'test'
      AND test_started_at < NOW() - INTERVAL '12 days'
      AND status = 'test'
  LOOP
    -- 2) 참여자 처리(완료, 점수, 로그, 알림)
    FOR part IN
      SELECT id AS participation_id, user_id, target_request_id
      FROM participations
      WHERE request_id = req.request_id
        AND status = 'pending'
        AND NOT EXISTS (
          SELECT 1 FROM trust_score_logs
          WHERE participation_id = participations.id
            AND reason = 'test_complete_after_12_days'
        )
    LOOP
      UPDATE participations
      SET status = 'completed', completed_at = NOW()
      WHERE id = part.participation_id;

      UPDATE users
      SET trust_score = trust_score + CASE WHEN part.target_request_id IS NULL THEN 2 ELSE 1 END
      WHERE id = part.user_id;

      INSERT INTO trust_score_logs(user_id, participation_id, delta, reason)
      VALUES(
        part.user_id, part.participation_id,
        CASE WHEN part.target_request_id IS NULL THEN 2 ELSE 1 END,
        'test_complete_after_12_days'
      );

      INSERT INTO public.notifications(
        user_id, title, body, scheduled_for, action, payload, sent
      ) VALUES (
        part.user_id,
        '테스트 완료',
        format('%s 앱의 테스트가 완료되어 신뢰점수가 반영되었습니다.', req.app_name),
        NOW(),
        'testCompletedReward',
        json_build_object(
          'requestId', req.request_id,
          'participationId', part.participation_id,
          'appName', req.app_name,
          'scoreGain', CASE WHEN part.target_request_id IS NULL THEN 2 ELSE 1 END
        ),
        TRUE
      );
    END LOOP;

    -- 3) 요청 닫기 및 요청자 알림
    UPDATE requests SET status = 'closed' WHERE id = req.request_id;

    INSERT INTO public.notifications(
      user_id, title, body, scheduled_for, action, payload, sent
    ) VALUES (
      req.owner_id,
      '테스트 완료',
      format('%s 앱의 테스트가 완료되었습니다.', req.app_name),
      NOW(),
      'testCompleted',
      json_build_object('requestId', req.request_id, 'appName', req.app_name),
      TRUE
    );
  END LOOP;
END;
$$;

-- ✅ [배치 전용] 테스트 요청 자동 시작 처리 및 알림
CREATE OR REPLACE FUNCTION start_test_request_batch()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  p RECORD;
  q RECORD;
BEGIN
  FOR p IN
    SELECT id AS request_id, owner_id, app_name
    FROM request_with_owner
    WHERE request_type = 'test'
      AND status = 'open'
      AND current_participants >= 12
  LOOP
    -- 요청 상태 변경
    UPDATE requests
    SET test_started_at = NOW(), status = 'test'
    WHERE id = p.request_id;

    -- 테스터 등록 표시
    UPDATE participations
    SET tester_registered = TRUE
    WHERE request_id = p.request_id;

    -- 설치 지연 경고 알림
    FOR q IN
      SELECT id AS participation_id, user_id
      FROM participations
      WHERE request_id = p.request_id
        AND (last_install_check IS NULL OR last_install_check < NOW() - INTERVAL '1 day')
    LOOP
      INSERT INTO public.notifications(
        user_id, title, body, scheduled_for, action, payload, sent
      ) VALUES (
        q.user_id,
        '앱 설치 지연 경고',
        format('%s 앱 테스트가 시작되었습니다. 설치를 완료해 주세요.', p.app_name),
        NOW(),
        'warnUncheckedInstall',
        json_build_object(
          'requestId', p.request_id,
          'participationId', q.participation_id,
          'appName', p.app_name
        ),
        FALSE
      );
    END LOOP;

    -- 요청자 테스트 시작 알림
    INSERT INTO public.notifications(
      user_id, title, body, scheduled_for, action, payload, sent
    ) VALUES (
      p.owner_id,
      '테스트 시작',
      format('%s 앱의 테스트가 시작되었습니다.', p.app_name),
      NOW(),
      'testStarted',
      json_build_object('requestId', p.request_id, 'appName', p.app_name),
      FALSE
    );
  END LOOP;
END;
$$;

-- ✅ [배치 함수] 1일 미설치 경과 시 경고 알림
CREATE OR REPLACE FUNCTION warn_unchecked_install_after_1_day()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  part RECORD;
BEGIN
  FOR part IN
    SELECT p.id AS participation_id,
           p.user_id AS participant_id,
           rwo.owner_id AS requester_id,
           rwo.app_name,
           rwo.id   AS request_id
    FROM request_with_owner rwo
    JOIN participations p ON rwo.id = p.request_id
    WHERE rwo.request_type = 'test'
      AND p.status = 'pending'
      AND p.created_at < NOW() - INTERVAL '1 day'
      AND NOT EXISTS (
        SELECT 1 FROM notifications n
        WHERE n.payload->>'participation_id' = p.id::text
          AND n.action = 'warnUncheckedInstall'
      )
  LOOP
    INSERT INTO public.notifications(user_id, title, body, scheduled_for, action, payload)
    VALUES (
      part.participant_id,
      '앱 설치 미확인 경고',
      format('%s 앱이 아직 설치되지 않았습니다. 설치를 완료해주세요.', part.app_name),
      NOW(),
      'warnUncheckedInstall',
      json_build_object(
        'requestId', part.request_id,
        'participationId', part.participation_id,
        'appName', part.app_name
      )
    );
  END LOOP;
END;
$$;

-- ✅ [배치 함수] 3일 미설치 시 실패 처리 및 패널티, 알림
CREATE OR REPLACE FUNCTION fail_unchecked_install_after_3_days()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  part RECORD;
BEGIN
  FOR part IN
    SELECT p.id AS participation_id,
           p.user_id AS participant_id,
           rwo.owner_id AS requester_id,
           rwo.app_name,
           rwo.id   AS request_id
    FROM request_with_owner rwo
    JOIN participations p ON rwo.id = p.request_id
    WHERE rwo.request_type = 'test'
      AND p.status = 'pending'
      AND p.created_at < NOW() - INTERVAL '3 days'
      AND NOT EXISTS (
        SELECT 1 FROM trust_score_logs
        WHERE participation_id = p.id AND reason = 'fail_unchecked_install_3_days'
      )
  LOOP
    -- 실패 상태 변경
    UPDATE participations
    SET status = 'failed', completed_at = NOW()
    WHERE id = part.participation_id;

    -- 신뢰점수 감점
    UPDATE users
    SET trust_score = trust_score - 1
    WHERE id = part.participant_id;

    -- 로그 기록
    INSERT INTO trust_score_logs(user_id, participation_id, delta, reason)
    VALUES(part.participant_id, part.participation_id, -1, 'fail_unchecked_install_3_days');

    -- 알림 삽입
    INSERT INTO public.notifications(user_id, title, body, scheduled_for, action, payload, sent)
    VALUES (
      part.participant_id,
      '테스트 실패 처리',
      format('%s 앱 테스트가 설치되지 않아 실패 처리되었습니다.', part.app_name),
      NOW(),
      'testFailed',
      json_build_object(
        'requestId', part.request_id,
        'participationId', part.participation_id,
        'appName', part.app_name,
        'penalty', -1
      ),
      TRUE
    );
  END LOOP;
END;
$$;

-- ✅ [배치 함수] 테스트 시작 후 30일 경과시 참여자에게 신뢰점수 강제 부여 및 상태 변경
CREATE OR REPLACE FUNCTION complete_test_participations_after_30_days()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE part RECORD;
BEGIN

  -- 보상 및 벌점: 테스트 미시작 30일 경과 시
  FOR part IN
    SELECT p.id AS participation_id,
           p.user_id AS participant_id,
           rwo.owner_id AS requester_id,
           rwo.app_name,
           rwo.id   AS request_id
    FROM request_with_owner rwo
    JOIN participations p ON rwo.id = p.request_id
    WHERE rwo.request_type = 'test'
      AND rwo.created_at < NOW() - INTERVAL '30 days'
      AND p.status <> 'failed'
  LOOP
    -- 참여자 보상
    UPDATE users
    SET trust_score = trust_score +
      CASE WHEN part.target_request_id IS NULL THEN 2 ELSE 1 END
    WHERE id = part.participation_id;

    -- 요청자 벌점
    UPDATE users
    SET trust_score = trust_score - 1
    WHERE id = part.requester_id;

    -- 로그 기록
    INSERT INTO trust_score_logs(user_id, participation_id, delta, reason)
    VALUES
      (part.participant_id, part.participation_id,
        CASE WHEN part.target_request_id IS NULL THEN 2 ELSE 1 END,
        'unstarted_test_after_30_days'),
      (part.requester_id, part.participation_id, -1, 'unstarted_test_after_30_days');

    -- 요청 상태 닫기
    UPDATE requests
    SET status = 'closed'
    WHERE id = part.request_id;

    -- 참여 상태 completed 처리
    UPDATE participations
    SET status = 'completed', completed_at = NOW()
    WHERE id = part.participation_id;

    -- 알림: 참여자 보상
    INSERT INTO public.notifications(
      user_id, title, body, scheduled_for, action, payload, sent
    ) VALUES (
      part.participant_id,
      '테스트 미시작 보상',
      format('%s 앱의 테스트가 30일간 시작되지 않아 보상이 지급되었습니다.', part.app_name),
      NOW(),
      'unstartedTestReward',
      json_build_object(
        'requestId', part.request_id,
        'participationId', part.participation_id,
        'appName', part.app_name
      ),
      TRUE
    );

    -- 알림: 요청자 패널티
    INSERT INTO public.notifications(
      user_id, title, body, scheduled_for, action, payload, sent
    ) VALUES (
      part.requester_id,
      '테스트 미시작 패널티',
      format('%s 앱 테스트 요청이 30일간 시작되지 않아 패널티가 부과되었습니다.', part.app_name),
      NOW(),
      'unstartedTestPenalty',
      json_build_object(
        'requestId', part.request_id,
        'appName', part.app_name
      ),
      TRUE
    );
  END LOOP;
END;
$$;


CREATE OR REPLACE FUNCTION penalize_requester_for_inaction()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  part RECORD;
BEGIN
  FOR part IN
    SELECT p.id AS participation_id,
           p.user_id AS participant_id,
           rwo.owner_id AS requester_id,
           p.requested_at,
           rwo.id AS request_id,
           p.target_request_id,
           p.is_pairing,
           rwo.request_type
    FROM request_with_owner rwo
    JOIN participations p ON rwo.id = p.request_id
    WHERE p.status = 'pending'
      AND p.requested_at < NOW() - INTERVAL '7 days'
      AND p.requester_failed = FALSE
      AND (
        (p.target_request_id IS NOT NULL AND p.is_pairing = FALSE)
        OR rwo.request_type = 'review'
      )
  LOOP
    -- 요청자 신뢰점수 패널티
    UPDATE users SET trust_score = trust_score - 1 WHERE id = part.requester_id;

    -- 로그 기록
    INSERT INTO trust_score_logs (user_id, participation_id, delta, reason)
    VALUES (part.requester_id, part.participation_id, -1, 'requester_no_action_7d');

    -- 요청 실패 처리 표시
    UPDATE participations
    SET requester_failed = TRUE
    WHERE id = part.participation_id;

    -- 알림: 요청자 패널티 안내
    INSERT INTO public.notifications(
      user_id, title, body, scheduled_for, action, payload, sent
    ) VALUES (
      part.requester_id,
      '응답 미진행 패널티',
      format(
        '요청(%s)이 7일 내에 처리되지 않아 패널티가 부과되었습니다.', part.request_id
      ),
      NOW(),
      'pairingInactiveFailed',
      json_build_object(
        'requestId', part.request_id,
        'participationId', part.participation_id,
        'targetRequestId', part.target_request_id,
        'participantName', (SELECT display_name FROM users WHERE id = part.user_id)
      ),
      TRUE
    );
  END LOOP;
END;
$$;
