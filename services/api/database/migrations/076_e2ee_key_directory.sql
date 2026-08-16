-- End-to-end encryption key directory.
--
-- The server only ever stores PUBLIC key material. Private keys never leave the
-- user's device (they live in the platform keystore). This directory lets one
-- device fetch another's prekey bundle to start an X3DH / Double Ratchet
-- (Signal Protocol) session without both parties being online at once.
--
-- One row per (user, device): a device publishes its long-term identity public
-- key plus a signed prekey it rotates periodically.
CREATE TABLE IF NOT EXISTS e2ee_devices (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  registration_id integer NOT NULL,
  identity_key text NOT NULL,                 -- base64 public identity key
  signed_prekey_id integer NOT NULL,
  signed_prekey text NOT NULL,                -- base64 public signed prekey
  signed_prekey_signature text NOT NULL,      -- base64 signature over the signed prekey
  signed_prekey_created_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, device_id)
);

CREATE INDEX IF NOT EXISTS e2ee_devices_user_idx ON e2ee_devices (user_id);

-- A pool of single-use prekeys per device. Fetching a bundle consumes one
-- (each is used by at most one session hand-off), so the client replenishes the
-- pool when it runs low.
CREATE TABLE IF NOT EXISTS e2ee_one_time_prekeys (
  user_id uuid NOT NULL,
  device_id text NOT NULL,
  prekey_id integer NOT NULL,
  prekey text NOT NULL,                        -- base64 public one-time prekey
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, device_id, prekey_id),
  FOREIGN KEY (user_id, device_id) REFERENCES e2ee_devices (user_id, device_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS e2ee_one_time_prekeys_device_idx
  ON e2ee_one_time_prekeys (user_id, device_id, prekey_id);
