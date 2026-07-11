-- Provider-backed payment transactions: the canonical ledger tracking a payment
-- through a real gateway (Chapa, etc.) from checkout to settlement. Domain rows
-- (donations, payment_history) are written on settlement; this table owns the
-- provider lifecycle and reconciliation.
CREATE TABLE IF NOT EXISTS payment_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tx_ref text UNIQUE NOT NULL,
  provider text NOT NULL,
  provider_ref text,
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  purpose text NOT NULL,           -- donation | payment_plan | marketplace_order | ...
  reference_id uuid,               -- fund_id / plan_id / listing_id, by purpose
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  currency text NOT NULL DEFAULT 'ETB',
  status text NOT NULL DEFAULT 'pending',   -- pending | paid | failed | cancelled
  checkout_url text,
  email text,
  first_name text,
  last_name text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  reconciled_at timestamptz,       -- set once domain rows are written (idempotency)
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payment_transactions_user_idx ON payment_transactions(user_id);
CREATE INDEX IF NOT EXISTS payment_transactions_status_idx ON payment_transactions(status);
CREATE INDEX IF NOT EXISTS payment_transactions_purpose_ref_idx ON payment_transactions(purpose, reference_id);
