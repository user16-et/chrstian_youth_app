UPDATE users
SET username = lower(username)
WHERE username IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS users_username_lower_unique_idx
  ON users(lower(username))
  WHERE username IS NOT NULL;
