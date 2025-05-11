-- ✅ filterMyParticipation=true 인 경우 사용할 뷰
CREATE OR REPLACE VIEW request_with_owner_filtered AS
SELECT
  r.*,
  u.display_name,
  u.trust_score,
  a.app_name,
  a.package_name,
  a.app_state,
  p.status AS participation_status
FROM requests r
JOIN users u ON r.owner_id = u.id
JOIN user_apps a ON r.target_app_id = a.id
LEFT JOIN participations p ON p.request_id = r.id AND p.user_id = auth.uid()
WHERE (p.status IS NULL OR p.status = 'pending')


--- view table
CREATE VIEW request_with_owner AS
SELECT
  r.*,
  u.display_name,
  u.trust_score,
  a.app_name,
  a.package_name,
  a.app_state
FROM requests r
JOIN users u ON r.owner_id = u.id
JOIN user_apps a ON r.target_app_id = a.id;

CREATE OR REPLACE VIEW request_with_owner_and_participation AS
SELECT
  r.*,
  u.display_name,
  u.trust_score,
  a.app_name,
  a.package_name,
  a.app_state,
  p.user_id AS participation_user_id,
  p.status AS participation_status
FROM requests r
JOIN users u ON r.owner_id = u.id
JOIN user_apps a ON r.target_app_id = a.id
LEFT JOIN participations p
  ON p.request_id = r.id
  AND p.user_id = auth.uid();
;