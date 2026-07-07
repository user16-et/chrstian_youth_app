ALTER TABLE church_memberships ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'approved';

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  photo_url text NOT NULL DEFAULT '',
  city text NOT NULL DEFAULT '',
  occupation text NOT NULL DEFAULT '',
  relationship_status text NOT NULL DEFAULT '',
  testimony text NOT NULL DEFAULT '',
  interests text[] NOT NULL DEFAULT '{}',
  birth_date date,
  onboarding_complete boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS otp_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number text NOT NULL,
  code text NOT NULL,
  verified_at timestamptz,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS post_saves (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);

CREATE TABLE IF NOT EXISTS prayer_commitments (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  prayer_request_id uuid NOT NULL REFERENCES prayer_requests(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, prayer_request_id)
);

CREATE TABLE IF NOT EXISTS reading_plan_enrollments (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES bible_reading_plans(id) ON DELETE CASCADE,
  completed_days int NOT NULL DEFAULT 0,
  streak int NOT NULL DEFAULT 0,
  last_checkin date,
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  PRIMARY KEY (user_id, plan_id)
);

CREATE TABLE IF NOT EXISTS friend_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (sender_id, receiver_id)
);

CREATE TABLE IF NOT EXISTS story_replies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  story_id uuid NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL UNIQUE,
  description text NOT NULL,
  lesson_count int NOT NULL DEFAULT 1,
  category text NOT NULL DEFAULT 'Discipleship',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS course_enrollments (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  completed_lessons int NOT NULL DEFAULT 0,
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  PRIMARY KEY (user_id, course_id)
);

CREATE TABLE IF NOT EXISTS certificates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  course_id uuid NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  certificate_code text NOT NULL UNIQUE,
  awarded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, course_id)
);

CREATE TABLE IF NOT EXISTS badges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  badge_key text NOT NULL,
  title text NOT NULL,
  awarded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, badge_key)
);

CREATE TABLE IF NOT EXISTS marketplace_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL UNIQUE,
  category text NOT NULL,
  price_cents int NOT NULL,
  seller_name text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS marketplace_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES marketplace_listings(id),
  status text NOT NULL DEFAULT 'paid',
  receipt_number text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO churches (name, city, verified)
SELECT 'Mulu Wongel', 'Addis Ababa', true
WHERE NOT EXISTS (SELECT 1 FROM churches WHERE name = 'Mulu Wongel');

INSERT INTO ministries (name, department, description, lead_name)
SELECT 'Mulu Wongel Youth Ministry', 'Youth', 'Youth discipleship, fellowship and service.', 'Youth Pastor'
WHERE NOT EXISTS (SELECT 1 FROM ministries WHERE name = 'Mulu Wongel Youth Ministry');

INSERT INTO ministries (name, department, description, lead_name)
SELECT 'Mulu Wongel Media Ministry', 'Media', 'Photography, livestream and church communication.', 'Media Director'
WHERE NOT EXISTS (SELECT 1 FROM ministries WHERE name = 'Mulu Wongel Media Ministry');

INSERT INTO groups (name, category)
SELECT seed.name, seed.category FROM (VALUES
  ('Christian Software Engineers', 'Professional'),
  ('Romans Study', 'Bible Study'),
  ('Night Prayer Warriors', 'Prayer'),
  ('Young Professionals Fellowship', 'Fellowship')
) AS seed(name, category)
WHERE NOT EXISTS (SELECT 1 FROM groups g WHERE g.name = seed.name);

INSERT INTO bible_reading_plans (title, description, duration_days, language, category)
SELECT 'Read New Testament in 90 Days', 'A daily New Testament reading journey with progress and streak tracking.', 90, 'en', 'Bible'
WHERE NOT EXISTS (SELECT 1 FROM bible_reading_plans WHERE title = 'Read New Testament in 90 Days');

INSERT INTO courses (title, description, lesson_count, category) VALUES
  ('Discipleship Foundations', 'Video, PDF and quiz-based foundations for Christian growth.', 8, 'Discipleship'),
  ('Christian Leadership Essentials', 'Practical formation for ministry and youth leaders.', 6, 'Leadership')
ON CONFLICT (title) DO NOTHING;

INSERT INTO marketplace_listings (title, category, price_cents, seller_name) VALUES
  ('Amharic Study Bible', 'Books', 180000, 'Mulu Wongel Bookstore'),
  ('Worship Guitar Resource Pack', 'Worship Resources', 45000, 'Kingdom Creatives'),
  ('Youth Conference Ticket', 'Tickets', 30000, 'Mulu Wongel Youth')
ON CONFLICT (title) DO NOTHING;
