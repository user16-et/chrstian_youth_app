-- Populate courtship gender from the account's registered gender where it was
-- never set on the courtship profile (gender is now captured at registration).
UPDATE courtship_profiles c
SET gender = u.gender
FROM users u
WHERE c.user_id = u.id
  AND COALESCE(c.gender, '') = ''
  AND COALESCE(u.gender, '') <> '';
