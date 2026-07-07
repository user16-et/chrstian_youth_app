CREATE TABLE IF NOT EXISTS prayer_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  status text NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ministries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  department text NOT NULL,
  description text NOT NULL,
  lead_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mentors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name text NOT NULL,
  ministry text NOT NULL,
  church_name text NOT NULL,
  languages text NOT NULL DEFAULT 'en,am',
  verified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mentorship_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_id uuid NOT NULL REFERENCES mentors(id) ON DELETE CASCADE,
  requester_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  note text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  language text NOT NULL DEFAULT 'en',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  amount numeric(12,2) NOT NULL,
  currency text NOT NULL DEFAULT 'ETB',
  recurring boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id uuid REFERENCES payment_plans(id) ON DELETE SET NULL,
  purpose text NOT NULL,
  amount numeric(12,2) NOT NULL,
  currency text NOT NULL DEFAULT 'ETB',
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO ministries (id, name, department, description, lead_name) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Youth Ministry', 'Youth', 'Discipleship, worship nights, and mentoring for young believers.', 'Alemu Tadesse'),
  ('11111111-1111-1111-1111-111111111112', 'Prayer Ministry', 'Prayer', 'Prayer chains, fasting schedules, and intercession support.', 'Rahel Bekele'),
  ('11111111-1111-1111-1111-111111111113', 'Campus Ministry', 'Campus', 'Fellowship and outreach for students and graduates.', 'Henok Mekonnen')
ON CONFLICT DO NOTHING;

INSERT INTO mentors (id, full_name, ministry, church_name, languages, verified) VALUES
  ('22222222-2222-2222-2222-222222222221', 'Simegn Wondimu', 'Youth', 'Ethiopian Gospel Church', 'en,am', true),
  ('22222222-2222-2222-2222-222222222222', 'Marta Gebre', 'Prayer', 'Bethel Youth Fellowship', 'am,en', true),
  ('22222222-2222-2222-2222-222222222223', 'Dawit Tesfaye', 'Campus', 'Mekane Yesus Campus Ministry', 'en,am', false)
ON CONFLICT DO NOTHING;

INSERT INTO payment_plans (id, name, description, amount, currency, recurring) VALUES
  ('33333333-3333-3333-3333-333333333331', 'Monthly Support', 'Support church media, discipleship, and community tools.', 100.00, 'ETB', true),
  ('33333333-3333-3333-3333-333333333332', 'Youth Event Seed', 'Sponsor retreats, conferences, and youth nights.', 250.00, 'ETB', false),
  ('33333333-3333-3333-3333-333333333333', 'Ministry Builder', 'Help ministries purchase teaching and media resources.', 500.00, 'ETB', true)
ON CONFLICT DO NOTHING;
