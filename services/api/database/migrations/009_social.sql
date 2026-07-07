CREATE TABLE IF NOT EXISTS post_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS post_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS post_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

INSERT INTO post_comments (id, post_id, author_id, body, created_at)
SELECT gen_random_uuid(), p.id, u.id, 'This is encouraging.', now()
FROM posts p
JOIN (SELECT id FROM users ORDER BY created_at ASC LIMIT 1) u ON true
ORDER BY p.created_at ASC
LIMIT 1;

INSERT INTO post_likes (id, post_id, user_id, created_at)
SELECT gen_random_uuid(), p.id, u.id, now()
FROM posts p
JOIN (SELECT id FROM users ORDER BY created_at ASC LIMIT 1) u ON true
ORDER BY p.created_at ASC
LIMIT 1
ON CONFLICT (post_id, user_id) DO NOTHING;

INSERT INTO post_shares (id, post_id, user_id, created_at)
SELECT gen_random_uuid(), p.id, u.id, now()
FROM posts p
JOIN (SELECT id FROM users ORDER BY created_at ASC LIMIT 1) u ON true
ORDER BY p.created_at ASC
LIMIT 1
ON CONFLICT (post_id, user_id) DO NOTHING;
