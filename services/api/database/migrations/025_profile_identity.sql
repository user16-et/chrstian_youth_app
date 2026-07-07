ALTER TABLE users
  ADD COLUMN IF NOT EXISTS username text,
  ADD COLUMN IF NOT EXISTS first_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS middle_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS last_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS email text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS profile_image text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS cover_image text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS bio text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS country text NOT NULL DEFAULT 'Ethiopia',
  ADD COLUMN IF NOT EXISTS gender text NOT NULL DEFAULT '';

CREATE UNIQUE INDEX IF NOT EXISTS users_username_unique_idx ON users(username) WHERE username IS NOT NULL;

UPDATE users
SET username=COALESCE(username, lower(regexp_replace(full_name, '[^a-zA-Z0-9]+', '_', 'g')) || '_' || substr(id::text,1,4)),
    first_name=COALESCE(NULLIF(first_name,''), split_part(full_name,' ',1)),
    last_name=COALESCE(NULLIF(last_name,''), NULLIF(split_part(full_name,' ',2),'')),
    bio=COALESCE(NULLIF(bio,''),'Faith, fellowship and service in the Christian community.')
WHERE username IS NULL OR first_name='' OR bio='';

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS cover_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS baptism_status text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS baptism_date date,
  ADD COLUMN IF NOT EXISTS years_in_faith int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS favorite_verse text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS spiritual_interests text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS service_areas text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS privacy_settings jsonb NOT NULL DEFAULT '{"personal":"private","relationship":"relationship_mode_only","phone":"private","church":"public","ministries":"public","friends":"followers_only","prayers":"private"}'::jsonb,
  ADD COLUMN IF NOT EXISTS notification_settings jsonb NOT NULL DEFAULT '{"push":true,"email":false,"sms":false,"church":true,"events":true,"prayer":true}'::jsonb,
  ADD COLUMN IF NOT EXISTS theme text NOT NULL DEFAULT 'light';

UPDATE user_profiles
SET baptism_status=COALESCE(NULLIF(baptism_status,''),'not_set'),
    favorite_verse=COALESCE(NULLIF(favorite_verse,''),'Romans 8:28'),
    spiritual_interests=CASE WHEN spiritual_interests='{}' THEN ARRAY['Prayer','Bible Study','Worship'] ELSE spiritual_interests END,
    service_areas=CASE WHEN service_areas='{}' THEN ARRAY['Youth Ministry','Media Ministry'] ELSE service_areas END;

CREATE TABLE IF NOT EXISTS user_saved_content (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content_type text NOT NULL,
  content_id uuid,
  title text NOT NULL DEFAULT '',
  url text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id,content_type,content_id)
);

CREATE TABLE IF NOT EXISTS user_verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  reviewed_by uuid REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id,type)
);

CREATE TABLE IF NOT EXISTS user_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  note_type text NOT NULL DEFAULT 'personal',
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  visibility text NOT NULL DEFAULT 'private',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO user_verifications(user_id,type,status)
SELECT id,'phone','verified' FROM users ON CONFLICT DO NOTHING;

INSERT INTO user_verifications(user_id,type,status)
SELECT cm.user_id,'church','verified' FROM church_memberships cm WHERE cm.status IN ('active','approved') ON CONFLICT DO NOTHING;

INSERT INTO user_saved_content(user_id,content_type,content_id,title,url)
SELECT user_id,'post',post_id,'Saved post','' FROM post_saves ON CONFLICT DO NOTHING;

INSERT INTO user_notes(user_id,note_type,title,body)
SELECT user_id,'personal','My discipleship goals','Grow in prayer, Bible reading, service and fellowship.' FROM user_profiles
WHERE NOT EXISTS (SELECT 1 FROM user_notes n WHERE n.user_id=user_profiles.user_id AND n.title='My discipleship goals');

INSERT INTO badges(user_id,badge_key,title)
SELECT user_id,'profile_complete','Profile Complete' FROM user_profiles WHERE onboarding_complete=true ON CONFLICT DO NOTHING;

INSERT INTO badges(user_id,badge_key,title)
SELECT user_id,'prayer_warrior','Prayer Warrior' FROM prayer_commitments GROUP BY user_id HAVING count(*) >= 1 ON CONFLICT DO NOTHING;

INSERT INTO badges(user_id,badge_key,title)
SELECT user_id,'event_participant','Event Participant' FROM event_registrations GROUP BY user_id HAVING count(*) >= 1 ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS user_saved_content_user_idx ON user_saved_content(user_id,created_at DESC);
CREATE INDEX IF NOT EXISTS user_notes_user_idx ON user_notes(user_id,created_at DESC);
CREATE INDEX IF NOT EXISTS user_verifications_user_idx ON user_verifications(user_id,type);
