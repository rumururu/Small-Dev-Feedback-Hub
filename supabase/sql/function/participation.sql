-- ✅ 참여 생성 및 삽입된 ID 반환
create or replace function public.create_participation(
  p_owner_id          uuid,
  p_request_id        uuid,
  p_participant_id    uuid,
  p_target_request_id uuid,
  p_proof_url         text,
  p_request_type      text,
  p_participant_name  text,
  p_app_name          text
)
returns uuid
language plpgsql
security definer
as $$
declare
  v_new_id uuid;
begin
  -- 1. participations 삽입 및 새 ID 저장
  insert into public.participations(
    request_id,
    user_id,
    target_request_id,
    proof_url
  ) values (
    p_request_id,
    p_participant_id,
    p_target_request_id,
    p_proof_url
  )
  returning id into v_new_id;

  -- 3. 알림 생성
  insert into public.notifications(
    user_id,
    title,
    body,
    scheduled_for,
    action,
    payload
  ) values (
    p_owner_id,
    '참여 신청 알림',
    format(
      '사용자 %s님이 %s 요청(%s) 앱에 참여 신청했습니다.',
      p_participant_name,
      p_request_type,
      p_app_name
    ),
    now(),
    'participationRequest',
    json_build_object(
      'requestId', p_request_id,
      'participantName', p_participant_name,
      'appName', p_app_name
    )
  );

  -- 4. 새로 생성된 participation의 ID 반환
  return v_new_id;
end;
$$;


-- 권한 부여: 인증된 사용자만 실행 가능
grant execute on function public.create_participation(
  uuid, uuid, uuid, uuid, text, text, text, text
) to authenticated;


create or replace function set_is_pairing()
returns trigger as $$
begin
  -- 맞품앗이 조건: 서로가 서로의 요청에 참여한 상태
  if exists (
    select 1 from participations
    where request_id = NEW.target_request_id
      and target_request_id = NEW.request_id
  ) then
    -- 기존 짝이 성립되어 있으면 양쪽 모두 pairing = true
    NEW.is_pairing := true;

    update participations
    set is_pairing = true
    where request_id = NEW.target_request_id
      and target_request_id = NEW.request_id;

  elsif exists (
    select 1 from participations
    where request_id = NEW.target_request_id
      and target_request_id is null
      and user_id != NEW.user_id
  ) then
    -- 상대가 먼저 참여했는데 target_request_id가 비어있는 경우
    -- 해당 participation의 target_request_id 업데이트 및 양쪽 pairing = true
    update participations
    set target_request_id = NEW.request_id,
        is_pairing = true
    where request_id = NEW.target_request_id
      and target_request_id is null
      and user_id != NEW.user_id;

    NEW.is_pairing := true;

  else
    -- 짝이 없으면 pairing = false
    NEW.is_pairing := false;
  end if;

  return NEW;
end;
$$ language plpgsql;


create trigger trg_set_is_pairing
before insert on participations
for each row
execute function set_is_pairing();

create or replace function update_pairing_on_delete()
returns trigger as $$
begin
  update participations
  set is_pairing = false
  where request_id = OLD.target_request_id
    and target_request_id = OLD.request_id;
  return OLD;
end;
$$ language plpgsql;

create trigger trg_update_pairing_on_delete
before delete on participations
for each row
execute function update_pairing_on_delete();


-- ✅ [트리거 함수] 신고가 처리되었을 때, 신고된 사용자에게 패널티 (-5점) 부여
CREATE or replace FUNCTION penalize_reported_user() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  reported_user UUID;
BEGIN
  -- 신고가 해결 상태로 변경될 때 실행
  IF NEW.resolved = true AND OLD.resolved = false THEN
    -- 신고된 참여자의 user_id 조회
    SELECT user_id INTO reported_user
    FROM participations
    WHERE id = NEW.participation_id;

    -- 신고된 사용자 신뢰점수 5점 감소
    UPDATE users
    SET trust_score = trust_score - 5
    WHERE id = reported_user;

    -- 신뢰점수 로그 기록
    INSERT INTO trust_score_logs (user_id, participation_id, delta, reason)
    VALUES (reported_user, NEW.participation_id, -5, 'penalize_reported_user');

    -- 알림: 신고 패널티 안내
    INSERT INTO public.notifications(
      user_id, title, body, scheduled_for, action, payload, sent
    ) VALUES (
      reported_user,
      '신고 패널티 부과',
      format('신고 처리로 인해 신뢰점수 %s 점이 감점되었습니다.', 5),
      NOW(),
      'reportedUserPenalized',
      json_build_object('participationId', NEW.participation_id),
      TRUE
    );
  END IF;

  RETURN NEW;
END;
$$;

-- ✅ [트리거 함수] 신고가 처리되었을 때, 신고된 사용자에게 패널티 (-5점) 부여
CREATE TRIGGER trg_penalize_reported_user
AFTER UPDATE ON reports
FOR EACH ROW
EXECUTE FUNCTION penalize_reported_user();

-- ✅ [RPC] "테스터 등록 안내 메일 발송" (ID 반환)
create or replace function public.mark_tester_registered(
  p_participation_id uuid,
  p_app_name        text
)
returns uuid                    -- void → uuid로 변경
language plpgsql
security definer
as $$
DECLARE
  v_request_id uuid;
  v_owner_id   uuid;
BEGIN
  -- 1) participation 정보 조회
  SELECT request_id, user_id
    INTO v_request_id, v_owner_id
    FROM public.participations
   WHERE id = p_participation_id;

  -- 2) 참여자 등록 상태 업데이트
  UPDATE public.participations
     SET tester_registered = true
   WHERE id = p_participation_id;

  -- 3) 알림 생성
  INSERT INTO public.notifications(
    user_id,
    title,
    body,
    scheduled_for,
    action,
    payload
  ) VALUES (
    v_owner_id,
    '테스터 등록 완료',
    format(
      '%s 앱의 테스터로 등록되었습니다. 링크를 클릭하여 앱을 설치하세요.',
      p_app_name
    ),
    now(),
    'testerRegistered',
    json_build_object(
      'requestId', v_request_id,
      'ownerName', (SELECT display_name FROM users WHERE id = v_owner_id),
      'appName', p_app_name
    )
  );

  -- 4) 참여 ID 반환
  RETURN p_participation_id;
END;
$$;

-- 권한 부여
grant execute on function public.mark_tester_registered(uuid, text) to authenticated;


-- ✅ [RPC] 리뷰 완료 처리
-- request_type = 'review'인 요청에 대해 status를 'closed'로 갱신
create or replace function finish_review_participation(participation_id uuid, p_app_name text)
returns void SECURITY DEFINER as $$
declare
  p_user_id uuid;
  target_id uuid;
begin
  -- 참여 상태 완료로 변경
  UPDATE participations p
  SET status = 'completed', completed_at = now()
  FROM requests r
  WHERE p.id = participation_id
    AND r.id = p.request_id
    AND r.request_type = 'review'
    AND p.status = 'pending';

  -- user_id 및 target_request_id 조회
  select user_id, target_request_id into p_user_id, target_id
  from participations
  where id = participation_id;

  -- 신뢰점수 증가
  update users
  set trust_score = trust_score + case when target_id is null then 2 else 1 end
  where id = p_user_id;

  INSERT INTO public.notifications(
      user_id,
      title,
      body,
      scheduled_for,
      action,
      payload,
      sent
    ) VALUES (
      p_user_id,
      '리뷰 참여 완료',
      format(
        '%s 앱의 리뷰가 완료됬습니다. 신뢰점수 1점을 획득합니다.',
        p_app_name
      ),
      now(),
      'reviewCompleted',
      json_build_object(
        'requestId', target_id,
        'appName', p_app_name,
        'scoreGain', 1
      ),
      true
    );

  -- 로그 기록
  insert into trust_score_logs (user_id, participation_id, delta, reason)
  values (
    p_user_id,
    participation_id,
    case when target_id is null then 2 else 1 end,
    'review_complete'
  );
end;
$$ language plpgsql;

GRANT EXECUTE ON FUNCTION finish_review_participation(UUID, text) TO authenticated;