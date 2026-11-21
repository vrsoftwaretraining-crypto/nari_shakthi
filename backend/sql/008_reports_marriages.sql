-- Developed by Codesoftwares
-- Data for the admin Reports: profile views, response times, marriages, payment details
ALTER TABLE interests ADD COLUMN IF NOT EXISTS responded_at TIMESTAMPTZ;
UPDATE interests SET responded_at = created_at WHERE status <> 'sent' AND responded_at IS NULL;
ALTER TABLE contact_requests ADD COLUMN IF NOT EXISTS responded_at TIMESTAMPTZ;
UPDATE contact_requests SET responded_at = created_at WHERE status <> 'pending' AND responded_at IS NULL;

ALTER TABLE payments ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS txn_ref TEXT;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS admin_note TEXT;
UPDATE payments SET verified_at = created_at WHERE status = 'verified' AND verified_at IS NULL;

ALTER TABLE users ADD COLUMN IF NOT EXISTS matched_at TIMESTAMPTZ;   -- set when an admin confirms a marriage: the profile leaves search

CREATE TABLE IF NOT EXISTS profile_views (
  viewer UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  day DATE NOT NULL DEFAULT current_date,
  PRIMARY KEY (viewer, viewed, day)
);
CREATE INDEX IF NOT EXISTS profile_views_day ON profile_views (day);

CREATE TABLE IF NOT EXISTS marriages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  interest_id UUID UNIQUE REFERENCES interests(id) ON DELETE SET NULL,
  user_a UUID REFERENCES users(id) ON DELETE SET NULL,
  user_b UUID REFERENCES users(id) ON DELETE SET NULL,
  names TEXT NOT NULL,
  reported_by UUID REFERENCES users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'reported' CHECK (status IN ('reported','confirmed','rejected')),
  reported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  decided_at TIMESTAMPTZ,
  decided_by UUID REFERENCES users(id) ON DELETE SET NULL
);
