-- The X3DH key agreement needs the device's identity Diffie-Hellman (X25519)
-- public key, separate from the identity *signing* key (identity_key, Ed25519)
-- that verifies the signed prekey and anchors safety-number verification.
ALTER TABLE e2ee_devices
  ADD COLUMN IF NOT EXISTS identity_dh_key text NOT NULL DEFAULT '';
