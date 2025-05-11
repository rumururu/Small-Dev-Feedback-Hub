


-- ✅ 아직 전송되지 않은 알림 목록 조회 RPC
create or replace function public.get_unsent_notifications()
returns table(
  noti_id        uuid,
  user_id        uuid,
  title          text,
  body           text,
  scheduled_for  timestamptz,
  action         text,
  payload        jsonb
)
language sql
stable
as $$
  select
    id    as noti_id,
    user_id,
    title,
    body,
    scheduled_for,
    action,
    payload
  from public.notifications
  where sent = false
  order by scheduled_for asc
$$;

-- 권한 부여: 인증된 사용자만 실행 가능
grant execute on function public.get_unsent_notifications() to authenticated;