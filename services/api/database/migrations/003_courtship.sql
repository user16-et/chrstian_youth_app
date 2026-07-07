CREATE TABLE IF NOT EXISTS courtship_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  church_name text NOT NULL,
  city text NOT NULL,
  bio text NOT NULL,
  interests text NOT NULL,
  relationship_intent text NOT NULL DEFAULT 'serious',
  verified boolean NOT NULL DEFAULT false,
  visible boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS courtship_interests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  note text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (sender_id, receiver_id)
);

INSERT INTO courtship_profiles (user_id, church_name, city, bio, interests, relationship_intent, verified, visible)
SELECT id, 'Ethiopian Gospel Church', 'Addis Ababa', 'Serving in youth ministry and seeking a Christ-centered relationship.', 'Bible study, worship, prayer', 'serious', true, true
FROM users
ORDER BY created_at ASC
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO courtship_profiles (user_id, church_name, city, bio, interests, relationship_intent, verified, visible)
SELECT id, 'Bethel Youth Fellowship', 'Adama', 'A prayerful believer who values accountability and church community.', 'Prayer, service, family', 'serious', true, true
FROM users
ORDER BY created_at ASC
OFFSET 1
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO courtship_profiles (user_id, church_name, city, bio, interests, relationship_intent, verified, visible)
SELECT id, 'Mekane Yesus Campus Ministry', 'Hawassa', 'Campus fellowships, mentorship, and devotion are important to me.', 'Campus ministry, discipleship, worship', 'serious', false, true
FROM users
ORDER BY created_at ASC
OFFSET 2
LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO courtship_profiles (user_id, church_name, city, bio, interests, relationship_intent, verified, visible)
SELECT id, 'Local Fellowship', 'Bahir Dar', 'I enjoy quiet prayer, serving, and learning together.', 'Prayer, music, scripture', 'serious', false, true
FROM users
ORDER BY created_at ASC
OFFSET 3
LIMIT 1
ON CONFLICT DO NOTHING;

WITH sender AS (
  SELECT id AS sender_id FROM users ORDER BY created_at ASC LIMIT 1
), receiver AS (
  SELECT id AS receiver_id FROM users ORDER BY created_at ASC OFFSET 1 LIMIT 1
)
INSERT INTO courtship_interests (id, sender_id, receiver_id, note, status)
SELECT gen_random_uuid(), sender.sender_id, receiver.receiver_id, 'Would love to get to know you through church and prayer.', 'pending'
FROM sender, receiver
ON CONFLICT DO NOTHING;

WITH sender AS (
  SELECT id AS sender_id FROM users ORDER BY created_at ASC OFFSET 1 LIMIT 1
), receiver AS (
  SELECT id AS receiver_id FROM users ORDER BY created_at ASC OFFSET 2 LIMIT 1
)
INSERT INTO courtship_interests (id, sender_id, receiver_id, note, status)
SELECT gen_random_uuid(), sender.sender_id, receiver.receiver_id, 'Interested in a God-centered conversation and mentorship.', 'pending'
FROM sender, receiver
ON CONFLICT DO NOTHING;
