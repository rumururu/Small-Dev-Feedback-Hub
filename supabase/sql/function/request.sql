-- ✅ 테스트 재시작 처리
-- 파라미터: request_id(UUID)
-- request_type = 'test'인 요청에 대해 status를 'test'로, test_started_at을 NOW()로 갱신
CREATE OR REPLACE FUNCTION restart_test_request(request_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  part RECORD;
  v_app_name TEXT;
BEGIN

  -- 이미 open/closed 상태이거나 최근 10일 내에 시작된 테스트면 종료
  IF EXISTS (
    SELECT 1 FROM requests
    WHERE id = request_id
      AND request_type = 'test'
      AND (
        status IN ('open', 'closed')
        OR (test_started_at IS NOT NULL AND test_started_at > NOW() - INTERVAL '10 days')
      )
  ) THEN
    RETURN FALSE;
  END IF;

  SELECT app_name
    INTO v_app_name
    FROM request_with_owner_and_participation
   WHERE id = request_id;

  -- 1) Reset the test start timestamp
  UPDATE requests
  SET test_started_at = NOW()
  WHERE id = restart_test_request.request_id
    AND request_type = 'test';

  -- 2) Reward participants: +2 if no target_request_id, else +1
  UPDATE users u
  SET trust_score = trust_score + CASE WHEN p.target_request_id IS NULL THEN 2 ELSE 1 END
  FROM participations p
  WHERE p.request_id = restart_test_request.request_id
    AND u.id = p.user_id;

  -- 3) Log trust score changes with correct delta
  INSERT INTO trust_score_logs (user_id, participation_id, delta, reason)
  SELECT p.user_id, p.id,
         CASE WHEN p.target_request_id IS NULL THEN 2 ELSE 1 END,
         'manual_restart_test'
  FROM participations p
  WHERE p.request_id = restart_test_request.request_id;

    -- 알림: 테스트 재시작 알림
    FOR part IN
      SELECT id AS participation_id, user_id, target_request_id
      FROM participations
      WHERE request_id = request_id
    LOOP
      -- 참여자 알림
      INSERT INTO public.notifications(
        user_id, title, body, scheduled_for, action, payload, sent
      ) VALUES (
        part.user_id,
        '테스트 재시작',
        format('%s 앱의 테스트가 재시작되었습니다. 기존 테스트 보상으로 신뢰점수 %s 점을 획득했습니다.', v_app_name, CASE WHEN part.target_request_id IS NULL THEN 2 ELSE 1 END),
        NOW(),
        'testRestartedReward',
        json_build_object(
          'requestId', request_id,
          'participationId', part.participation_id,
          'appName', v_app_name,
          'scoreGain', CASE WHEN part.target_request_id IS NULL THEN 2 ELSE 1 END
        ),
        TRUE
      );
    END LOOP;

    -- 요청자 알림
    INSERT INTO public.notifications(
      user_id, title, body, scheduled_for, action, payload, sent
    ) VALUES (
      (SELECT owner_id FROM requests WHERE id = request_id),
      '테스트 재시작 알림',
      format('%s 앱의 테스트가 재시작되었습니다.', v_app_name),
      NOW(),
      'testRestarted',
        json_build_object(
          'requestId', request_id,
          'appName', v_app_name
        ),
      FALSE
    );

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION restart_test_request(UUID) TO authenticated;

-- ✅ [트리거 함수] 참여 생성 시 요청의 참가자 수를 1 증가시킴
CREATE FUNCTION inc_request_count() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE requests
    SET current_participants = current_participants + 1
    WHERE id = NEW.request_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_inc_count
  AFTER INSERT ON participations
  FOR EACH ROW EXECUTE FUNCTION inc_request_count();

-- ✅ [트리거 함수] 참여 삭제 시 요청의 참가자 수를 1 감소시킴
CREATE FUNCTION dec_request_count() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE requests
    SET current_participants = current_participants - 1
    WHERE id = OLD.request_id;
  RETURN OLD;
END; $$;

CREATE TRIGGER trg_dec_count
  AFTER DELETE ON participations
  FOR EACH ROW EXECUTE FUNCTION dec_request_count();



CREATE OR REPLACE FUNCTION complete_test_request(p_request_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  part RECORD;
  v_app_name TEXT;
BEGIN
  -- 1) 유효한 요청 확인
  IF NOT EXISTS (
    SELECT 1 FROM requests
    WHERE id = p_request_id
      AND request_type = 'test'
      AND status = 'test'
  ) THEN
    RETURN FALSE;
  END IF;

  -- 2) 앱 이름 조회
  SELECT app_name
    INTO v_app_name
    FROM request_with_owner_and_participation
   WHERE id = p_request_id;

  -- 3) 요청 닫기
  UPDATE requests
  SET status = 'closed'
  WHERE id = p_request_id;

  -- 4) 참여 완료 처리
  UPDATE participations
  SET status = 'completed',
      completed_at = NOW()
  WHERE request_id = p_request_id
    AND status = 'pending';

  -- 5) 참여자 보상, 로그, 알림
  FOR part IN
    SELECT id AS participation_id, user_id, target_request_id
      FROM participations
     WHERE request_id = p_request_id
       AND status = 'completed'
  LOOP
    -- (a) 신뢰점수 조정
    UPDATE users
    SET trust_score = trust_score +
      CASE WHEN part.target_request_id IS NULL THEN 2 ELSE 1 END
    WHERE id = part.user_id;

    -- (b) 로그
    INSERT INTO trust_score_logs(user_id, participation_id, delta, reason)
    VALUES (
      part.user_id,
      part.participation_id,
      CASE WHEN part.target_request_id IS NULL THEN 2 ELSE 1 END,
      'manual_finish_test'
    );

    -- (c) 참여자 알림
    INSERT INTO public.notifications(
      user_id, title, body, scheduled_for, action, payload, sent
    ) VALUES (
      part.user_id,
      '테스트 완료',
      format('%s 앱의 테스트가 완료되어 신뢰점수 %s점을 획득했습니다.',
             v_app_name,
             CASE WHEN part.target_request_id IS NULL THEN 2 ELSE 1 END),
      NOW(),
      'testCompletedReward',
      json_build_object(
        'requestId', p_request_id,
        'participationId', part.participation_id,
        'appName', v_app_name,
        'scoreGain', CASE WHEN part.target_request_id IS NULL THEN 2 ELSE 1 END
      ),
      TRUE
    );
  END LOOP;

  -- 6) 요청자 알림
  INSERT INTO public.notifications(
    user_id, title, body, scheduled_for, action, payload, sent
  ) VALUES (
    (SELECT owner_id FROM requests WHERE id = p_request_id),
    format('%s 앱의 테스트가 완료되었습니다.', v_app_name),
    format('%s 앱의 테스트가 완료되었습니다.', v_app_name),
    NOW(),
    'testCompleted',
    json_build_object(
      'requestId', p_request_id,
      'appName', v_app_name
    ),
    FALSE
  );

  -- 성공적으로 처리되었으므로 TRUE 반환
  RETURN TRUE;

EXCEPTION
  WHEN OTHERS THEN
    -- 오류 발생 시 FALSE 반환
    RETURN FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION complete_test_request(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION start_test_request(p_request_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  part RECORD;
  v_app_name TEXT;
BEGIN
  -- 0) 유효한 테스트 요청인지 확인
  IF NOT EXISTS (
    SELECT 1
      FROM requests
     WHERE id = p_request_id
       AND request_type = 'test'
       AND status = 'open'
  ) THEN
    RETURN FALSE;
  END IF;

  -- 1) 앱 이름 조회
  SELECT app_name
    INTO v_app_name
    FROM request_with_owner_and_participation
   WHERE id = p_request_id;

  -- 2) 테스트 시작 처리
  UPDATE requests
     SET test_started_at = NOW(),
         status = 'test'
   WHERE id = p_request_id;

  -- 3) tester_registered 표시
  UPDATE participations
     SET tester_registered = TRUE
   WHERE request_id = p_request_id;

  -- 4) 설치 지연 경고 알림 발송
  FOR part IN
    SELECT id AS participation_id, user_id
      FROM participations
     WHERE request_id = p_request_id
       AND (
         last_install_check IS NULL
         OR last_install_check < NOW() - INTERVAL '1 day'
       )
  LOOP
    INSERT INTO public.notifications(
      user_id, title, body, scheduled_for, action, payload, sent
    ) VALUES (
      part.user_id,
      '앱 설치 지연 경고',
      format('%s 앱 테스트가 시작되었습니다. 설치 확인을 완료해 주세요.', v_app_name),
      NOW(),
      'warnUncheckedInstall',
      json_build_object(
        'requestId',          p_request_id,
        'participationId',    part.participation_id,
        'appName',            v_app_name
      ),
      TRUE
    );
  END LOOP;

  -- 5) 요청자에게 테스트 시작 알림
  INSERT INTO public.notifications(
    user_id, title, body, scheduled_for, action, payload, sent
  ) VALUES (
    (SELECT owner_id FROM requests WHERE id = p_request_id),
    '테스트 시작',
    format('%s 앱의 테스트가 시작되었습니다.', v_app_name),
    NOW(),
    'testStarted',
    json_build_object(
      'requestId', p_request_id,
      'appName',   v_app_name
    ),
    TRUE
  );

  -- 6) 참여자에게 테스트 시작 알림
  FOR part IN
    SELECT id AS participation_id, user_id
      FROM participations
     WHERE request_id = p_request_id
  LOOP
    INSERT INTO public.notifications(
      user_id, title, body, scheduled_for, action, payload, sent
    ) VALUES (
      part.user_id,
      '테스트 시작 안내',
      format('%s 앱의 테스트가 시작되었습니다.', v_app_name),
      NOW(),
      'testStarted',
      json_build_object(
        'requestId',       p_request_id,
        'participationId', part.participation_id,
        'appName',         v_app_name
      ),
      TRUE
    );
  END LOOP;

  RETURN TRUE;

EXCEPTION
  WHEN OTHERS THEN
    -- 오류 발생 시 FALSE 리턴
    RETURN FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION start_test_request(UUID) TO authenticated;
