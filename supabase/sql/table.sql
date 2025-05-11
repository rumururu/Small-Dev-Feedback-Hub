-- 0) ENUM 타입 정의
CREATE TYPE app_state AS ENUM ('closed_test', 'published');
CREATE TYPE platform_type AS ENUM ('android', 'ios', 'both');
CREATE TYPE participation_status AS ENUM ('pending', 'completed', 'reported', 'failed');
CREATE TYPE request_status AS ENUM ('open', 'test', 'closed'); -- open, test, closed
CREATE TYPE request_type AS ENUM ('test', 'review');

-- 1) users 테이블
CREATE TABLE users (
  id           UUID          PRIMARY KEY DEFAULT auth.uid(),
  email        TEXT          NOT NULL UNIQUE,
  display_name TEXT          NOT NULL,
  trust_score  INT           NOT NULL DEFAULT 0,
  platform     platform_type NOT NULL DEFAULT 'android',
  fcm_tokens   TEXT[],
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE user_apps (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id      UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  app_name      TEXT          NOT NULL,
  package_name  TEXT          NOT NULL,
  app_state     app_state     NOT NULL,
  icon_url      TEXT,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
  -- Prevent deletion if related requests or participations exist
  -- (enforced by ON DELETE RESTRICT on referencing tables below)
);

CREATE TABLE requests (
  id                   UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  target_app_id        UUID            NOT NULL REFERENCES user_apps(id) ON DELETE RESTRICT,
  description          TEXT,
  desc_url             TEXT,
  owner_id             UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  status               request_status  NOT NULL DEFAULT 'open',
  request_type         request_type    NOT NULL DEFAULT 'test',
  current_participants INT             NOT NULL DEFAULT 0,
  created_at           TIMESTAMPTZ     NOT NULL DEFAULT now(),
  test_started_at      TIMESTAMPTZ,
  updated_at           TIMESTAMPTZ     DEFAULT now()
);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language plpgsql;

CREATE TRIGGER trg_update_updated_at
BEFORE UPDATE ON requests
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE requests
ADD CONSTRAINT unique_request_per_app_type UNIQUE (target_app_id, request_type);

CREATE TABLE participations (
  id                 UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id         UUID                  NOT NULL REFERENCES requests(id) ON DELETE RESTRICT, -- 내가 참여하는 요청
  user_id            UUID                  NOT NULL REFERENCES users(id) ON DELETE CASCADE,     -- 참여자
  target_request_id  UUID                  REFERENCES requests(id) ON DELETE RESTRICT, -- 도움받고 싶은 요청 (nullable)
  status             participation_status  NOT NULL DEFAULT 'pending',
  proof_url          TEXT,
  requested_at       TIMESTAMPTZ           NOT NULL DEFAULT now(),
  completed_at       TIMESTAMPTZ,
  is_pairing         BOOLEAN              NOT NULL DEFAULT FALSE,
  tester_registered  BOOLEAN              NOT NULL DEFAULT FALSE,
  requester_failed   BOOLEAN              NOT NULL DEFAULT FALSE,
  last_install_check TIMESTAMPTZ,
  created_at         TIMESTAMPTZ          NOT NULL DEFAULT now()
);

-- 한 사용자가 동일 요청에 중복 참여하지 못하도록 UNIQUE 제약 추가
ALTER TABLE participations
ADD CONSTRAINT unique_request_per_user UNIQUE (request_id, user_id, target_request_id);

-- 5) notifications 테이블
create table notifications (
  id            uuid          primary key default gen_random_uuid(),
  user_id       uuid          not null references users(id),
  title         text          not null,
  body          text          not null,
  action        text          not null,
  payload       JSONB         not null DEFAULT '{}'::jsonb,
  scheduled_for timestamptz   not null,
  sent          boolean       not null default false,
  read          boolean       not null default false,
  created_at    timestamptz   not null default now()
);

-- RLS 활성화
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 로그인한 사용자 자신의 알림만 조회할 수 있도록 허용
CREATE POLICY notifications_select_own
  ON notifications
  FOR SELECT
  USING (user_id = auth.uid());

-- 내 서비스 키나 내부 함수에서 user_id를 마음대로 지정해 INSERT 할 수 있게 하려면
CREATE POLICY notifications_insert_any
  ON notifications
  FOR INSERT
  WITH CHECK ( true );

-- 6) reports 테이블

CREATE TABLE reports (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  participation_id UUID        NOT NULL REFERENCES participations(id) ON DELETE CASCADE,
  reporter_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason           TEXT        NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved         BOOLEAN     NOT NULL DEFAULT FALSE,
  resolved_at      TIMESTAMPTZ
);

-- 7) 신뢰점수 변경 로그 저장 테이블
CREATE TABLE trust_score_logs (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  participation_id  UUID        REFERENCES participations(id) ON DELETE CASCADE,
  delta             INT         NOT NULL,
  reason            TEXT        NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8) 리뷰 내용 저장 테이블 (1주일 보존용)
CREATE TABLE review_contents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participation_id UUID REFERENCES participations(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);


-- 7) RLS 활성화
ALTER TABLE users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_apps        ENABLE ROW LEVEL SECURITY;
ALTER TABLE requests         ENABLE ROW LEVEL SECURITY;
ALTER TABLE participations   ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications    ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports          ENABLE ROW LEVEL SECURITY;

-- 8) RLS 정책

-- users
CREATE POLICY users_select_own ON users
  FOR SELECT USING ( auth.uid() = id );
CREATE POLICY users_select_all ON users
  FOR SELECT USING ( true );
CREATE POLICY users_update_own ON users
  FOR UPDATE USING ( auth.uid() = id );
CREATE POLICY users_update_by_service_role ON users
  FOR UPDATE USING (current_user = 'service_role');
CREATE POLICY users_insert_own ON users
  FOR INSERT WITH CHECK ( auth.uid() = id );

-- user_apps
CREATE POLICY apps_select_all ON user_apps
  FOR SELECT USING ( true );
CREATE POLICY apps_insert_per_user ON user_apps
  FOR INSERT WITH CHECK ( owner_id = auth.uid() );
CREATE POLICY apps_update_per_user ON user_apps
  FOR UPDATE USING ( owner_id = auth.uid() );
CREATE POLICY apps_delete_per_user ON user_apps
  FOR DELETE USING ( owner_id = auth.uid() );

-- requests
CREATE POLICY requests_select ON requests
  FOR SELECT USING ( true );
CREATE POLICY requests_insert ON requests
  FOR INSERT WITH CHECK ( owner_id = auth.uid() );
CREATE POLICY requests_update_own ON requests
  FOR UPDATE USING ( owner_id = auth.uid() );
CREATE POLICY requests_delete_own ON requests
  FOR DELETE USING ( owner_id = auth.uid() );

-- participations
CREATE POLICY parts_select ON participations
  FOR SELECT USING (
    request_id IN (
      SELECT id FROM requests
    )
  );

CREATE POLICY parts_insert_with_app ON participations
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
  );

CREATE POLICY parts_update_own ON participations
  FOR UPDATE USING (
    user_id = auth.uid()
    OR request_id IN (
      SELECT id FROM requests WHERE owner_id = auth.uid()
    )
  );

CREATE POLICY parts_delete_only_if_request_open ON participations
    FOR DELETE
    USING (
      user_id = auth.uid()
      AND request_id IN (
        SELECT id FROM requests WHERE status = 'open'
      )
    );

-- notifications
CREATE POLICY noti_select ON notifications
  FOR SELECT USING ( user_id = auth.uid() );

CREATE POLICY notifications_insert_own ON notifications
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- reports
CREATE POLICY reports_insert ON reports
  FOR INSERT WITH CHECK ( reporter_id = auth.uid() );
CREATE POLICY reports_select ON reports
  FOR SELECT USING ( reporter_id = auth.uid() );
CREATE POLICY reports_update ON reports
  FOR UPDATE USING ( FALSE );