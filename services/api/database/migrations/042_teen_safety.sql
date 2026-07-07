-- Guardian consent tracking for teen (minor) accounts.
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS guardian_phone text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS guardian_consent_at timestamptz;
